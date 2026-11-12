"""Read-only historical comparison. Exact scoped evidence, not permission to delete."""
import argparse,json,os
from pathlib import Path
from scene_sync import ROOT,capture,read,write,require,reconcile,state_path
from default_clone_delta import split_default_clones
from deploy import load_all,resolve

def counts(state):
    rows=state["records"].values()
    pm=[r for r in rows if r.get("service")=="StarterPlayer" and r.get("path") and r["path"][0]["name"]=="PlayerModule"]
    atomic=[r for r in rows if r.get("service")=="StarterPlayer" and r.get("name")=="AtomicBinding" and r.get("class")=="ModuleScript"]
    return {"playerModuleRoots":sum(len(r["path"])==1 for r in pm),"playerModuleRecords":len(pm),"atomicBindingRecords":len(atomic),"total":state["total"]}
def compare(before,after):
    delta=reconcile(before,after)["external"]
    scoped,clones=split_default_clones(before,after,delta)
    return {"beforeVersion":before["loadedVersion"],"afterVersion":after["loadedVersion"],"before":counts(before),"after":counts(after),"exactCloneDeltaRecords":len(clones),"otherDeltaRecords":len(scoped),"cloneKeys":[r["key"] for r in clones],"terrainUnchanged":all(after["records"].get(k)==v for k,v in before["records"].items() if k.startswith("terrain:")),"causeProven":False,"deletionAuthorized":False}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--before",type=int,default=13);p.add_argument("--output",type=Path,default=ROOT/"dist/s01");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    base=read(state_path(target));require(1<=a.before<base["loadedVersion"],"Historical version required")
    before=capture(target,key,read_version=a.before);after=capture(target,key,read_version=base["loadedVersion"])
    require(after["stateDigest"]==base["stateDigest"],"Current baseline mismatch")
    report=compare(before,after);report.update(noPlaceWrites=True,universeId=target["universeId"],placeId=target["placeId"])
    write(a.output/"default-module-report.json",report)
    print("S01_FORENSICS "+json.dumps({k:v for k,v in report.items() if k!="cloneKeys"}),flush=True)
if __name__=="__main__":main()
