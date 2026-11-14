"""Read-only check whether existing third-party canopy planes can be separated."""
import os,json
from scene_sync import ROOT,task,write,require
from deploy import load_all,resolve
from s084_foliage_preview import retry
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    source="do\n"+(ROOT/"tools/sync/s084_foliage_split_probe.luau").read_text()+"\nend"
    r=retry(lambda:task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],source,read_version=23,compile_source=True))
    require(r["noPlaceWrites"] and r["trees"]==250 and len(r["species"])==4,"Scope")
    write(ROOT/"dist/s084-split/probe.json",r)
    print("S084_SPLIT",json.dumps(r),flush=True)
if __name__=="__main__":main()
