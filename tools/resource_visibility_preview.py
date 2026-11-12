import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,read,write,require,sha,state_path,task
from deploy import load_all,resolve
def main():
    p=argparse.ArgumentParser();p.add_argument("--plan",type=Path,required=True);p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target));plan=read(a.plan)
    require(plan["planDigest"]==sha({k:v for k,v in plan.items() if k!="planDigest"}) and plan["stateDigest"]==base["stateDigest"],"Plan integrity")
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+(ROOT/"tools/sync/resource_paint_preview.luau").read_text()+"\nend",read_version=16,compile_source=True,patches=plan["patches"],terrainExpected={k[8:]:v["digest"] for k,v in base["records"].items() if k.startswith("terrain:")})
    require(r["columns"]==144 and r["all49Restored"] and r["occupancyPreserved"] and r["noPlaceWrites"],"Paint proof")
    write(a.output/"paint-proof.json",r);print("S063_PAINT "+json.dumps(r),flush=True)
if __name__=="__main__":main()
