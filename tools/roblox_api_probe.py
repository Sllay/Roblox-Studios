"""Run a checked-in, read-only API probe on an explicitly pinned staging version."""
import argparse,json,os
from pathlib import Path
from scene_sync import ROOT,read,write,require,state_path
from deploy import load_all,resolve
from cloud_tasks import run_task
SOURCE=ROOT/"tools/sync/api_probe.luau"
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--version",type=int)
    p.add_argument("--output",type=Path,default=ROOT/"dist/api-probe")
    a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    baseline=read(state_path(target))
    version=a.version or baseline["loadedVersion"]
    require(1<=version<=baseline["loadedVersion"],"Only known staging history")
    cfg=json.dumps({"universeId":target["universeId"],"placeId":target["placeId"]},separators=(",",":"))
    src=SOURCE.read_text()
    require(src.count("__RS_CONFIG__")==1 and "SavePlaceAsync(" not in src,"Probe contract")
    result=run_task(target["universeId"],target["placeId"],os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],src.replace("__RS_CONFIG__","[=["+cfg+"]=]"),read_version=version)
    require(result["loadedVersion"]==version and result["noPlaceWrites"] is True and result["context"]=="headless_edit","Probe result contract")
    write(a.output/f"v{version}.json",result)
    print("API_PROBE "+json.dumps(result),flush=True)
if __name__=="__main__":main()
