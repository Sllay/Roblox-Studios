"""Incremental, reviewed scene operations against a fresh Scene Sync baseline."""
from __future__ import annotations
import argparse,base64,hashlib,json,math,os,re,sys
from pathlib import Path
from scene_sync import ROOT,require,require_current,read,write,state_path,task,capture,reconcile,sha
from deploy import load_all,resolve,WorkspaceError
from scene_snapshot import canonical
ID=re.compile(r"[a-z][a-z0-9-]{2,63}")
NAME=re.compile(r"[A-Za-z0-9_ -]{1,80}")
COUPLED_ROOTS={"RSSceneBuilder","RSWorldVegetation","RSEnvironmentP4","RSEnvironmentP4Detail","RSManagedAssets"}
def require_uncoupled(r):
    path=r.get("path",[])
    require(r.get("service")!="Workspace" or not path or path[0]["name"] not in COUPLED_ROOTS,"Use dedicated coupled environment migration")
def num(v,lo,hi):return type(v) in (int,float) and math.isfinite(v) and lo<=v<=hi
def vector(v,n,lo,hi):return isinstance(v,list) and len(v)==n and all(num(x,lo,hi) for x in v)
def cf(v):
    require(vector(v,12,-100000,100000),"Invalid CFrame")
    rows=[v[3:6],v[6:9],v[9:12]]
    for i,a in enumerate(rows):
        for j,b in enumerate(rows):
            require(abs(sum(x*y for x,y in zip(a,b))-(i==j))<0.001,"Nonorthonormal CFrame")
    det=rows[0][0]*(rows[1][1]*rows[2][2]-rows[1][2]*rows[2][1])-rows[0][1]*(rows[1][0]*rows[2][2]-rows[1][2]*rows[2][0])+rows[0][2]*(rows[1][0]*rows[2][1]-rows[1][1]*rows[2][0])
    require(abs(det-1)<0.001,"Invalid CFrame handedness")
def changes(p):
    require(isinstance(p,dict) and p and set(p)<={"cframe","size","color","material","transparency","canCollide"},"Unsupported property")
    if "cframe" in p:cf(p["cframe"])
    if "size" in p:require(vector(p["size"],3,0.1,512),"Size")
    if "color" in p:require(vector(p["color"],3,0,1),"Color")
    if "material" in p:require(p["material"] in ("Plastic","SmoothPlastic","Wood","WoodPlanks","Rock","Concrete","Metal","Glass","Neon"),"Material")
    if "transparency" in p:require(num(p["transparency"],0,1),"Transparency")
    if "canCollide" in p:require(type(p["canCollide"]) is bool,"Collision")
