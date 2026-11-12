"""S06.7: force a disposable exact-channel terrain collision rebuild, measure real ray surface."""
import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,read,write,require,task,state_path
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
IDS={"p45-stone-chunk-1--1-12","p45-stick-chunk-1--1-06","p45-stick-chunk-1-0-03"}
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target));require(base["loadedVersion"]==17,"Expected v17")
    plan=read(GAME/"docs/s06/resources-v16/plan.json")
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+(ROOT/"tools/sync/resource_surface_rebuild_probe.luau").read_text()+"\nend",read_version=17,compile_source=True,rows=plan["resources"],patches=plan["patches"],terrainExpected={k[8:]:v["digest"] for k,v in base["records"].items() if k.startswith("terrain:")})
    require(r["loadedVersion"]==17 and r["noPlaceWrites"] and r["all49Restored"] and len(r["rows"])==216,"Proof scope")
    summary={k:r[k] for k in ("initialHits","sameRewriteHits","finalHits","mode","all49Restored","noPlaceWrites","clientRenderVerified")}
    cats={}
    for cat in ("stone","stick"):
        rows=[x for x in r["rows"] if x["category"]==cat and x["center"]]
        d={"hits":len(rows),"fullyBelowRaySurface":sum(x["topGap"]<0 for x in rows),"baseBelowRaySurface":sum(x["baseGap"]<0 for x in rows),"baseAboveRaySurface":sum(x["baseGap"]>0 for x in rows),"footprintHits":sum(bool(p["hit"]) for x in rows for p in x["footprint"])}
        for key in ("groundDelta","baseGap","topGap"):
            d[key]=[min(x[key] for x in rows),max(x[key] for x in rows)] if rows else None
        cats[cat]=d
    summary["categories"]=cats;summary["selected"]=[x for x in r["rows"] if x["id"] in IDS]
    write(a.output/"surface-rebuild-proof.json",r);write(a.output/"surface-rebuild-summary.json",summary);print("S067_SURFACE "+json.dumps(summary),flush=True)
if __name__=="__main__":main()
