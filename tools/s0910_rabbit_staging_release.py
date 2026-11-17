"""S09.10 Rabbit V3: incremental staging-only Place installation with durable one-shot save.

Use --preview for a detached no-save rehearsal. --publish requires all gates,
journals intent to the feature branch BEFORE cloud POST, then verifies V32 by GET.
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
OUT=ROOT/"dist/s0910-rabbit-stage"
RECEIPT=GAME/"docs/s09/publication-rabbit-v32.json"
V31=GAME/"docs/s09/publication-v31.json"
SCRIPT=ROOT/"tools/sync/s0910_rabbit_staging_release.luau"
BRANCH="feat/creature-factory-next"
MODEL="87498816533548"
MODULES=("CreatureRegistry","WildlifeProfiles","SpawnPolicy","FaunaService",
         "BookGameplay","BookServer","RobloxMobAdapter","SpawnDirector","FeatureFlags")

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
    paths.extend([(SRC/"ServerScriptService/CreatureBootstrap.server.luau","CreatureBootstrap","Script","Server"),
                  (SRC/"StarterPlayer/StarterPlayerScripts/CreatureVisual.client.luau","CreatureVisual","LocalScript","Client")])
    for path,name,cl,scope in paths:
        text=path.read_text(encoding="utf-8")
        rows.append(dict(name=name,scope=scope,id="s095-"+name.lower(),**{"class":cl},
                         source=text,hash=base64.b64encode(hashlib.sha256(text.encode()).digest()).decode()))
    require(len(rows)==11 and len({x["id"] for x in rows})==11,"Fixed reviewed scope only")
    return rows

def main():
    a=argparse.ArgumentParser()
    group=a.add_mutually_exclusive_group(required=True)
    group.add_argument("--preview",action="store_true")
    group.add_argument("--publish",action="store_true")
    args=a.parse_args()
    previous=json.loads(V31.read_text())
    require(previous["status"]=="verified" and previous["afterVersion"]==31,"Verified V31 prerequisite")
    rows=sources()
    expected_old={row["id"]:previous["sourceHashes"][row["id"]] for row in rows}
    require(all(expected_old.values()),"Missing V31 source hashes")
    require(not args.publish or not RECEIPT.exists(),"One-shot Rabbit V32 receipt exists; reconcile, do not replay")
    games,targets=load_all()
    target=resolve(games,targets,"mapa-principal","main","staging")
    require(target["universeId"]=="10769712441" and target["placeId"]=="93428341652658","Staging identity")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    source="do\n"+SCRIPT.read_text()+"\nend"
    current=latest(target,key)
    require(current==31,"Expected V31. Current Place version: "+str(current))
    opts=dict(sources=rows,oldHashes=expected_old,modelAssetId=MODEL)
    def native(mode,version,**kwargs):
        return task(target,key,source,read_version=version,compile_source=True,mode=mode,**opts,**kwargs)
    preview=native("preview",31)
    write(OUT/"preview.json",preview)
    require(preview["readyForStaging"] and preview["noPlaceWrites"] and preview["movementProbe"] and preview["brainProbe"],"Native smoke failed")
    require(preview["geometry"]["meshCount"]==9 and preview["geometry"]["bones"]==19 and preview["geometry"]["whiskers"]==6,"Model mismatch")
    require(preview["terrainRegions"]==49 and preview["rabbitMaximum"]==8 and preview["rabbitInitial"]==4,"Policy/terrain gate")
    print("RABBIT_STAGING_PREVIEW_PASS",json.dumps({k:preview[k] for k in ("rabbitModelId","rabbitInitial","rabbitMaximum","movementProbe","brainProbe","terrainRegions")}),flush=True)
    if args.preview:return
    require(latest(target,key)==31,"Place changed between preview and write; stop")
    # Freeze the preview digest and record user-approved one-shot save intent before touching Roblox.
    receipt=dict(schema=1,status="started",beforeVersion=31,environment="staging",
                 targetUniverse=target["universeId"],targetPlace=target["placeId"],
                 modelAssetId=MODEL,expectedAfterVersion=32,runId=os.environ.get("GITHUB_RUN_ID"),
                 saved=False,retryAllowed=False,clientFPSVerified=False,
                 sourceHashes=preview["sourceHashes"],terrainDigests=preview["terrainDigests"])
    atomic_json(RECEIPT,receipt)
    commit([RECEIPT],"intent(s0910): one-shot RabbitV3 staging V32 Place update")
    try:
        saved=native("apply",None,expectedTerrain=preview["terrainDigests"],
                     confirmStaging=True,journal=OUT/"save-task.json")
        write(OUT/"save-result.json",saved)
        require(saved["saved"] and saved["rabbitModelId"]==MODEL,"Native save result")
        require(latest(target,key)==32,"Rabbit V32 was not confirmed")
        verified=native("verify",32,expectedTerrain=preview["terrainDigests"])
        write(OUT/"verification.json",verified)
        require(verified["verified"] and verified["geometry"]["meshCount"]==9 and
                verified["geometry"]["bones"]==19 and verified["geometry"]["whiskers"]==6,
                "Version32 template readback mismatch")
        require(verified["sourceHashes"]==preview["sourceHashes"] and
                verified["terrainDigests"]==preview["terrainDigests"],"Source or terrain changed")
        require(latest(target,key)==32,"Staging head changed after verification")
        receipt.update(status="verified",saved=True,afterVersion=32,
                       verification=verified,runtimeSmokeVerified=True)
        atomic_json(RECEIPT,receipt)
        commit([RECEIPT],"evidence(s0910): RabbitV3 verified in staging Place V32")
        print("RABBIT_STAGING_PUBLISHED",json.dumps({k:receipt[k] for k in ("status","afterVersion","modelAssetId","runtimeSmokeVerified")}),flush=True)
    except Exception as error:
        receipt.update(status="requires_reconciliation",error=str(error)[:500])
        atomic_json(RECEIPT,receipt)
        commit([RECEIPT],"evidence(s0910): Rabbit staging update requires reconciliation")
        raise

if __name__=="__main__":
    main()