def prepare(t,base,p):
    require(t["environment"]=="staging" and p["schemaVersion"]==1 and p["expectedVersion"]==base["loadedVersion"] and p["baselineDigest"]==base["stateDigest"],"Plan baseline mismatch")
    require(1<=len(p["operations"])<=32,"Operation budget")
    records=base["records"];ops=[];seen=set();new_ids=set();destinations=set();target_paths=[];parent_paths=[];archive_ids=set()
    def lookup(key):
        r=records.get(key);require(isinstance(r,dict) and "path" in r and not r["ambiguous"],"Missing/ambiguous target")
        return r
    def parent(key):
        if key in ("service:Workspace","service:ServerScriptService","service:ReplicatedStorage"):
            return {"service":key.split(":")[1],"path":[]}
        return lookup(key)
    for raw in p["operations"]:
        op=dict(raw);kind=op["kind"]
        require(kind in ("add_part","set_part","move_model","adopt","archive","restore","create_script","update_script"),"Unsupported operation")
        if kind in ("set_part","move_model","adopt","archive","restore","update_script"):
            key=op.pop("targetKey");require(key not in seen,"Repeated target");seen.add(key);op["target"]=lookup(key)
            require_uncoupled(op["target"])
            target_paths.append((op["target"]["service"],op["target"]["path"]))
        if kind in ("add_part","restore","create_script"):
            op["parent"]=parent(op.pop("parentKey"))
            require_uncoupled(op["parent"])
            parent_paths.append((op["parent"]["service"],op["parent"]["path"]))
        if kind in ("add_part","create_script"):
            require(NAME.fullmatch(op["name"]) and ID.fullmatch(op["id"]) and "managed:"+op["id"] not in records and op["id"] not in new_ids,"Name/ID")
            new_ids.add(op["id"]);dest=canonical([op["parent"]["service"],op["parent"]["path"],op["name"]]);require(dest not in destinations,"Duplicate destination");destinations.add(dest)
        if kind in ("add_part","set_part"):changes(op["changes"])
        if kind=="add_part":require("cframe" in op["changes"] and "size" in op["changes"],"Explicit geometry")
        if kind=="move_model":cf(op["cframe"])
        if kind=="adopt":
            require(ID.fullmatch(op["id"]) and "managed:"+op["id"] not in records and op["id"] not in new_ids,"Adoption ID");new_ids.add(op["id"])
        if kind in ("archive","update_script"):
            require(ID.fullmatch(op["archiveId"]) and op["archiveId"] not in archive_ids,"Archive ID")
            archive_ids.add(op["archiveId"])
        if kind=="archive":
            op["parentToken"]=canonical([op["target"]["service"],op["target"]["path"][:-1]])
        if kind=="restore":
            op["parentToken"]=canonical([op["parent"]["service"],op["parent"]["path"]])
            children=[r for r in records.values() if r.get("service")==op["target"]["service"] and len(r.get("path",[]))==len(op["target"]["path"])+1 and r["path"][:-1]==op["target"]["path"]]
            require(len(children)==1,"Archive original not unique")
            op["restoreOriginal"]=children[0]
            dest=canonical([op["parent"]["service"],op["parent"]["path"],children[0]["name"]]);require(dest not in destinations,"Duplicate restore destination");destinations.add(dest)
        if kind in ("create_script","update_script"):
            if kind=="update_script":
                require(op["target"]["coverage"]=="script_hash" and op["target"]["childCount"]==0 and op["target"]["service"] in ("ServerScriptService","ReplicatedStorage","StarterPlayer"),"Unsupported script target")
                op["class"]=op["target"]["class"];op["targetToken"]=canonical([op["target"]["service"],op["target"]["path"]])
            require(op["class"] in ("Script","LocalScript","ModuleScript"),"Script class")
            path=(ROOT/op.pop("sourcePath")).resolve()
            game=(ROOT/"games/maps"/t["game"]/"game/places"/t["place"]/"src").resolve()
            require(path.is_relative_to(game) and path.suffix in (".lua",".luau") and path.is_file(),"Source must be checked-in game script")
            source=path.read_text();require(len(source.encode())<=64000,"Script budget")
            op["source"]=source;op["sourceHash"]=base64.b64encode(hashlib.sha256(source.encode()).digest()).decode()
        ops.append(op)
    for i,(svc,path) in enumerate(target_paths):
        for svc2,path2 in target_paths[:i]:
            require(svc!=svc2 or not (path[:len(path2)]==path2 or path2[:len(path)]==path),"Overlapping targets")
    for svc,path in parent_paths:
        for svc2,path2 in target_paths:
            require(svc!=svc2 or path[:len(path2)]!=path2,"Parent is being edited in same batch")
    return ops
