"""Reviewed, hash-bound transaction for supported Scene Patch operations.
Preview is read-only; apply delegates to existing Scene Patch and independent sync.
Does not implement coupled environment/terrain operations or automatic rollback.
"""
import argparse,json,os,subprocess,sys
from pathlib import Path
from scene_sync import ROOT,require,read,write,sha,require_current,state_path,task
from scene_patch import prepare
from transaction_policy import require_budget
from cloud_tasks import atomic_json
from deploy import load_all,resolve

def make_manifest(target,base,plan,ops):
    require(target["environment"]=="staging","Staging only")
    require((target["universeId"],target["placeId"])==(base["universeId"],base["placeId"]),"Baseline target mismatch")
    require(base["stateDigest"]==sha(base["records"]),"Baseline digest mismatch")
    budget=require_budget(base,ops)
    body={"schemaVersion":1,"kind":"scene_patch","environment":"staging","game":target["game"],"place":target["place"],"universeId":target["universeId"],"placeId":target["placeId"],"beforeVersion":base["loadedVersion"],"beforeDigest":base["stateDigest"],"planDigest":sha(plan),"preparedDigest":sha(ops),"operationKinds":[o["kind"] for o in ops],"inventoryBudget":budget}
    return {**body,"manifestDigest":sha(body)}
def verify_manifest(actual,reviewed):
    require(actual==reviewed,"Reviewed manifest differs from current plan, source or baseline")
def run(*args):
    subprocess.run([sys.executable,*map(str,args)],cwd=ROOT,check=True)
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("operation",choices=["preview","apply"])
    p.add_argument("--plan",type=Path,required=True);p.add_argument("--reviewed",type=Path)
    p.add_argument("--confirm-staging",action="store_true")
    p.add_argument("--output",type=Path,default=ROOT/"dist/scene-transaction")
    a=p.parse_args();g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    plan=read(a.plan);key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    base=require_current(target,key,plan["expectedVersion"]);ops=prepare(target,base,plan)
    manifest=make_manifest(target,base,plan,ops)
    if a.operation=="preview":
        dispatch="do\n"+(ROOT/"tools/sync/patch.luau").read_text()+"\nend"
        result=task(target,key,dispatch,mode="preview",environment="staging",expectedVersion=base["loadedVersion"],operations=ops,compile_source=True)
        require(result.get("preview") is True and result.get("operations")==len(ops) and result["loadedVersion"]==base["loadedVersion"],"Preview contract")
        atomic_json(a.output/"manifest.json",manifest);atomic_json(a.output/"preview.json",result)
        print("SCENE_TRANSACTION_PREVIEW "+json.dumps(manifest),flush=True)
        return
    require(a.confirm_staging and a.reviewed is not None,"Reviewed manifest and staging confirmation required")
    verify_manifest(manifest,read(a.reviewed))
    # Bind the checked plan to the versioned file; no arbitrary source text.
    require(a.plan.resolve().is_relative_to(state_path(target).parent/"patches"),"Apply requires versioned patch")
    a.output.mkdir(parents=True,exist_ok=True)
    receipt={"schemaVersion":1,"manifest":manifest,"status":"started","retryAllowed":False}
    with (a.output/"receipt.json").open("x",encoding="utf-8") as out:
        json.dump(receipt,out);out.flush();os.fsync(out.fileno())
    try:
        run("tools/scene_patch.py","apply","--plan",a.plan,"--confirm-staging","--output",a.output/"patch")
        after=read(a.output/"patch/after.json")
        old={k:v for k,v in base["records"].items() if k.startswith("terrain:")}
        require(old=={k:v for k,v in after["records"].items() if k.startswith("terrain:")},"Unexpected terrain delta")
        run("tools/scene_sync.py","--record","--expected-version",str(after["loadedVersion"]),"--expected-digest",after["stateDigest"])
        receipt.update(status="verified",afterVersion=after["loadedVersion"],afterDigest=after["stateDigest"],terrainUnchanged=len(old))
        atomic_json(a.output/"receipt.json",receipt)
        print("SCENE_TRANSACTION_VERIFIED "+json.dumps(receipt),flush=True)
    except Exception:
        receipt["status"]="requires_reconciliation";atomic_json(a.output/"receipt.json",receipt);raise
if __name__=="__main__":main()
