"""Read-only landmark placement measurement."""
import os,json
from scene_sync import ROOT,task,write,require
from deploy import load_all,resolve
from s084_foliage_preview import retry
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    src="do\n"+(ROOT/"tools/sync/s086_root_probe.luau").read_text()+"\nend"
    r=retry(lambda:task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],src,read_version=24,compile_source=True))
    require(r["noPlaceWrites"] and r["loadedVersion"]==24,"Scope")
    write(ROOT/"dist/s086/root-probe.json",r)
    print("S086_ROOT",json.dumps({k:v for k,v in r.items() if k!="samples"}),flush=True)
    print("S086_ROOT_SAMPLE_COUNT",len(r["samples"]),flush=True)
if __name__=="__main__":main()
