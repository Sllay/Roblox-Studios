"""Upload the immutable 19k triangle skinned rabbit and probe the Roblox staging importer.

No Place writes. Upload is one-shot and receipt-journaled. Asset ID is saved to Git.
Uses existing authenticated Open Cloud helper and native scene_sync, without cookies.
"""
import hashlib,json,os,sys,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/"tools"),str(ROOT/"tools/asset_factory")]
import s08_prop_intake as api
from deploy import load_all,resolve
from scene_sync import task
ASSET=ROOT/"asset-library/candidates/rabbit-v3-cartoon-v2-mobile-lod0/asset.glb"
REPORT=ROOT/"asset-library/candidates/rabbit-v3-cartoon-v2-mobile-lod0/validation.json"
RECEIPTS=ROOT/"asset-library/roblox-receipts/s0910-rabbit"
SHA="779ac4210bf77c19e8ec40f79dab9f7439a9630522ffd88f990d27c0be026133"
api.RECEIPTS=RECEIPTS
BRANCH="feat/creature-factory-next"
def commit(paths,message):
    names=[str(Path(p).relative_to(ROOT)) for p in paths]
    subprocess.run(["git","add",*names],cwd=ROOT,check=True)
    if subprocess.run(["git","diff","--cached","--quiet"],cwd=ROOT).returncode==0:return
    subprocess.run(["git","commit","-m",message],cwd=ROOT,check=True)
    for _ in range(4):
        subprocess.run(["git","fetch","origin",BRANCH],cwd=ROOT,check=True)
        subprocess.run(["git","rebase","origin/"+BRANCH],cwd=ROOT,check=True)
        if subprocess.run(["git","push","origin","HEAD:refs/heads/"+BRANCH],cwd=ROOT).returncode==0:return
        time.sleep(3)
    raise RuntimeError("Could not persist asset receipt: STOP before more uploads")
api.commit=commit
def main():
    assert hashlib.sha256(ASSET.read_bytes()).hexdigest()==SHA
    report=json.loads(REPORT.read_text())
    assert report["status"]=="PASS_ASSET_ONLY" and report["triangles_total"]==19524
    g,targets=load_all();target=resolve(g,targets,"mapa-principal","main","staging")
    assert target["universeId"]=="10769712441" and target["placeId"]=="93428341652658"
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    info=task(target,key,"do\nreturn syncResult({creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})\nend",compile_source=True)
    assert info["noPlaceWrites"] and info["creatorId"]=="8136365379" and info["creatorType"]=="User"
    receipt=api.submit(key,info["creatorId"],info["creatorType"],"rabbit-v3-cartoon-v2-mobile-lod0",ASSET,"Model")
    assert receipt["state"]=="created" and str(receipt["assetId"]).isdigit()
    probe=(ROOT/"tools/sync/s0910_rabbit_native_probe.luau").read_text()
    last=None
    for attempt in range(4):
        try:
            last=task(target,key,probe,compile_source=True,assetId=str(receipt["assetId"]))
            break
        except Exception as error:
            if attempt==3:raise
            print("Imported asset probe deferred",str(error)[:250],flush=True)
            time.sleep(8)
    assert last and last["noPlaceWrites"]
    last.update({"sourceSha256":SHA,"runtimeValidated":False,"animationPlaybackValidated":False,
                 "assetCreatedId":receipt["assetId"],"stage":"native_import_probe"})
    p=RECEIPTS/"rabbit-native-proof.json";api.write(p,last)
    commit([p],"evidence(s0910): rabbit native skinned model import inspection")
    print("RABBIT_NATIVE_PROOF",json.dumps(last,sort_keys=True),flush=True)
    # The importer is allowed to differ; report failures rather than silently approving.
    assert last["scripts"]==0 and last["meshCount"]==9 and last["whiskers"]==6
    assert last["bones"]==19 and last["expectedBones"] and last["poseRoundtrip"]
    assert last["meshLoaded"]==9 and last["textureLoaded"]>=1
if __name__=="__main__":main()
