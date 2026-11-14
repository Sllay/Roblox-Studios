"""Current staging Scene Sync using complete bounded pages; no Place writes."""
import argparse,os,json
from collections import Counter
from pathlib import Path
from scene_sync import ROOT,task,read,write,require,state_path,reconcile
from sharded_scene_sync import latest,capture_sharded,default_forensics
from deploy import load_all,resolve
from s084_foliage_preview import retry
def main():
    p=argparse.ArgumentParser();p.add_argument("--record",action="store_true");p.add_argument("--desired",type=Path);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    def request(*args,**kwargs):return retry(lambda:task(*args,**kwargs))
    v=latest(target,key,request=request);state,pages,calls=capture_sharded(target,key,v,request=request)
    require(latest(target,key,request=request)==v,"Head drift")
    path=state_path(target);base=read(path) if path.exists() else None
    delta=reconcile(base,state,read(a.desired) if a.desired else None)
    out=ROOT/"dist/scene-sync";write(out/"inventory.json",state);write(out/"changes.json",delta)
    rows=state["records"];summary={k:state[k] for k in ("schemaVersion","universeId","placeId","loadedVersion","stateDigest","total")}
    summary.update(classes=dict(Counter(r["class"] for r in rows.values() if "class" in r)),workspaceRoots=[{"name":r["name"],"class":r["class"],"key":k,"managedId":r["managedId"]} for k,r in rows.items() if r.get("service")=="Workspace" and len(r.get("path",[]))==1],terrain={k:r for k,r in rows.items() if k.startswith("terrain:")},coverageNote="Complete scoped sharded inventory; not full backup",defaultForensics=default_forensics(state),pages=pages)
    write(out/"summary.json",summary)
    if a.record:
        require(not delta["conflicts"] and not delta["local"],"Unresolved desired changes")
        write(path,state);write(path.with_suffix(".summary.json"),summary)
    print("S09_SCENE_SYNC",json.dumps({"version":v,"digest":state["stateDigest"],"total":state["total"],"terrain":len(summary["terrain"]),"defaultForensics":summary["defaultForensics"],"batchCalls":calls,"changes":len(delta["external"])}),flush=True)
if __name__=="__main__":main()
