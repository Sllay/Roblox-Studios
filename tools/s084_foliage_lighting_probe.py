"""Inspect live staging v23 foliage surface properties without writes."""
import json,os
from scene_sync import ROOT,task,write,require
from deploy import load_all,resolve
from s084_foliage_preview import retry
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    src="do\n"+(ROOT/"tools/sync/s084_foliage_lighting_probe.luau").read_text()+"\nend"
    r=retry(lambda:task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],src,read_version=23,compile_source=True))
    require(r["noPlaceWrites"] and r["count"]==250,"Scope")
    write(ROOT/"dist/s084-lighting/proof.json",r)
    print("S084_LIGHTING",json.dumps(r),flush=True)
if __name__=="__main__":main()
