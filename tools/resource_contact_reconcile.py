"""Reconcile the already-published v18 after a read-only HTTP 429. Never saves a Place."""
import argparse,json,os,time
from pathlib import Path
from collections import Counter
from scene_sync import ROOT,read,write,require,sha,state_path,task,reconcile
from deploy import load_all,resolve
from sharded_scene_sync import capture_sharded,latest
from default_clone_delta import split_default_clones
from p45_transaction import equal
from resource_contact_publish import APPROVED,PLAN
from workspace import WorkspaceError
GAME=ROOT/"games/maps/mapa-principal"
def paced(*args,**kwargs):
    # This adapter is ONLY called by historical inventory reads and head probes.
    for delay in (0,15,30,60,90):
        if delay: time.sleep(delay)
        try: return task(*args,**kwargs)
        except WorkspaceError as exc:
            if "HTTP 429" not in str(exc): raise
            print("Read-only rate limit; backing off",flush=True)
    raise WorkspaceError("Read-only Roblox rate limit exhausted; no Place writes")
def main():
    p=argparse.ArgumentParser();p.add_argument("--artifact",type=Path,required=True);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    base=read(state_path(target));dest=GAME/"docs/s06/resource-contact-publish-v18"
    manifest=read(dest/"manifest.json");expected=read(dest/"expected.json")
    receipt=read(a.artifact/"s067-publish-apply/receipt.json");proof=read(a.artifact/"s067-publish-apply/verification.json")
    require(base["loadedVersion"]==17 and base["stateDigest"]==manifest["baseDigest"] and manifest["planDigest"]==APPROVED and receipt["planDigest"]==APPROVED and receipt["afterVersion"]==18 and receipt["status"]=="requires_reconciliation" and not receipt["retryAllowed"],"Publication receipt")
    require(expected["stateDigest"]==sha(expected["records"])==manifest["expectedDigest"] and proof["verified"] and proof["loadedVersion"]==18 and proof["stones"]==108 and proof["sticks"]==108 and proof["hits"]==1080 and proof["all49Restored"] and proof["noPlaceWrites"],"Persisted geometry proof")
    version=latest(target,key,request=paced);require(version==18,"Unexpected current staging head")
    actual,pages,calls=capture_sharded(target,key,version,request=paced)
    require(latest(target,key,request=paced)==version,"Head changed during read")
    scoped,clones=split_default_clones(expected,actual,reconcile(expected,actual)["external"])
    for d in scoped:
        k=d["key"];require(k in expected["records"] and k in actual["records"] and equal(expected["records"][k],actual["records"][k]),"Persisted mismatch "+k)
    classes=Counter(r["class"] for r in actual["records"].values() if "class" in r)
    summary={k:actual[k] for k in ("schemaVersion","universeId","placeId","loadedVersion","stateDigest","total")}
    summary.update(classes=dict(classes),workspaceRoots=[{"name":v["name"],"class":v["class"],"key":k,"managedId":v["managedId"]} for k,v in actual["records"].items() if v.get("service")=="Workspace" and len(v["path"])==1],terrain={k:v for k,v in actual["records"].items() if k.startswith("terrain:")},coverageNote="Scoped inventory, not full backup. Sharded observed state.")
    write(state_path(target),actual);write(state_path(target).with_suffix(".summary.json"),summary)
    receipt.update(status="verified",afterDigest=actual["stateDigest"],total=actual["total"],defaultCloneDelta=len(clones),shardedCalls=calls,reconciliationReadOnly=True)
    write(dest/"publication-receipt.json",receipt);write(dest/"persisted-verification.json",proof)
    print("S067_RECONCILED "+json.dumps(receipt),flush=True)
if __name__=="__main__":main()
