"""Reviewed script-only staging transaction using existing Scene Patch.
No automatic write retry. A saved but unverified operation requires reconciliation.
"""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
from scene_sync import ROOT,read,write,require
GAME=ROOT/"games/maps/mapa-principal"
SYNC=GAME/"docs/sync/main"
def run(*args):subprocess.run([sys.executable,*map(str,args)],cwd=ROOT,check=True)
def validate_plan(plan,base):
    require(plan["schemaVersion"]==1 and plan["expectedVersion"]==base["loadedVersion"] and plan["baselineDigest"]==base["stateDigest"],"Stale reviewed script plan")
    require(1<=len(plan["operations"])<=16,"Script transaction budget")
    require(all(o["kind"] in ("create_script","update_script") for o in plan["operations"]),"Script-only transaction")
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--plan",type=Path,required=True)
    p.add_argument("--confirm-staging",action="store_true")
    p.add_argument("--output",type=Path,default=ROOT/"dist/verified-script-stage")
    a=p.parse_args()
    require(a.confirm_staging,"Explicit staging confirmation")
    path=a.plan.resolve();require(path.is_relative_to(SYNC/"patches"),"Plan must be versioned")
    base=read(SYNC/"staging.json");plan=read(path);validate_plan(plan,base)
    a.output.mkdir(parents=True,exist_ok=True)
    receipt={"schemaVersion":1,"environment":"staging","plan":str(path.relative_to(ROOT)),"planSha256":hashlib.sha256(path.read_bytes()).hexdigest(),"beforeVersion":base["loadedVersion"],"beforeDigest":base["stateDigest"],"status":"started"}
    from cloud_tasks import atomic_json
    try:
        with (a.output/"receipt.json").open("x",encoding="utf-8") as out:
            json.dump(receipt,out);out.flush()
    except FileExistsError as exc:
        raise RuntimeError("Existing transaction receipt; reconcile before another attempt") from exc
    try:
        run("tools/scene_patch.py","apply","--plan",path,"--confirm-staging","--output",a.output/"patch")
        after=read(a.output/"patch/after.json")
        old={k:v for k,v in base["records"].items() if k.startswith("terrain:")}
        require(old=={k:v for k,v in after["records"].items() if k.startswith("terrain:")},"Terrain changed during script transaction")
        run("tools/scene_sync.py","--record","--expected-version",str(after["loadedVersion"]),"--expected-digest",after["stateDigest"])
        observed=read(SYNC/"staging.json")
        require(after["loadedVersion"]==observed["loadedVersion"] and after["stateDigest"]==observed["stateDigest"],"Unexpected change after verification")
        old={k:v for k,v in base["records"].items() if k.startswith("terrain:")}
        new={k:v for k,v in observed["records"].items() if k.startswith("terrain:")}
        require(old==new,"Terrain changed during script transaction")
        receipt.update(status="verified",afterVersion=observed["loadedVersion"],afterDigest=observed["stateDigest"],terrainUnchanged=len(old))
        atomic_json(a.output/"receipt.json",receipt)
        print("SCRIPT_STAGE_VERIFIED",json.dumps(receipt),flush=True)
    except Exception:
        receipt["status"]="requires_reconciliation"
        receipt["retryAllowed"]=False
        write(a.output/"receipt.json",receipt)
        raise
if __name__=="__main__":main()
