"""S08.3 deterministic additive vegetation preview and guarded staging publication."""
import argparse,json,os,time
from pathlib import Path
from scene_sync import ROOT,task,read,write,require
from deploy import load_all,resolve
from sharded_scene_sync import latest
from cloud_tasks import atomic_json
from workspace import WorkspaceError
def main():
    p=argparse.ArgumentParser();p.add_argument("--publish",action="store_true");p.add_argument("--reviewed",type=Path);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    out=ROOT/"dist/s083";out.mkdir(parents=True,exist_ok=True)
    plan=read(ROOT/"games/maps/mapa-principal/docs/s06/regeneration-v16/plan.json")
    profiles=[{k:r[k] for k in ("id","groundRadius","supportRadius","canopyRadius")} for r in plan["rows"]]
    source="do\n"+(ROOT/"tools/sync/s083_density.luau").read_text()+"\nend"
    def retry(fn):
        for delay in (10,20,None):
            try:return fn()
            except WorkspaceError as e:
                if delay is None or not any(x in str(e) for x in ("Cloud task timed out","HTTP 429:","HTTP 502:","HTTP 503:")):raise
                time.sleep(delay)
    def native(mode,version=None,**kw):
        fn=lambda:task(target,key,source,read_version=version,compile_source=True,mode=mode,profiles=profiles,**kw)
        return fn() if mode=="apply" else retry(fn)
    require(retry(lambda:latest(target,key))==21,"Expected staging v21")
    expected={"tree":250,"pine":16,"bush":200,"rock":150}
    if not a.publish:
        r=native("preview",21);write(out/"preview.json",r)
        print("S083_PREVIEW",json.dumps({k:v for k,v in r.items() if k!="terrain"}),flush=True)
        require(r["noPlaceWrites"] and r["readyForStaging"] and r["counts"]==expected and r["newModels"]==398,"Preview")
        return
    require(a.reviewed is not None,"Reviewed artifact required")
    r=read(a.reviewed);require(r["loadedVersion"]==21 and r["noPlaceWrites"] and r["readyForStaging"] and r["counts"]==expected,"Reviewed preview")
    opts=dict(expectedDigest=r["digest"],expectedFingerprint=r["fingerprint"],originalFingerprint=r["originalFingerprint"],expectedTerrain={x["id"]:x["digest"] for x in r["terrain"]})
    receipt={"status":"started","beforeVersion":21,"retryAllowed":False};atomic_json(out/"receipt.json",receipt)
    try:
        saved=native("apply",confirmStaging=True,journal=out/"cloud-task.json",**opts)
        require(saved["saved"] and saved["loadedVersion"]==21 and saved["digest"]==r["digest"],"Save receipt")
        version=retry(lambda:latest(target,key));require(version==22,"Expected v22")
        receipt.update(status="saved_pending_verification",afterVersion=version);atomic_json(out/"receipt.json",receipt)
        proof=native("verify",22,**opts);write(out/"verification.json",proof)
        require(proof["verified"] and proof["loadedVersion"]==22 and proof["counts"]==expected and proof["tiles"]==r["tiles"],"Persisted proof")
        receipt.update(status="verified",counts=proof["counts"],tiles=proof["tiles"],digest=proof["digest"],newModels=proof["newModels"],newColliders=proof["newColliders"]);atomic_json(out/"receipt.json",receipt)
        print("S083_PUBLISHED",json.dumps(receipt),flush=True)
    except Exception:
        receipt["status"]="requires_reconciliation";atomic_json(out/"receipt.json",receipt);raise
if __name__=="__main__":main()
