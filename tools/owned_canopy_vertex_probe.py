"""Retest already owned canopy after enabling Mesh/Image APIs; no asset POST."""
import argparse,json,os
from pathlib import Path
from scene_sync import ROOT,read,write,require,state_path,task
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    require(base["loadedVersion"]==16,"Expected staging v16")
    mod=(GAME/"game/places/main/src/ReplicatedStorage/RSCanopyDeform.luau").read_text()
    src=(ROOT/"tools/sync/owned_canopy_vertex_probe.luau").read_text().replace("-- __RS_DEFORM__","local D=(function()\n"+mod+"\nend)()")
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+src+"\nend",read_version=16,compile_source=True)
    require(r["loadedVersion"]==16 and r["noPlaceWrites"] and r["assetId"]=="91515745821527","Proof scope")
    write(a.output/"owned-vertex-proof.json",r);print("S064_VERTEX "+json.dumps(r),flush=True)
if __name__=="__main__":main()
