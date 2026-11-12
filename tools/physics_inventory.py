"""Read exact staging version tree geometry and collider profiles."""
import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,task,read,write,require,state_path
from deploy import load_all,resolve
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--output",type=Path,default=ROOT/"dist/s04");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+(ROOT/"tools/sync/physics_inventory.luau").read_text()+"\nend",read_version=base["loadedVersion"],compile_source=True)
    require(r["noPlaceWrites"] is True and r["loadedVersion"]==base["loadedVersion"],"Scope")
    require(len(r["rows"])==len({o["id"] for o in r["rows"]}),"Duplicate model identity")
    r["stateDigest"]=base["stateDigest"];write(a.output/"inventory.json",r)
    from collections import Counter
    print("S04_INVENTORY "+json.dumps({"version":r["loadedVersion"],"models":len(r["rows"]),"trees":dict(Counter(o["species"] for o in r["rows"] if o["species"].startswith(("Tree_","Pine_")))),"colliders":sum(o.get("collider") is not None for o in r["rows"]),"playableUncoupled":[{k:o.get(k) for k in ("id","species","position","ground","top")} for o in r["rows"] if o["playable"] and o["species"].startswith(("Tree_","Pine_")) and not o.get("collider")],"geometry":r["geometry"],"worldModel":r["worldModel"]}),flush=True)
if __name__=="__main__":main()
