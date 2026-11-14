"""S08.5: shared white roughness map, guarded native staging transaction."""
import argparse,base64,json,os,sys,subprocess
from scene_sync import ROOT,task,write,require,read
from deploy import load_all,resolve
from sharded_scene_sync import latest
from s084_foliage_preview import retry
sys.path.insert(0,str(ROOT/"tools/asset_factory"))
from s08_prop_intake import submit,commit,RECEIPTS,sha
from PIL import Image

def main():
    p=argparse.ArgumentParser();p.add_argument("--publish",action="store_true");args=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];out=ROOT/"dist/s085"
    require(retry(lambda:latest(target,key))==23,"Expected staging v23")
    source="do\n"+(ROOT/"tools/sync/s085_foliage_matte.luau").read_text()+"\nend"
    owner=retry(lambda:task(target,key,"do\nreturn syncResult({creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})\nend",read_version=23,compile_source=True))
    require(owner["creatorId"]=="8136365379" and owner["creatorType"]=="User","Asset owner")
    path=ROOT/"asset-library/approved/foliage-matte/v1/roughness-white.png"
    if not path.exists():
        path.parent.mkdir(parents=True,exist_ok=True)
        Image.new("RGB",(64,64),(255,255,255)).save(path)
        commit([path],"assets(s085): shared fully rough foliage map")
    im=Image.open(path).convert("RGB")
    require(im.size==(64,64) and im.getextrema()==((255,255),(255,255),(255,255)),"White map")
    receipt=submit(key,owner["creatorId"],owner["creatorType"],"foliage-matte-roughness-v1",path,"Image")
    require(receipt["state"]=="created","Image upload")
    uri="rbxassetid://"+receipt["assetId"]
    print("S085_TEXTURE",uri,flush=True)
    out.mkdir(parents=True,exist_ok=True)
    template=out/"matte-surface.rbxm"
    subprocess.run(["cargo","run","--quiet","--manifest-path",str(ROOT/"tools/assets/rbx-author/Cargo.toml"),"--","--matte-template",str(template),"rbxassetid://89626593244521",uri],check=True,timeout=300)
    blob=base64.b64encode(template.read_bytes()).decode()
    require(len(blob)<16000,"Material-only template budget")
    def native(mode,version,**opts):
        return task(target,key,source,read_version=version,compile_source=True,mode=mode,roughnessUri=uri,surfaceBlob=blob,**opts)
    preview=retry(lambda:native("preview",23))
    write(out/"preview.json",preview)
    expected={"tree":250,"pine":16,"bush":200}
    require(preview["noPlaceWrites"] and preview["readyForStaging"] and preview["counts"]==expected and preview["geometryUnchanged"] and preview["meshPartsAdded"]==0 and preview["roughnessUri"]==uri,"Preview")
    print("S085_PREVIEW",json.dumps({k:preview[k] for k in ("counts","roughnessUri","geometryUnchanged","meshPartsAdded")}),flush=True)
    if not args.publish:return
    require(retry(lambda:latest(target,key))==23,"Head changed")
    opts=dict(expectedFingerprint=preview["fingerprint"],expectedEnvironment=preview["environment"],expectedTerrain={r["id"]:r["digest"] for r in preview["terrain"]},expectedBefore=preview["before"],expectedAfter=preview["after"])
    write(out/"receipt.json",{"status":"started","beforeVersion":23,"retryAllowed":False})
    try:
        saved=native("apply",None,confirmStaging=True,journal=out/"cloud-task.json",**opts)
        require(saved["saved"] and saved["loadedVersion"]==23,"Save")
        require(retry(lambda:latest(target,key))==24,"Expected v24")
        proof=retry(lambda:native("verify",24,**opts))
        write(out/"verification.json",proof)
        require(proof["verified"] and proof["after"]==preview["after"] and proof["counts"]==expected and proof["geometryUnchanged"],"Readback")
        result={"status":"verified","beforeVersion":23,"afterVersion":24,"counts":expected,"roughnessUri":uri,"meshPartsAdded":0,"clientRenderVerified":False}
        write(out/"receipt.json",result)
        print("S085_PUBLISHED",json.dumps(result),flush=True)
    except Exception:
        write(out/"receipt.json",{"status":"requires_reconciliation","beforeVersion":23,"retryAllowed":False})
        raise
if __name__=="__main__":main()
