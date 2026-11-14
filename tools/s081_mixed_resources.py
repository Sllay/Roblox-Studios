"""S08.1 staging-only mixed resource transaction; one write, no blind retry."""
import argparse,json,os,time
from pathlib import Path
from scene_sync import ROOT,read,write,require,task
from deploy import load_all,resolve
from sharded_scene_sync import latest
from cloud_tasks import atomic_json
from workspace import WorkspaceError
def main():
    p=argparse.ArgumentParser();p.add_argument("--publish",action="store_true");p.add_argument("--reviewed",type=Path);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];out=ROOT/"dist/s081";out.mkdir(parents=True,exist_ok=True)
    reg=read(ROOT/"games/maps/mapa-principal/game/assets/prop-registry-s08-candidates.json")
    src="do\n"+(ROOT/"tools/sync/s081_mixed_resources.luau").read_text()+"\nend"
    def native(mode,version=None,**extra):
        for delay in (15,30,60,120,None):
            try:
                return task(target,key,src,read_version=version,compile_source=True,mode=mode,assets=reg["props"],**extra)
            except WorkspaceError as e:
                if "HTTP 429:" not in str(e) or delay is None or mode=="apply":raise
                time.sleep(delay)
    version=latest(target,key);require(version==19,"Expected staging v19; reconcile if head changed")
    preview=native("preview",version)
    write(out/"preview.json",preview)
    require(preview["loadedVersion"]==19 and preview["noPlaceWrites"] and preview["readyForStaging"] and preview["removed"]==1000,"Preview contract")
    require(preview["counts"]=={"Stone":{"legacy":250,"v1":250},"Stick":{"legacy":250,"v1":250}} and preview["maxSupportGap"]<=.22 and len(preview["terrain"])==49,"Preview validation")
    print("S081_PREVIEW",json.dumps({k:v for k,v in preview.items() if k!="terrain"}),flush=True)
    if not a.publish:return
    require(a.reviewed is not None,"Reviewed preview required")
    reviewed=read(a.reviewed)
    for k in ("resourcePlanDigest","tree","treeSite","nonResourceFingerprint","originalNonResource","terrain","counts","legacyMeshIds"):
        require(preview[k]==reviewed[k],"Reviewed preview mismatch "+k)
    opts=dict(expectedDigest=preview["resourcePlanDigest"],expectedTreeDigest=preview["tree"]["digest"],expectedSite=preview["treeSite"],expectedNonResource=preview["nonResourceFingerprint"],originalNonResource=preview["originalNonResource"],expectedTerrain={r["id"]:r["digest"] for r in preview["terrain"]},legacyMeshIds=preview["legacyMeshIds"])
    require(latest(target,key)==19,"Head changed before save")
    receipt={"status":"started","beforeVersion":19,"retryAllowed":False,"resourcePlanDigest":opts["expectedDigest"]}
    atomic_json(out/"publication-receipt.json",receipt)
    try:
        saved=native("apply",confirmStaging=True,journal=out/"cloud-task.json",**opts)
        require(saved["saved"] and saved["loadedVersion"]==19,"Save receipt")
        version=latest(target,key);require(version==20,"Expected staging v20")
        receipt.update(status="saved_pending_verification",afterVersion=version);atomic_json(out/"publication-receipt.json",receipt)
        proof=native("verify",version,**opts)
        write(out/"verification.json",proof)
        require(proof["verified"] and proof["loadedVersion"]==version and proof["noPlaceWrites"],"Persisted verification")
        require(latest(target,key)==version,"Head changed after verification")
        receipt.update(status="verified",controllerState=proof["controllerState"],counts=proof["counts"]);atomic_json(out/"publication-receipt.json",receipt)
        print("S081_PUBLISHED_VERIFIED",json.dumps({"receipt":receipt,"tree":proof["tree"],"tiles":proof["tiles"]}),flush=True)
    except Exception:
        receipt["status"]="requires_reconciliation";atomic_json(out/"publication-receipt.json",receipt);raise
if __name__=="__main__":main()
