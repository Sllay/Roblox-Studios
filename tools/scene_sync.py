"""Scene Sync: observe published Place state and reconcile without overwriting it."""
from __future__ import annotations
import argparse, hashlib, json, os, re, sys
from pathlib import Path
from cloud_tasks import run_task
from deploy import load_all,resolve,WorkspaceError
from scene_snapshot import canonical,ROOT

SERVICES=["Workspace","ReplicatedStorage","ServerScriptService","ServerStorage","StarterPlayer","StarterGui","StarterPack","Lighting","SoundService","Teams","ReplicatedFirst"]
SOURCE=ROOT/"tools/sync/inventory.luau"
def require(ok,msg):
    if not ok:raise WorkspaceError(msg)
def sha(value):return hashlib.sha256(canonical(value).encode()).hexdigest()
def read(path):return json.loads(path.read_text(encoding="utf-8"))
def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2,sort_keys=True)+"\n",encoding="utf-8")
def state_path(t):
    return ROOT/"games/maps"/t["game"]/"docs/sync"/t["place"]/(t["environment"]+".json")
def regions(t):
    path=ROOT/"games/maps"/t["game"]/"docs/sync"/t["place"]/"regions.json"
    if not path.exists():return []
    rows=read(path)
    require(isinstance(rows,list) and len(rows)<=32,"Region limit")
    for r in rows:
        b=r["bounds"];require(len(b)==6 and all(type(x) is int and x%4==0 for x in b),"Region alignment")
        dx,dy,dz=[b[i+3]-b[i] for i in range(3)]
        require(min(dx,dy,dz)>0 and dx*dy*dz//64<=262144,"Region budget")
    return rows
def key_for(row):
    return "managed:"+row["managedId"] if row["managedId"] else "path:"+canonical([row["service"],row["path"]])
def normalize(report):
    require(report.get("schemaVersion")==1 and isinstance(report.get("loadedVersion"),int),"Invalid inventory")
    require(report["total"]==len(report["objects"]) and report["services"]==SERVICES,"Incomplete inventory")
    rows={}
    for r in report["objects"]:
        k=key_for(r);require(k not in rows,"Duplicate managed identity: "+k)
        rows[k]=r
    items={**rows}
    for r in report["terrain"]:items["terrain:"+r["id"]]=r
    items["environment:lighting"]=report["lighting"]
    state={k:report[k] for k in ("schemaVersion","universeId","placeId","loadedVersion","services","total")}
    state["records"]=items
    state["stateDigest"]=sha(items)
    return state
def task(t,key,dispatch="",**extra):
    cfg=dict(universeId=t["universeId"],placeId=t["placeId"],services=SERVICES,regions=regions(t),maxObjects=5000,**extra)
    payload=canonical(cfg)
    src=SOURCE.read_text().replace("-- __RS_SYNC_DISPATCH__",dispatch)
    for n in range(1,16):
        eq="="*n
        if "]"+eq+"]" not in payload:return run_task(t["universeId"],t["placeId"],key,src.replace("__RS_CONFIG__","["+eq+"["+payload+"]"+eq+"]"))
    raise WorkspaceError("Config encoding")
def capture(t,key):return normalize(task(t,key))
def reconcile(base,remote,desired=None):
    """Three-way diff. Desired contains explicit record intents, not absence=deletion."""
    old=base["records"] if base else {}
    now=remote["records"]
    desired=desired or {}
    external=[];local=[];conflicts=[];converged=[]
    for k in sorted(set(old)|set(now)|set(desired)):
        a,b=old.get(k),now.get(k)
        local_changed=k in desired and desired[k]!=a
        remote_changed=a!=b
        if local_changed and remote_changed:
            if desired[k]==b:converged.append(k)
            else:conflicts.append(k)
        elif local_changed:local.append(k)
        elif remote_changed:external.append({"key":k,"change":"added" if a is None else "removed" if b is None else "modified"})
    return {"external":external,"local":local,"conflicts":conflicts,"converged":converged,"initial":base is None}
def require_current(t,key,expected=None):
    """Mandatory pre-write guard: checked-in observed baseline, independently reread."""
    path=state_path(t);require(path.is_file(),"Run Scene Sync first: no baseline")
    base=read(path);remote=capture(t,key)
    require(base["universeId"]==remote["universeId"] and base["placeId"]==remote["placeId"],"Sync target mismatch")
    require(base["stateDigest"]==sha(base["records"]),"Sync baseline integrity")
    require(base["loadedVersion"]==remote["loadedVersion"] and base["stateDigest"]==remote["stateDigest"],"Scene changed: run Scene Sync, review external changes, replan")
    if expected is not None:require(remote["loadedVersion"]==expected,"Plan version stale")
    return remote
def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument("--game",default="mapa-principal");a.add_argument("--place",default="main")
    a.add_argument("--environment",choices=["staging","production"],default="staging")
    a.add_argument("--output",type=Path,default=ROOT/"dist/scene-sync")
    a.add_argument("--record",action="store_true",help="Update observed Git baseline; does not write Roblox")
    a.add_argument("--desired",type=Path,help="Explicit desired records map for three-way comparison")
    p=a.parse_args();games,targets=load_all();t=resolve(games,targets,p.game,p.place,p.environment)
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];path=state_path(t)
    base=read(path) if path.exists() else None
    remote=capture(t,key)
    if base:require((base["universeId"],base["placeId"])==(remote["universeId"],remote["placeId"]),"Baseline target mismatch")
    delta=reconcile(base,remote,read(p.desired) if p.desired else None)
    write(p.output/"inventory.json",remote);write(p.output/"changes.json",delta)
    classes={}
    for r in remote["records"].values():
        if "class" in r:classes[r["class"]]=classes.get(r["class"],0)+1
    summary={"schemaVersion":1,"universeId":remote["universeId"],"placeId":remote["placeId"],"loadedVersion":remote["loadedVersion"],"stateDigest":remote["stateDigest"],"total":remote["total"],"classes":classes,"workspaceRoots":[{"name":v["name"],"class":v["class"],"key":k,"managedId":v["managedId"]} for k,v in remote["records"].items() if v.get("service")=="Workspace" and len(v.get("path",[]))==1],"terrain":{k:v for k,v in remote["records"].items() if k.startswith("terrain:")},"coverageNote":"Scoped inventory, not full backup. Query full records for object properties."}
    write(p.output/"summary.json",summary)
    if p.record:
        require(not delta["conflicts"] and not delta["local"],"Unresolved desired changes: do not advance baseline")
        write(path,remote);write(path.with_suffix(".summary.json"),summary)
    print("SCENE_SYNC",json.dumps({"version":remote["loadedVersion"],"objects":remote["total"],"classes":classes,"terrain":{k:v for k,v in remote["records"].items() if k.startswith("terrain:")},"changes":{k:len(v) for k,v in delta.items() if isinstance(v,list)},"digest":remote["stateDigest"]}),flush=True)
if __name__=="__main__":
    try:main()
    except (WorkspaceError,ValueError,KeyError,OSError) as e:print("ERROR:",e,file=sys.stderr);raise SystemExit(1)
