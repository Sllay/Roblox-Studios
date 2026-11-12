import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,read,write,require,state_path,task
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    mod=(GAME/"game/places/main/src/ReplicatedStorage/RSBranchWind.luau").read_text()
    src=(ROOT/"tools/sync/branch_wind_probe.luau").read_text().replace("-- __RS_BRANCH_POLICY__","local B=(function()\n"+mod+"\nend)()")
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+src+"\nend",read_version=base["loadedVersion"],compile_source=True)
    require(r["nativeBoneTransforms"] and r["rootFixed"] and r["noPlaceWrites"] and r["loadedVersion"]==16,"Bone proof")
    write(a.output/"bone-proof.json",r);print("S064_BONES "+json.dumps(r),flush=True)
if __name__=="__main__":main()
