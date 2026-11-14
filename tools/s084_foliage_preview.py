"""S08.4 native material-only staging preview, publish and independent readback."""
import argparse
import json
import os
import time
from scene_sync import ROOT, task, write, require
from deploy import load_all, resolve
from sharded_scene_sync import latest
from workspace import WorkspaceError

def retry(fn):
    for delay in (10,20,40,None):
        try:
            return fn()
        except WorkspaceError as exc:
            if delay is None or not any(s in str(exc) for s in ("HTTP 429:", "HTTP 502:", "HTTP 503:", "Cloud task timed out")):
                raise
            time.sleep(delay)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--publish", action="store_true")
    args=parser.parse_args()
    games, targets=load_all()
    target=resolve(games, targets, "mapa-principal", "main", "staging")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    out=ROOT/"dist/s084"
    source="do\n"+(ROOT/"tools/sync/s084_foliage_preview.luau").read_text()+"\nend"
    def native(mode, version, **opts):
        return task(target,key,source,read_version=version,compile_source=True,mode=mode,**opts)
    require(retry(lambda:latest(target,key))==22,"Expected staging v22")
    expected={"tree":250,"pine":16,"bush":200}
    preview=retry(lambda:native("preview",22))
    write(out/"preview.json",preview)
    require(preview["noPlaceWrites"] and preview["readyForStaging"] and preview["counts"]==expected and preview["geometryUnchanged"] and preview["meshPartsAdded"]==0 and len(preview["after"])==250,"Preview gate")
    print("S084_PREVIEW",json.dumps({k:preview[k] for k in ("counts","species","texture","material","changed","meshPartsAdded","geometryUnchanged")}),flush=True)
    if not args.publish:
        return
    require(retry(lambda:latest(target,key))==22,"Staging version drift")
    opts=dict(expectedFingerprint=preview["fingerprint"],expectedEnvironment=preview["environment"],expectedTerrain={r["id"]:r["digest"] for r in preview["terrain"]},expectedBefore=preview["before"],expectedAfter=preview["after"])
    write(out/"receipt.json",{"status":"started","beforeVersion":22,"retryAllowed":False})
    try:
        # Never retry a write automatically. A lost receipt requires reconciliation.
        applied=native("apply",None,confirmStaging=True,journal=out/"cloud-task.json",**opts)
        require(applied["saved"] and applied["loadedVersion"]==22 and applied["counts"]==expected,"Save receipt")
        require(retry(lambda:latest(target,key))==23,"Expected v23")
        proof=retry(lambda:native("verify",23,**opts))
        write(out/"verification.json",proof)
        require(proof["verified"] and proof["counts"]==expected and proof["after"]==preview["after"] and proof["geometryUnchanged"],"Readback gate")
        receipt={"status":"verified","beforeVersion":22,"afterVersion":23,"counts":expected,"changed":250,"meshPartsAdded":0,"clientRenderVerified":False}
        write(out/"receipt.json",receipt)
        print("S084_PUBLISHED",json.dumps(receipt),flush=True)
    except Exception:
        write(out/"receipt.json",{"status":"requires_reconciliation","beforeVersion":22,"retryAllowed":False})
        raise

if __name__=="__main__":
    main()
