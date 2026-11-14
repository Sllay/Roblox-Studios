"""Version-pinned S08.2 native audit and placement preview."""
import os,json
from scene_sync import ROOT,task,write,require
from deploy import load_all,resolve
from sharded_scene_sync import latest
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    version=latest(target,key);require(version==20,"Expected S08.1 v20")
    source="do\n"+(ROOT/"tools/sync/s082_preview.luau").read_text()+"\nend"
    audit=task(target,key,source,read_version=version,compile_source=True,mode="audit")
    write(ROOT/"dist/s082/audit.json",audit);print("S082_AUDIT",json.dumps(audit),flush=True)
    result=task(target,key,source,read_version=version,compile_source=True,mode="preview")
    write(ROOT/"dist/s082/preview.json",result)
    print("S082_PREVIEW",json.dumps({**{k:v for k,v in result.items() if k not in ("terrain","logs")},"logs":{k:v for k,v in result["logs"].items() if k!="rows"}}),flush=True)
    require(result["readyForStaging"] and result["logs"]["count"]==250 and result["noPlaceWrites"],"Preview gate")
if __name__=="__main__":main()
