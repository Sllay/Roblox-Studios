"""S09.10 Rabbit V34: incremental staging-only animation update with one-shot save.

Use --preview for a detached no-save rehearsal. --publish requires all gates,
journals intent to the feature branch BEFORE cloud POST, then verifies V33 by GET.
Never rerun an uncertain save. Never modifies the production Place or main.
"""
import argparse,base64,hashlib,json,os,subprocess,sys,time
from pathlib import Path
from scene_sync import ROOT,task,write,require
from cloud_tasks import atomic_json
from deploy import load_all,resolve
from sharded_scene_sync import latest

GAME=ROOT/"games/maps/mapa-principal"
SRC=GAME/"game/places/main/src"
OUT=ROOT/"dist/s0910-rabbit-v34-stage"
RECEIPT=GAME/"docs/s09/publication-rabbit-v34.json"
V33=GAME/"docs/s09/publication-rabbit-v32.json"
SCRIPT=ROOT/"tools/sync/s0910_rabbit_v34_release.luau"
PROOF=ROOT/"asset-library/roblox-receipts/s0910-rabbit-v38/rabbit-animations-published.json"
V31=GAME/"docs/s09/publication-v31.json"
BRANCH="feat/creature-factory-next"
MODEL="87498816533548"
MODULES=("CreatureRegistry","RobloxMobAdapter","MobBrain")

def commit(paths,message):
    files=[str(Path(path).relative_to(ROOT)) for path in paths]
    subprocess.run(["git","add",*files],cwd=ROOT,check=True)
    if subprocess.run(["git","diff","--cached","--quiet"],cwd=ROOT).returncode==0:return
    subprocess.run(["git","commit","-m",message],cwd=ROOT,check=True)
    for i in range(4):
        subprocess.run(["git","fetch","origin",BRANCH],cwd=ROOT,check=True)
        subprocess.run(["git","rebase","origin/"+BRANCH],cwd=ROOT,check=True)
        if subprocess.run(["git","push","origin","HEAD:refs/heads/"+BRANCH],cwd=ROOT).returncode==0:return
        time.sleep(3)
    raise RuntimeError("Receipt could not be persisted: STOP, do not resubmit any Place task")

def sources():
    rows=[]
    paths=[(SRC/"ServerScriptService/CreatureFramework"/(name+".luau"),name,"ModuleScript","Module") for name in MODULES]
    for path,name,cl,scope in paths:
        text=path.read_text(encoding="utf-8")
        rows.append(dict(name=name,scope=scope,id="s095-"+name.lower(),**{"class":cl},
                         source=text,hash=base64.b64encode(hashlib.sha256(text.encode()).digest()).decode()))
    require(len(rows)==3 and len({x["id"] for x in rows})==3,"V34 changes only Rabbit registry, adapter and shared MobBrain")
    return rows

