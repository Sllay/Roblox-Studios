"""Version-pinned read-only Scene Sync, with complete page coverage and parity.
The writer's existing inventory limit is deliberately NOT changed here.
"""
import argparse,base64,hashlib,json,os
from pathlib import Path
from collections import Counter
from scene_sync import ROOT,SERVICES,task,read,write,require,normalize,key_for,state_path,sha
from deploy import load_all,resolve
PAGE=400
SERVICE_LIMIT=20000
TOTAL_LIMIT=40000
SOURCE=ROOT/"tools/sync/inventory_page_batch.luau"
def identity(row):
    return "/".join(f"{len(s['name'].encode('utf-8'))}:{s['name']}:{s['class']}:{s['ordinal']}" for s in row["path"])
def identity_digest(rows):
    keys=sorted(identity(r) for r in rows)
    require(len(keys)==len(set(keys)),"Duplicate path identity")
    b="".join(f"{len(k.encode('utf-8'))}:{k}" for k in keys).encode()
    return base64.b64encode(hashlib.sha256(b).digest()).decode()
def merge_service(name,pages,version):
    require(bool(pages),"Missing service")
    first=pages[0];count=first["total"];digest=first["identityDigest"]
    require(type(count)is int and 0<=count<=SERVICE_LIMIT,"Service budget")
    rows=[];expected=1
    for p in pages:
        require(p["service"]==name and p["loadedVersion"]==version and p["total"]==count and p["identityDigest"]==digest and p["noPlaceWrites"] is True,"Page version/identity drift")
        require(p["first"]==expected and p["last"]==min(count,expected+PAGE-1) and len(p["objects"])==max(0,p["last"]-expected+1),"Page gap/overlap")
        require(all(r["service"]==name for r in p["objects"]),"Service scope")
        rows.extend(p["objects"]);expected=p["last"]+1
    require(len(rows)==count and identity_digest(rows)==digest,"Incomplete service inventory")
    require([identity(r) for r in rows]==sorted(identity(r) for r in rows),"Page order")
    return rows
def capture_sharded(t,key,version,*,request=task):
    src="do\n"+SOURCE.read_text()+"\nend"
    grouped={name:[] for name in SERVICES};first=1;environment=None;manifest=None;total=None
    # Each request returns up to five logical pages; 2000 records max.
    # Empty service pages cost no rows and retain completeness evidence.
    calls=0
    while True:
        r=request(t,key,src,read_version=version,compile_source=True,firstPage=first,pageSize=PAGE,batchSize=5,serviceLimit=SERVICE_LIMIT,totalLimit=TOTAL_LIMIT)
        calls+=1
        require(r["loadedVersion"]==version and r["noPlaceWrites"] and r["firstPage"]==first,"Batch scope")
        if manifest is None:
            manifest=r["manifest"];total=r["totalPages"]
            require([x["service"] for x in manifest]==SERVICES and r["total"]==sum(x["total"] for x in manifest),"Manifest completeness")
            environment={k:r[k] for k in ("terrain","lighting","workspaceSettings")}
        require(r["manifest"]==manifest and r["totalPages"]==total and len(r["pages"])==min(5,total-first+1),"Batch drift or missing pages")
        for page in r["pages"]:
            grouped[page["service"]].append({**page,"loadedVersion":version})
        first+=len(r["pages"])
        if first>total:break
        require(calls<=TOTAL_LIMIT//PAGE+len(SERVICES),"Batch count")
    rows=[];receipts=[]
    for name in SERVICES:
        pages=grouped[name];merged=merge_service(name,pages,version);rows.extend(merged)
        require(len(rows)<=TOTAL_LIMIT,"Total read budget")
        receipts.append({"service":name,"count":len(merged),"pages":len(pages),"identityDigest":pages[0]["identityDigest"]})
    require(environment is not None,"Environment missing")
    result=normalize({"schemaVersion":1,"universeId":t["universeId"],"placeId":t["placeId"],"loadedVersion":version,"services":SERVICES,"total":len(rows),"objects":rows,**environment})
    return result,receipts,calls
def latest(t,key,*,request=task):
    r=request(t,key,"do\nreturn syncResult({noPlaceWrites=true})\nend",compile_source=True)
    require(r["noPlaceWrites"],"Read scope");return r["loadedVersion"]
def default_forensics(base):
    from copy import deepcopy
    roots={}
    for r in base["records"].values():
        path=r.get("path",[])
        if r.get("service")=="StarterPlayer" and path and path[0]["name"]=="PlayerModule" and path[0]["class"]=="ModuleScript":
            n=path[0]["ordinal"];q=deepcopy(r);q["path"][0]["ordinal"]=1
            roots.setdefault(n,{})[key_for(q)]=q
    groups={}
    for n,rs in sorted(roots.items()):groups.setdefault(sha(rs),[]).append(n)
    return {"rootCount":len(roots),"subtreeSizes":{str(n):len(rs) for n,rs in roots.items()},"identicalGroups":list(groups.values()),"allIdentical":len(groups)==1,"deletionAuthorized":False,"note":"Observed equality in scoped record coverage only; does not prove safe deletion or source of cloning."}
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,default=ROOT/"dist/s06-5");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target));key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    version=latest(target,key);require(version==base["loadedVersion"]==16,"Stale baseline")
    state,pages,calls=capture_sharded(target,key,version)
    require(latest(target,key)==version,"Head changed during read")
    require(state==base,"Sharded inventory differs from exact observed baseline")
    report={"loadedVersion":version,"stateDigest":state["stateDigest"],"total":state["total"],"pages":pages,"batchCalls":calls,"parityVerified":True,"noPlaceWrites":True,"defaultForensics":default_forensics(state),"writerLimitUnchanged":True}
    write(a.output/"shard-proof.json",report);print("S065_SHARDS "+json.dumps(report),flush=True)
if __name__=="__main__":main()
