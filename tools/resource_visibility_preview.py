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
    proof=[];rows=plan["resources"]
    src="do\n"+(ROOT/"tools/sync/resource_visibility_geometry.luau").read_text()+"\nend"
    for i in range(0,len(rows),72):
        batch=rows[i:i+72];g=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],src,read_version=16,compile_source=True,rows=batch)
        require(g["checked"]==len(batch) and g["noPlaceWrites"] and g["loadedVersion"]==16,"Resource geometry proof");proof.append(g)
    result={"checked":sum(g["checked"] for g in proof),"maxBoundsError":max(g["maxBoundsError"] for g in proof),"planDigest":plan["planDigest"],"noPlaceWrites":True}
    write(a.output/"geometry.json",result);print("S063_GEOMETRY "+json.dumps(result),flush=True)
if __name__=="__main__":main()
