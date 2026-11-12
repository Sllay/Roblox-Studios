"""Read-only exact visual component inventory/extraction. No scripts executed."""
import argparse,base64,hashlib,json,os,sys
from pathlib import Path
from pipeline import ROOT,check_id
from pack import validate_selector
from scene_sync import task,read,write,require,state_path
from deploy import load_all,resolve
SOURCE=Path(__file__).with_suffix(".luau")
def call(target,key,version,asset,mode,selector=None):
    check_id(asset)
    opts={"componentMode":mode,"assetId":asset}
    if selector is not None:opts["selector"]=validate_selector(selector)
    r=task(target,key,"do\n"+SOURCE.read_text()+"\nend",read_version=version,compile_source=True,**opts)
    require(r["assetId"]==asset and r["loadedVersion"]==version and r["noPlaceWrites"] is True and r["codeExecuted"] is False,"Component result scope")
    if mode=="extract" and r["status"]=="extracted":
        require(r["source"]["selector"]==selector,"Component selector mismatch")
        require(r["roundtripVerified"] and r["importAuthorized"] is False and r["outputClasses"].count("MeshPart")==1 and set(r["outputClasses"])<={"MeshPart","SurfaceAppearance"},"Unsafe component")
        blob=base64.b64decode(r.pop("serializedBase64"),validate=True)
        require(blob.startswith(b"<roblox!") and base64.b64encode(hashlib.sha256(blob).digest()).decode()==r["digest"],"Component serialization digest")
    return r
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("mode",choices=["inventory","extract"]);p.add_argument("--asset-id",required=True);p.add_argument("--selector",type=Path);p.add_argument("--output",type=Path,default=ROOT/"dist/component");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    require(a.mode=="inventory" or a.selector is not None,"Exact selector required")
    r=call(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],base["loadedVersion"],a.asset_id,a.mode,json.loads(a.selector.read_text()) if a.selector else None)
    write(a.output/(a.mode+".json"),r);print("COMPONENT "+json.dumps(r),flush=True)
if __name__=="__main__":main()
