"""Read-only S08 integration preview against the freshly observed staging head."""
import os,json,time
from scene_sync import ROOT,read,write,require,task
from deploy import load_all,resolve
from sharded_scene_sync import latest
from workspace import WorkspaceError
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    reg=read(ROOT/"games/maps/mapa-principal/game/assets/prop-registry-s08-candidates.json")
    require(reg["status"]=="candidate-only" and not reg["writeAuthorized"],"Candidate contract")
    version=latest(target,key)
    require(version>=19,"S07 population not published")
    src=(ROOT/"tools/sync/s08_integration_preview.luau").read_text()
    for delay in (15,30,60,120,None):
        try:
            result=task(target,key,"do\n"+src+"\nend",read_version=version,compile_source=True,assets=reg["props"])
            break
        except WorkspaceError as exc:
            if "HTTP 429:" not in str(exc) or delay is None:raise
            time.sleep(delay)
    require(result["loadedVersion"]==version and result["noPlaceWrites"],"Disposable contract")
    require(latest(target,key)==version,"Staging changed during preview")
    write(ROOT/"dist/s08-integration/preview.json",result)
    print(json.dumps({k:v for k,v in result.items() if k!="terrain"}),flush=True)
    require(result["readyForVisualReview"],"Preview needs support/site correction; see artifact")
if __name__=="__main__":main()
