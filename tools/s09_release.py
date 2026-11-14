"""Owner-approved S09.5 staging-only incremental release. Never retry a Place save."""
import base64,hashlib,json,os,subprocess,sys,argparse
from pathlib import Path
from scene_sync import ROOT,task,read,write,require,state_path,sha
from sharded_scene_sync import latest,capture_sharded,default_forensics
from deploy import load_all,resolve
from s084_foliage_preview import retry
from cloud_tasks import atomic_json
GAME=ROOT/"games/maps/mapa-principal"
SYNC=GAME/"docs/sync/main"
OUT=ROOT/"dist/s09-release"
RECEIPT=GAME/"docs/s09/publication-v26.json"
SOURCE=GAME/"game/places/main/src"
BASE_DIGEST="cba2d30569d4d298c6cbb5667ec0a8fedaa8caef5462e85851e2e668a014b926"
def sources():
    files=[]
    def add(path,name,cls,scope):
        s=path.read_text();files.append({"name":name,"class":cls,"scope":scope,"id":"s095-"+name.lower(),"source":s,"hash":base64.b64encode(hashlib.sha256(s.encode()).digest()).decode()})
    for path in sorted((SOURCE/"ServerScriptService/CreatureFramework").glob("*.luau")):add(path,path.stem,"ModuleScript","Module")
    add(SOURCE/"ServerScriptService/CreatureBootstrap.server.luau","CreatureBootstrap","Script","Server")
    add(SOURCE/"StarterPlayer/StarterPlayerScripts/BookView.luau","BookView","ModuleScript","Client")
    add(SOURCE/"StarterPlayer/StarterPlayerScripts/RSBook.client.luau","RSBook","LocalScript","Client")
    require(len(files)==33,"Reviewed script scope");return files
def publish_file(path,msg):
    subprocess.run(["git","add",str(path)],cwd=ROOT,check=True)
    subprocess.run(["git","commit","-m",msg],cwd=ROOT,check=True)
    subprocess.run(["git","pull","--rebase","origin","main"],cwd=ROOT,check=True)
    subprocess.run(["git","push","origin","HEAD:main"],cwd=ROOT,check=True)
def main():
    p=argparse.ArgumentParser();p.add_argument("--publish",action="store_true");a=p.parse_args()
    require(a.publish,"Explicit staging publication approval")
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    require(target["placeId"]=="93428341652658" and target["universeId"]=="10769712441","Staging only")
    base=read(state_path(target));require(base["loadedVersion"]==25 and base["stateDigest"]==BASE_DIGEST and sha(base["records"])==BASE_DIGEST,"Fresh reviewed baseline")
    require(default_forensics(base)["allIdentical"] and default_forensics(base)["rootCount"]==19,"Default clone baseline")
    terrain={r["id"]:r["digest"] for k,r in base["records"].items() if k.startswith("terrain:")};require(len(terrain)==49,"Terrain baseline")
    require(not RECEIPT.exists(),"Existing durable release receipt; reconcile before any save")
    files=sources();src="do\n"+(ROOT/"tools/sync/s09_release.luau").read_text()+"\nend"
    opts=dict(sources=files,expectedTerrain=terrain)
    def native(mode,v,**extra):return task(target,key,src,read_version=v,compile_source=True,mode=mode,**opts,**extra)
    require(retry(lambda:latest(target,key))==25,"Head changed")
    preview=retry(lambda:native("preview",25));write(OUT/"preview.json",preview)
    require(preview["readyForStaging"] and preview["noPlaceWrites"] and preview["installedScripts"]==33 and preview["bones"]==14 and preview["enabled"] and preview["maximum"]==15 and preview["respawnSeconds"]==300,"Preview gate")
    print("S09_PREVIEW",json.dumps(preview),flush=True)
    require(retry(lambda:latest(target,key))==25,"Head changed")
    extra=dict(expectedFingerprint=preview["fingerprint"],expectedEnvironment=preview["environment"])
    receipt={"status":"started","release":"S09.5","environment":"staging","beforeVersion":25,"baselineDigest":BASE_DIGEST,"retryAllowed":False,"sourceHashes":preview["sourceHashes"],"runId":os.environ.get("GITHUB_RUN_ID"),"clientRenderVerified":False}
    atomic_json(RECEIPT,receipt);publish_file(RECEIPT,"intent(s09): one-shot owner-approved staging v26 save")
    try:
        saved=native("apply",None,confirmStaging=True,journal=OUT/"cloud-task.json",**extra)
        write(OUT/"save.json",saved);require(saved["saved"] and saved["loadedVersion"]==25,"Save receipt")
        require(retry(lambda:latest(target,key))==26,"Expected V26")
        proof=retry(lambda:native("verify",26,**extra));write(OUT/"verification.json",proof)
        require(proof["verified"] and proof["sourceHashes"]==preview["sourceHashes"] and proof["fingerprint"]==preview["fingerprint"] and proof["terrainRegions"]==49 and proof["enabled"],"Readback")
        require(retry(lambda:latest(target,key))==26,"Head drift")
        receipt.update(status="verified",afterVersion=26,verification=proof)
        atomic_json(RECEIPT,receipt);publish_file(RECEIPT,"evidence(s09): staging V26 verified creature release")
        print("S09_PUBLISHED",json.dumps(receipt),flush=True)
    except Exception as e:
        receipt.update(status="requires_reconciliation",error=str(e)[:500])
        atomic_json(RECEIPT,receipt);publish_file(RECEIPT,"evidence(s09): publication requires reconciliation")
        raise
if __name__=="__main__":main()
