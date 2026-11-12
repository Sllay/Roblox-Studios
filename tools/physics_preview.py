"""Validate detached collider construction in the exact staging version."""
import argparse,json,os
from pathlib import Path
from scene_sync import ROOT,task,read,write,require,sha,state_path
from deploy import load_all,resolve
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--plan",type=Path,required=True);p.add_argument("--output",type=Path,default=ROOT/"dist/s04");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target));plan=read(a.plan)
    require(plan["planDigest"]==sha({k:v for k,v in plan.items() if k!="planDigest"}) and plan["stateDigest"]==base["stateDigest"] and plan["loadedVersion"]==base["loadedVersion"] and plan["applyAuthorized"] is False,"Plan scope")
    rows=plan["profiles"];proof=[]
    for i in range(0,len(rows),32):
        batch=rows[i:i+32]
        r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+(ROOT/"tools/sync/physics_preview.luau").read_text()+"\nend",read_version=base["loadedVersion"],compile_source=True,profiles=batch)
        require(r["checked"]==len(batch) and r["noPlaceWrites"] is True and r["runtimePhysicsVerified"] is False,"Native proof")
        proof.append(r)
    result={"schemaVersion":1,"version":base["loadedVersion"],"planDigest":plan["planDigest"],"checked":sum(r["checked"] for r in proof),"batches":proof,"noPlaceWrites":True,"runtimePhysicsVerified":False}
    write(a.output/"collider-preview.json",result);print("S04_PREVIEW "+json.dumps({"checked":result["checked"],"batches":len(proof),"planDigest":plan["planDigest"],"runtimePhysicsVerified":False}),flush=True)
if __name__=="__main__":main()
