"""S08.2 exact reviewed staging publication, one save and independent readback."""
import os,json,time,argparse
from pathlib import Path
from scene_sync import ROOT,task,read,write,require
from deploy import load_all,resolve
from sharded_scene_sync import latest
from cloud_tasks import atomic_json
from workspace import WorkspaceError
def main():
    p=argparse.ArgumentParser();p.add_argument("--reviewed",type=Path,required=True);p.add_argument("--publish",action="store_true");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    out=ROOT/"dist/s082-publish";out.mkdir(parents=True,exist_ok=True)
    reviewed=read(a.reviewed);wood=read(ROOT/"asset-library/approved/eggydrasil/v8/wood-uv/native-proof.json")
    require(reviewed["loadedVersion"]==20 and reviewed["readyForStaging"] and reviewed["noPlaceWrites"] and reviewed["logs"]["count"]==250 and wood["alphaMode"]=="TintMask" and wood["noPlaceWrites"],"Reviewed placement/wood proof")
    src="do\n"+(ROOT/"tools/sync/s082_publish.luau").read_text()+"\nend"
    def head():
        for delay in (10,20,None):
            try:return latest(target,key)
            except WorkspaceError as e:
                if delay is None or not any(x in str(e) for x in ("Cloud task timed out","HTTP 429:","HTTP 502:","HTTP 503:")):raise
                time.sleep(delay)
    def native(mode,version=None,**extra):
        for delay in (10,20,None):
            try:return task(target,key,src,read_version=version,compile_source=True,mode=mode,reviewed=reviewed,wood=wood,**extra)
            except WorkspaceError as e:
                if mode=="apply" or delay is None or not any(x in str(e) for x in ("Cloud task timed out","HTTP 429:","HTTP 502:","HTTP 503:")):raise
                time.sleep(delay)
    require(head()==20,"Expected v20; reconcile if head changed")
    r=native("preview",20);write(out/"preview.json",r)
    require(r["noPlaceWrites"] and r["readyForStaging"] and r["counts"]["logs"]==250 and r["maxCollisionDelta"]<.06 and r["loadedVersion"]==20,"Native texture/collision/placement gate")
    print("S082_FINAL_PREVIEW",json.dumps({k:v for k,v in r.items() if k!="terrain"}),flush=True)
    if not a.publish:return
    opts=dict(expectedNonResource=r["nonResourceFingerprint"])
    receipt={"status":"started","beforeVersion":20,"retryAllowed":False}
    atomic_json(out/"receipt.json",receipt)
    try:
        saved=native("apply",confirmStaging=True,journal=out/"cloud-task.json",**opts)
        require(saved["saved"] and saved["loadedVersion"]==20,"Save receipt")
        version=head();require(version==21,"Expected staging v21")
        receipt.update(status="saved_pending_verification",afterVersion=version);atomic_json(out/"receipt.json",receipt)
        proof=native("verify",21,**opts);write(out/"verification.json",proof)
        require(proof["verified"] and proof["loadedVersion"]==21 and proof["noPlaceWrites"] and proof["counts"]==r["counts"] and proof["logTiles"]==r["logTiles"],"Persisted verification")
        require(head()==21,"Head changed")
        receipt.update(status="verified",counts=proof["counts"],tree=proof["tree"],logTiles=proof["logTiles"]);atomic_json(out/"receipt.json",receipt)
        print("S082_PUBLISHED_VERIFIED",json.dumps(receipt),flush=True)
    except Exception:
        receipt["status"]="requires_reconciliation";atomic_json(out/"receipt.json",receipt);raise
if __name__=="__main__":main()
