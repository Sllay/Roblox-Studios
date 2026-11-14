"""S09 static rig import alternative: new explicit asset, not a retry of ambiguous multi-clip POST."""
import json,os,sys,hashlib,urllib.request,urllib.error,urllib.parse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/"tools"),str(ROOT/"tools/asset_factory")]
import s08_prop_intake as api
from scene_sync import task
from deploy import load_all,resolve
OWNER="8136365379"
BASE=ROOT/"asset-library/candidates/chicken-rig-43578265487-1/roblox-exports"
SHA="3d4c122b34e9fee090bb1ba53809b1d13a7dcde190e82bff627619fbee169723"
DIR=ROOT/"asset-library/roblox-receipts/s09"
api.RECEIPTS=DIR
NAME="chicken-v2-base-rig"
def main():
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    old=json.loads((DIR/"chicken-v2-rig.json").read_text())
    assert old["httpStatus"]==503 and not old.get("operationPath") and old["retryAllowed"]==False
    d=json.loads((DIR/"chicken-v2-api-diagnostics.json").read_text())
    assert d["probes"]["knownAssetMetadata"]["status"]==200
    path=BASE/"chicken-v2-base.glb";data=path.read_bytes();assert hashlib.sha256(data).hexdigest()==SHA
    j=api.glb(data);assert api.tris(j)==3120 and len(j["skins"][0]["joints"])==14 and not j.get("animations")
    games,targets=load_all();target=resolve(games,targets,"mapa-principal","main","staging")
    c=task(target,key,'do\nreturn syncResult({creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})\nend',read_version=25,compile_source=True)
    assert c["loadedVersion"]==25 and c["creatorId"]==OWNER and c["creatorType"]=="User" and c["noPlaceWrites"]
    # Reconcile visible model inventory by metadata, including nested item schemas.
    code,inv=api.request("https://apis.roblox.com/cloud/v2/users/"+OWNER+"/inventory-items?"+urllib.parse.urlencode({"filter":"inventoryItemAssetTypes=MODEL","maxPageSize":100}),key)
    matches=[];scanned=[];unresolved=[]
    def findid(row):
        item=row.get("assetDetails",{})
        return item.get("assetId") or row.get("assetId") or item.get("id")
    if code==200:
        for row in inv.get("inventoryItems",[]):
            aid=str(findid(row) or "")
            if not aid.isdigit():unresolved.append(list(row.keys()));continue
            s,m=api.request("https://apis.roblox.com/assets/v1/assets/"+aid,key)
            name=m.get("displayName");scanned.append({"assetId":aid,"status":s,"name":name})
            if name in ("Black Islands chicken-v2-rig","Black Islands "+NAME):matches.append({"assetId":aid,"name":name,"status":s})
    scan={"status":code,"scanned":scanned,"unresolvedSchemas":unresolved,"matches":matches,"nextPage":bool(inv.get("nextPageToken")),"inventoryAuthoritative":False,"noPlaceWrites":True}
    p=DIR/"chicken-v2-alternative-scan.json";api.write(p,scan);api.commit([p],"evidence(s09): compare owned model metadata before distinct base import")
    # Original multi-clip asset is not retried. Static base is an independent production artifact.
    base_matches=[x for x in matches if x["name"]=="Black Islands "+NAME and x["status"]==200]
    if base_matches:
        assert len(base_matches)==1;aid=base_matches[0]["assetId"]
    else:
        receipt=api.submit(key,OWNER,"User",NAME,path,"Model")
        assert receipt["state"]=="created";aid=receipt["assetId"]
    src=(ROOT/"tools/sync/s09_chicken_native.luau").read_text()
    proof=task(target,key,src,read_version=25,compile_source=True,assetId=aid)
    proof.update(sourceSha256=SHA,assetId=aid,clientRenderVerified=False,animationPlaybackVerified=False,originalMultiClipReceiptUnchanged=True)
    dest=DIR/"chicken-v2-base-native-proof.json";api.write(dest,proof);api.commit([dest],"evidence(s09): isolated static rig native proof")
    print(json.dumps(proof,indent=2))
    assert proof["noPlaceWrites"] and proof["meshes"]==1 and proof["scripts"]==0 and proof["meshLoaded"] and proof["bones"]==14 and proof["expectedBoneNames"] and proof["poseRoundtrip"] and proof["textureLoaded"]
if __name__=="__main__":main()
