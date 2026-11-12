import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,task,read,write,require,state_path
from deploy import load_all,resolve
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,default=ROOT/"dist/s06-5");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+(ROOT/"tools/sync/default_cleanup_preview.luau").read_text()+"\nend",read_version=base["loadedVersion"],compile_source=True,expectedTotal=base["total"])
    require(r["loadedVersion"]==16 and r["restoredExact"] and r["noPlaceWrites"] and not r["runtimeSafeDeletionVerified"],"Recovery proof")
    write(a.output/"default-cleanup-proof.json",r);print("S065_CLEANUP "+json.dumps(r),flush=True)
if __name__=="__main__":main()
