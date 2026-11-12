"""Installed asset dependency proof and reconciliation of the original intake.
Preload success is not a client-render or permission-to-edit claim.
"""
import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,task,read,write,require,state_path
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,default=ROOT/"dist/s06-5");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+(ROOT/"tools/sync/asset_runtime_audit.luau").read_text()+"\nend",read_version=base["loadedVersion"],compile_source=True)
    require(r["loadedVersion"]==16 and r["models"]==390 and r["noPlaceWrites"] and not r["clientRenderVerified"],"Audit scope")
    intake=read(GAME/"game/assets/intake-p4.json")["assets"]
    rows=[]
    for a0 in intake:
        aid=a0["id"];n=r["assetCounts"].get(aid,0)
        state="installed_visual_subset" if n else "catalog_only_not_installed"
        if aid=="11946229834":state="first_party_wind_reimplementation_no_pack_code"
        if aid=="9204066145" and n:state="inert_component_only"
        rows.append({"id":aid,"name":a0["name"],"installedModels":n,"state":state,"historicalSecurity":a0["securityStatus"],"historicalInventory":a0["auditEvidence"]["inventoryStatus"],"clientRenderVerified":False})
    r["intake"]=rows
    r["dependencyCounts"]={"total":len(r["dependencies"]),"success":sum(x["preload"]=="Success" or x["fetch"]=="Success" for x in r["dependencies"]),"unreadableProperties":len(r["issues"])}
    write(a.output/"asset-runtime-audit.json",r)
    print("S065_ASSETS "+json.dumps({k:r[k] for k in ("models","assetCounts","dependencyCounts","intake","noPlaceWrites")}),flush=True)
if __name__=="__main__":main()
