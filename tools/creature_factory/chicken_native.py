"""S09 isolated original chicken import; durable one-shot intent; never saves a Place."""
import json,os,sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tools"))
sys.path.insert(0,str(ROOT/"tools/asset_factory"))
import s08_prop_intake as intake
from deploy import load_all,resolve
from scene_sync import task
BASE=ROOT/"asset-library/candidates/chicken-rig-43578265487-1"
SHA="ea0ebd42c7ea7a6b7ec6bf7c976edb2a1e91e205f83a017b21c9e5bc48121466"
RECEIPTS=ROOT/"asset-library/roblox-receipts/s09"
intake.RECEIPTS=RECEIPTS
def main():
    path=BASE/"chicken-v2-rig.glb";report=json.loads((BASE/"report.json").read_text())
    assert hashlib.sha256(path.read_bytes()).hexdigest()==SHA==report["glbSha256"]
    assert report["restTriangleParity"] and report["independentBlenderReimport"] and report["bones"]==14 and report["renderMeshes"]==1 and len(report["clips"])==5
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    c=task(target,key,'do\nreturn syncResult({creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})\nend',read_version=25,compile_source=True)
    assert c["noPlaceWrites"] and c["loadedVersion"]==25 and c["creatorType"]=="User" and c["creatorId"]=="8136365379"
    r=intake.submit(key,c["creatorId"],c["creatorType"],"chicken-v2-rig",path,"Model")
    assert r["state"]=="created"
    code=(ROOT/"tools/sync/s09_chicken_native.luau").read_text()
    proof=task(target,key,code,read_version=25,compile_source=True,assetId=r["assetId"])
    proof.update(sourceSha256=SHA,assetId=r["assetId"],clientRenderVerified=False,animationPlaybackVerified=False)
    dest=RECEIPTS/"chicken-v2-native-proof.json";intake.write(dest,proof);intake.commit([dest],"evidence(s09): detached chicken rig native proof")
    print(json.dumps(proof,indent=2))
    assert proof["noPlaceWrites"] and proof["meshes"]==1 and proof["scripts"]==0 and proof["meshLoaded"] and proof["bones"]==14 and proof["expectedBoneNames"] and proof["poseRoundtrip"] and proof["textureLoaded"],"Native import requires review; receipt retained"
if __name__=="__main__":main()
