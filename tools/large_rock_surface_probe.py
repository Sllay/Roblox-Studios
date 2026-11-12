"""Read-only actual support audit for the six large rocks, reuse exact terrain rehydration."""
import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,read,write,require,task,state_path
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target));require(base["loadedVersion"]==17,"Expected v17")
    old=read(GAME/"docs/sync/main/patches/p4-detail-layout-reviewed.json")
    rows=[{**r,"category":"large_rock"} for r in old["rows"] if r["name"]=="Mossy_Rock1_M_Mossy_Rock_0_Node"]
    require(len(rows)==6,"Six exact rock identities")
    patches=[{"center":[round(r["position"][0]/4)*4,round(r["position"][2]/4)*4]} for r in rows]
    source=(ROOT/"tools/sync/resource_surface_rebuild_probe.luau").read_text()
    marker="local folder=W.RSResourcesP45.Models";require(source.count(marker)==1,"Scope marker")
    source=source.replace(marker,"local folder=W.RSEnvironmentP4Detail.Models")
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+source+"\nend",read_version=17,compile_source=True,rows=rows,patches=patches,terrainExpected={k[8:]:v["digest"] for k,v in base["records"].items() if k.startswith("terrain:")})
    require(r["loadedVersion"]==17 and r["noPlaceWrites"] and r["all49Restored"] and len(r["rows"])==6,"Rock proof scope")
    evidence={x["id"]:x for x in rows}
    for x in r["rows"]:x["plannedBurial"]=evidence[x["id"]]["buriedDepth"]
    write(a.output/"large-rock-surface-proof.json",r)
    summary={"hits":r["finalHits"],"all49Restored":r["all49Restored"],"rows":[{k:x.get(k) for k in ("id","plannedBurial","groundDelta","baseGap","topGap","center")} for x in r["rows"]],"noPlaceWrites":True}
    print("S067_LARGE_ROCK "+json.dumps(summary),flush=True)
if __name__=="__main__":main()
