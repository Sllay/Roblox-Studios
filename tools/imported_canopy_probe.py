"""Read-only proof for the existing original canopy; no Assets POST."""
import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,read,write,require,task,state_path
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,default=ROOT/"dist/s06-4-imported");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    receipt=read(GAME/"docs/s06/wind-v16/permission-retry/upload-receipt.json")
    require(receipt["assetId"]=="91515745821527" and receipt["httpStatus"]==200 and receipt["operation"]["done"] and base["loadedVersion"]==16,"Reviewed asset scope")
    src="do\n"+(ROOT/"tools/sync/imported_canopy_probe.luau").read_text()+"\nend"
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],src,read_version=16,compile_source=True,assetId=receipt["assetId"])
    require(r["assetId"]==receipt["assetId"] and r["loadedVersion"]==16 and r["noPlaceWrites"] and not r["clientRenderVerified"],"Native proof scope")
    r["structureVerified"]=r["meshes"]==1 and r["bones"]>=20 and r["roots"]==1 and r["crowns"]==1 and r["boughs"]==r["transforms"]==18 and r["meshLoaded"] and r["scripts"]==0
    write(a.output/"imported-proof.json",r);print("S064_IMPORTED "+json.dumps(r),flush=True)
if __name__=="__main__":main()