def main():
    a=argparse.ArgumentParser()
    group=a.add_mutually_exclusive_group(required=True)
    group.add_argument("--preview",action="store_true")
    group.add_argument("--publish",action="store_true")
    args=a.parse_args()
    previous=json.loads(V33.read_text())
    require(previous["status"]=="verified" and previous["saved"] is True and previous["afterVersion"]==33,"Verified V33 prerequisite")
    proof=json.loads(PROOF.read_text())
    require(proof["playbackVerified"] and proof["stagingPlaceWritten"] is False,"Four native clips must be verified")
    ids=proof["animations"]
    require(set(ids)=={"Idle","Walk","Run","ScratchEar"},"Exact reviewed animation scope")
    rows=sources()
    # V33 receipt records two modified modules; MobBrain was unchanged
    # since V31. Its exact verified source hash is the third old-hash gate.
    historical=json.loads(V31.read_text())
    require(historical["status"]=="verified" and historical["afterVersion"]==31,"Verified V31 source ancestry")
    existing={**historical["sourceHashes"],**previous["sourceHashes"]}
    expected_old={row["id"]:existing[row["id"]] for row in rows if row["id"] in existing}
    require(len(expected_old)==3 and len(rows)==3,"Expected three V33 source replacements")
    require(not args.publish or not RECEIPT.exists(),"One-shot Rabbit V33 receipt exists; reconcile, do not replay")
    games,targets=load_all()
    target=resolve(games,targets,"mapa-principal","main","staging")
    require(target["universeId"]=="10769712441" and target["placeId"]=="93428341652658","Staging identity")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    source="do\n"+SCRIPT.read_text()+"\nend"
    current=latest(target,key)
    require(current==33,"Expected V33. Current Place version: "+str(current))
    opts=dict(sources=rows,oldHashes=expected_old,modelAssetId=MODEL,animationIds=ids)
    def native(mode,version,**kwargs):
        return task(target,key,source,read_version=version,compile_source=True,mode=mode,**opts,**kwargs)
    preview=native("preview",33)
    write(OUT/"preview.json",preview)
    require(preview["readyForStaging"] and preview["noPlaceWrites"] and preview["movementProbe"] and preview["brainProbe"],"Native smoke failed")
    require(preview["animationIds"]==ids,"V34 preview did not validate the new animation IDs")
    require(preview["geometry"]["meshCount"]==9 and preview["geometry"]["bones"]==19 and preview["geometry"]["whiskers"]==6,"Model mismatch")
    require(preview["terrainRegions"]==49 and preview["rabbitMaximum"]==8 and preview["rabbitInitial"]==4,"Policy/terrain gate")
    print("RABBIT_STAGING_PREVIEW_PASS",json.dumps({k:preview[k] for k in ("rabbitModelId","rabbitInitial","rabbitMaximum","movementProbe","brainProbe","terrainRegions")}),flush=True)
    if args.preview:return
    require(latest(target,key)==33,"Place changed between preview and write; stop")
    # Freeze the preview digest and record user-approved one-shot save intent before touching Roblox.
    receipt=dict(schema=1,status="started",beforeVersion=33,environment="staging",
                 targetUniverse=target["universeId"],targetPlace=target["placeId"],
                 modelAssetId=MODEL,animationIds=ids,expectedAfterVersion=34,runId=os.environ.get("GITHUB_RUN_ID"),
                 saved=False,retryAllowed=False,clientFPSVerified=False,
                 sourceHashes=preview["sourceHashes"],terrainDigests=preview["terrainDigests"])
    atomic_json(RECEIPT,receipt)
    commit([RECEIPT],"intent(s0910): one-shot Rabbit V34 animation staging patch")
    try:
        saved=native("apply",None,expectedTerrain=preview["terrainDigests"],
                     confirmStaging=True,journal=OUT/"save-task.json")
        write(OUT/"save-result.json",saved)
        require(saved["saved"] and saved["rabbitModelId"]==MODEL,"Native save result")
        require(latest(target,key)==34,"Rabbit V34 was not confirmed")
        verified=native("verify",34,expectedTerrain=preview["terrainDigests"])
        write(OUT/"verification.json",verified)
        require(verified["verified"] and verified["geometry"]["meshCount"]==9 and
                verified["geometry"]["bones"]==19 and verified["geometry"]["whiskers"]==6,
                "Version33 template readback mismatch")
        require(verified["animationIds"]==ids,"V34 animation IDs changed")
        require(verified["sourceHashes"]==preview["sourceHashes"] and
                verified["terrainDigests"]==preview["terrainDigests"],"Source or terrain changed")
        require(latest(target,key)==34,"Staging head changed after verification")
        receipt.update(status="verified",saved=True,afterVersion=34,
                       verification=verified,runtimeSmokeVerified=True)
        atomic_json(RECEIPT,receipt)
        commit([RECEIPT],"evidence(s0910): Rabbit hop/scratch verified in staging V34")
        print("RABBIT_V34_STAGING_PUBLISHED",json.dumps({k:receipt[k] for k in ("status","afterVersion","modelAssetId","runtimeSmokeVerified")}),flush=True)
    except Exception as error:
        receipt.update(status="requires_reconciliation",error=str(error)[:500])
        atomic_json(RECEIPT,receipt)
        commit([RECEIPT],"evidence(s0910): Rabbit V34 requires reconciliation")
        raise

if __name__=="__main__":
    main()
