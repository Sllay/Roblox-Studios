"""Verify all planned vegetation poses and collider geometry in native detached models."""
import argparse,json,os
from pathlib import Path
from scene_sync import ROOT,read,write,require,sha,state_path,task
from deploy import load_all,resolve
def main():
    p=argparse.ArgumentParser();p.add_argument("--plan",type=Path,required=True);p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target));plan=read(a.plan)
    require(plan["planDigest"]==sha({k:v for k,v in plan.items() if k!="planDigest"}) and plan["stateDigest"]==base["stateDigest"] and plan["loadedVersion"]==base["loadedVersion"] and not plan["applyAuthorized"],"Plan integrity")
    rows=plan["rows"];proof=[];src="do\n"+(ROOT/"tools/sync/vegetation_regeneration_preview.luau").read_text()+"\nend"
    for i in range(0,len(rows),64):
        batch=rows[i:i+64];r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],src,read_version=base["loadedVersion"],compile_source=True,rows=batch)
        require(r["noPlaceWrites"] and not r["runtimeVerified"] and r["checked"]==len(batch) and r["loadedVersion"]==base["loadedVersion"],"Native preview scope")
        proof.append(r)
    result={"planDigest":plan["planDigest"],"loadedVersion":base["loadedVersion"],"checked":sum(r["checked"] for r in proof),"treeProfiles":sum(r["treeProfiles"] for r in proof),"maxHeightError":max(r["maxHeightError"] for r in proof),"maxRadiusError":max(r["maxRadiusError"] for r in proof),"batches":proof,"noPlaceWrites":True,"runtimeVerified":False}
    write(a.output/"geometry.json",result);print("S06_REGEN_GEOMETRY "+json.dumps(result),flush=True)
if __name__=="__main__":main()
