"""Read-only first-party wind policy evidence, not runtime client evidence."""
import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,task,read,write,require,state_path
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--output",type=Path,default=ROOT/"dist/s04");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    policy=(GAME/"game/places/main/src/ReplicatedStorage/RSWindPolicy.luau").read_text()
    src=(ROOT/"tools/sync/wind_policy_probe.luau").read_text().replace("-- __RS_WIND_POLICY__","local Policy=(function()\n"+policy+"\nend)()")
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+src+"\nend",read_version=base["loadedVersion"],compile_source=True,policySource=policy)
    require(r["noPlaceWrites"] and not r["clientMotionVerified"] and r["eligible"]==162 and r["loadedVersion"]==base["loadedVersion"],"Wind policy coverage")
    write(a.output/"wind-proof.json",r);print("S04_WIND "+json.dumps(r),flush=True)
if __name__=="__main__":main()
