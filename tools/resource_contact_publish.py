"""S06.7: publish only the exact reviewed v17 resource contact plan to staging."""
import argparse, hashlib, json, os
from pathlib import Path
from collections import Counter
from scene_sync import ROOT,read,write,require,sha,state_path,task,key_for,reconcile
from deploy import load_all,resolve
from sharded_scene_sync import capture_sharded,latest
from default_clone_delta import split_default_clones
from p45_transaction import equal
from cloud_tasks import atomic_json
GAME=ROOT/"games/maps/mapa-principal"
PLAN=GAME/"docs/s06/resource-contact-scaled-v17/contact-fix-preview.json"
APPROVED="4fe7b59ac7488dc1bcd26a8e50bbc8d854cccf3239ad7c0a6a25243b64334b79"
def expected_from(base,r):
    records=dict(base["records"])
    for x in r["removed"]: del records[key_for(x)]
    for x in r["changed"]: records[key_for(x)]=x
    for t in r["terrain"]: records["terrain:"+t["id"]]=t
    records["environment:lighting"]=r["lighting"];records["environment:workspace"]=r["workspaceSettings"]
    return {**base,"total":r["afterTotal"],"records":records,"stateDigest":sha(records)}
def scope(base,expected,opts):
    ids={r["id"] for r in opts["rows"]}
    changed_tiles={r["id"] for r in opts["expectedTerrainRows"] if base["records"]["terrain:"+r["id"]]["digest"]!=r["digest"]}
    require(len(changed_tiles)==9,"Terrain scope")
    seen=set()
    for d in reconcile(base,expected)["external"]:
        k=d["key"]
        if k.startswith("terrain:"):
            require(k[8:] in changed_tiles,"Unexpected terrain delta");continue
        for r in (base["records"].get(k),expected["records"].get(k)):
            require(r is not None,"Object created/deleted")
            names=[x["name"] for x in r.get("path",[])]
            require(r.get("service")=="Workspace" and len(names)>=3 and names[:2]==["RSResourcesP45","Models"] and names[2] in ids,"Unexpected scope "+k)
            seen.add(names[2])
    require(seen==ids,"All resources accounted for")
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=True)
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    base=read(state_path(target));plan=read(PLAN)
    require(base["loadedVersion"]==17 and base["stateDigest"]==sha(base["records"])==plan["stateDigest"],"Baseline")
    require(plan["planDigest"]==APPROVED==sha({k:v for k,v in plan.items() if k!="planDigest"}),"Reviewed plan digest")
    require(plan["all49Restored"] and plan["resourceInverse"] and plan["noPlaceWrites"] and len(plan["rows"])==216 and not plan["overlapPairs"] and plan["extraPaintColumns"]==288 and not plan["finalGrassSamples"],"Preview proof")
    old=read(GAME/"docs/s06/resources-v16/plan.json")
    original={r["id"]:r for r in old["resources"]}
    rows=[{**r,"voxelGroundY":original[r["id"]]["groundY"]} for r in plan["rows"]]
    require(Counter(r["category"] for r in rows)=={"stone":108,"stick":108} and all(r["burial"]==0 and r["scaleRatio"]==(2 if r["category"]=="stick" else 1) and r["offset"]==[0,0] for r in rows),"Resource invariants")
    opts={"rows":rows,"patches":old["patches"],"extraPaint":plan["extraPaint"],"baseTotal":base["total"],"terrainExpected":{k[8:]:v["digest"] for k,v in base["records"].items() if k.startswith("terrain:")},"expectedTerrain":{r["id"]:r["digest"] for r in plan["expectedTerrain"]}}
    scope_opts={**opts,"expectedTerrainRows":plan["expectedTerrain"]}
    src="do\n"+(ROOT/"tools/sync/resource_contact_publish.luau").read_text()+"\nend"
    require(latest(target,key)==17,"Fresh staging head")
    r=task(target,key,src,read_version=17,compile_source=True,mode="preview",**opts)
    require(r["loadedVersion"]==17 and r["inverseVerified"] and r["noPlaceWrites"],"Exact transaction inverse")
    expected=expected_from(base,r);scope(base,expected,scope_opts)
    require(sum("class" in x for x in expected["records"].values())==expected["total"],"Complete inventory")
    manifest={"version":17,"baseDigest":base["stateDigest"],"planDigest":APPROVED,"sourceHash":hashlib.sha256(src.encode()).hexdigest(),"beforeFingerprint":r["beforeFingerprint"],"afterFingerprint":r["afterFingerprint"],"expectedDigest":expected["stateDigest"],"expectedTotal":expected["total"],"inverseVerified":True}
    write(a.output/"manifest.json",manifest);write(a.output/"expected.json",expected)
    require(latest(target,key)==17,"Head changed before save")
    receipt={**manifest,"status":"started","retryAllowed":False}
    with (a.output/"receipt.json").open("x") as o: json.dump(receipt,o);o.flush();os.fsync(o.fileno())
    try:
        saved=task(target,key,src,compile_source=True,journal=a.output/"cloud-task.json",mode="apply",confirmStaging=True,beforeFingerprint=manifest["beforeFingerprint"],afterFingerprint=manifest["afterFingerprint"],**opts)
        require(saved["saved"] and saved["loadedVersion"]==17,"Save receipt")
        version=latest(target,key);require(version==18,"Expected v18")
        receipt.update(status="saved_pending_verification",afterVersion=version);atomic_json(a.output/"receipt.json",receipt)
        proof=task(target,key,src,read_version=version,compile_source=True,mode="verify",**opts)
        require(proof["verified"] and proof["loadedVersion"]==version and proof["noPlaceWrites"] and proof["stones"]==108 and proof["sticks"]==108 and proof["hits"]==1080 and proof["all49Restored"],"Persisted physical proof")
        write(a.output/"verification.json",proof)
        actual,pages,calls=capture_sharded(target,key,version);write(a.output/"after.json",actual)
        require(latest(target,key)==version,"Head changed")
        scoped,clones=split_default_clones(expected,actual,reconcile(expected,actual)["external"])
        for d in scoped:
            k=d["key"];require(k in expected["records"] and k in actual["records"] and equal(expected["records"][k],actual["records"][k]),"Persisted mismatch "+k)
        classes=Counter(r["class"] for r in actual["records"].values() if "class" in r)
        summary={k:actual[k] for k in ("schemaVersion","universeId","placeId","loadedVersion","stateDigest","total")}
        summary.update(classes=dict(classes),workspaceRoots=[{"name":v["name"],"class":v["class"],"key":k,"managedId":v["managedId"]} for k,v in actual["records"].items() if v.get("service")=="Workspace" and len(v["path"])==1],terrain={k:v for k,v in actual["records"].items() if k.startswith("terrain:")},coverageNote="Scoped inventory, not full backup. Sharded observed state.")
        write(state_path(target),actual);write(state_path(target).with_suffix(".summary.json"),summary)
        receipt.update(status="verified",afterDigest=actual["stateDigest"],total=actual["total"],defaultCloneDelta=len(clones),shardedCalls=calls)
        atomic_json(a.output/"receipt.json",receipt);print("S067_VERIFIED "+json.dumps(receipt),flush=True)
    except Exception:
        receipt["status"]="requires_reconciliation";atomic_json(a.output/"receipt.json",receipt);raise
if __name__=="__main__":main()
