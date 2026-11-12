"""Read-only v17 follow-up for large rock burial and native Terrain query control."""
import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,read,write,require,task,state_path
from deploy import load_all,resolve
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target));require(base["loadedVersion"]==17,"Expected v17")
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+(ROOT/"tools/sync/resource_terrain_query_probe.luau").read_text()+"\nend",read_version=17,compile_source=True)
    require(r["loadedVersion"]==17 and r["noPlaceWrites"] and r["temporaryTerrain"]["restoredExact"] and len(r["rocks"])==6,"Probe scope")
    write(a.output/"terrain-query-proof.json",r);print("S067_TERRAIN "+json.dumps(r),flush=True)
if __name__=="__main__":main()