def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument("operation",choices=["preview","apply"]);a.add_argument("--plan",type=Path,required=True)
    a.add_argument("--game",default="mapa-principal");a.add_argument("--place",default="main")
    a.add_argument("--confirm-staging",action="store_true");a.add_argument("--output",type=Path,default=ROOT/"dist/scene-patch")
    p=a.parse_args();games,targets=load_all();t=resolve(games,targets,p.game,p.place,"staging")
    plan=read(p.plan);key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];base=require_current(t,key,plan["expectedVersion"])
    ops=prepare(t,base,plan);dispatch="do\n"+(ROOT/"tools/sync/patch.luau").read_text()+"\nend"
    opts=dict(environment="staging",expectedVersion=base["loadedVersion"],operations=ops)
    preview=task(t,key,dispatch,mode="preview",compile_source=True,**opts);write(p.output/"preview.json",preview)
    require(preview.get("preview") is True and preview.get("operations")==len(ops) and preview["loadedVersion"]==base["loadedVersion"],"Preview contract mismatch")
    if p.operation=="preview":print("PATCH_PREVIEW",json.dumps(preview));return
    require(p.confirm_staging,"Explicit confirmation required")
    require(not (p.output/"cloud-task.json").exists(),"Prior write journal; reconcile before apply")
    from script_quality import main as quality
    require(quality([])==0,"Luau gate")
    result=task(t,key,dispatch,mode="apply",compile_source=True,journal=p.output/"cloud-task.json",**opts);write(p.output/"save.json",result)
    require(result["loadedVersion"]==base["loadedVersion"] and isinstance(result.get("results"),list) and len(result["results"])==len(ops),"Save result contract mismatch")
    require(result.get("saved") is True,"Save unconfirmed")
    after=capture(t,key);write(p.output/"after.json",after);delta=reconcile(base,after);write(p.output/"changes.json",delta)
    require(after["loadedVersion"]>base["loadedVersion"],"Persistence unconfirmed")
    # Check the affected object identities / actual requested values, not merely save.
    for op in ops:
        k=op["kind"]
        if k in ("add_part","adopt","create_script"):
            r=after["records"].get("managed:"+op["id"]);require(r is not None,"New identity missing")
            if k=="create_script":require(r["properties"]["sourceHash"]==op["sourceHash"],"Source mismatch")
            if k=="add_part":check_properties(r,op["changes"])
        elif k in ("set_part","move_model","update_script"):
            from scene_sync import key_for
            r=after["records"].get(key_for(op["target"]));require(r is not None,"Edited object missing")
            check_properties(r,op["changes"] if k=="set_part" else {"pivot":op["cframe"]} if k=="move_model" else {"sourceHash":op["sourceHash"]})
            if k=="update_script":
                require(any(x.get("service")=="ServerStorage" and [p["name"] for p in x.get("path",[])][:2]==["RSScenePatchArchive",op["archiveId"]] and x.get("properties",{}).get("sourceHash")==op["target"]["properties"]["sourceHash"] for x in after["records"].values() if isinstance(x.get("properties"),dict)),"Script backup missing")
        elif k=="archive":
            require(any(r.get("service")=="ServerStorage" and [x["name"] for x in r.get("path",[])][:2]==["RSScenePatchArchive",op["archiveId"]] and r.get("name")==op["target"]["name"] for r in after["records"].values()),"Archive missing")
        elif k=="restore":
            require(not any(r.get("service")=="ServerStorage" and r.get("path",[])==op["target"]["path"] for r in after["records"].values()),"Archive still exists")
            original=op["restoreOriginal"]
            matches=[r for r in after["records"].values() if r.get("service")==op["parent"]["service"] and r.get("path",[])[:-1]==op["parent"]["path"] and r.get("name")==original["name"] and r.get("class")==original["class"]]
            require(len(matches)==1 and matches[0]["properties"]==original["properties"] and matches[0]["attributesHash"]==original["attributesHash"],"Restored original mismatch")
    from default_clone_delta import split_default_clones
    scoped,defaults=split_default_clones(base,after,delta["external"])
    if defaults:write(p.output/"default-clone-delta.json",defaults)
    verify_scope(base,after,ops,{"external":scoped})
    print("PATCH_VERIFIED",json.dumps({"version":after["loadedVersion"],"operations":len(ops),"changes":len(delta["external"])}))
def verify_scope(base,after,ops,delta):
    scopes=[]
    def scope(service,path,subtree=False):scopes.append((service,path,subtree))
    for op in ops:
        t=op.get("target");p=op.get("parent");kind=op["kind"]
        if t:
            scope(t["service"],t["path"],True)
            scope(t["service"],t["path"][:-1])
        if p:
            scope(p["service"],p["path"])
            name=op.get("name") or op.get("restoreOriginal",{}).get("name")
            cls=op.get("class") or op.get("restoreOriginal",{}).get("class") or "Part"
            if name:scope(p["service"],p["path"]+[{"name":name,"class":cls,"ordinal":1}],True)
        if kind in ("archive","update_script","restore"):
            ar=[{"name":"RSScenePatchArchive","class":"Folder","ordinal":1}]
            scope("ServerStorage",ar)
            if kind!="restore":scope("ServerStorage",ar+[{"name":op["archiveId"],"class":"Folder","ordinal":1}],True)
    for row in delta["external"]:
        for state in (base,after):
            r=state["records"].get(row["key"])
            if not r:continue
            path=r.get("path")
            require(path is not None and any(r.get("service")==svc and (path[:len(p)]==p if subtree else path==p) for svc,p,subtree in scopes),"Unexpected unrelated scene change: "+row["key"])
def check_properties(r,expected):
    p=r["properties"]
    for k,v in expected.items():
        actual=p.get(k)
        if isinstance(v,list):require(isinstance(actual,list) and len(actual)==len(v) and all(abs(a-b)<0.005 for a,b in zip(actual,v)),"Property mismatch: "+k)
        else:require(actual==v,"Property mismatch: "+k)
if __name__=="__main__":main()
