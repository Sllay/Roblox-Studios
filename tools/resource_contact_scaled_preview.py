"""S06.7 measured support plus 2x stick preview; v17 only, no saved Place changes."""
import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,read,write,require,task,state_path,sha
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target));require(base["loadedVersion"]==17,"Expected v17")
    old=read(GAME/"docs/s06/resources-v16/plan.json")
    evidence=read(GAME/"docs/s06/resource-contact-v17/surface-rebuild-proof.json")
    require(evidence["loadedVersion"]==17 and evidence["finalHits"]==216 and evidence["all49Restored"] and evidence["noPlaceWrites"],"Surface proof")
    src="do\n"+(ROOT/"tools/sync/resource_contact_scaled_preview.luau").read_text()+"\nend"
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],src,read_version=17,compile_source=True,rows=old["resources"],patches=old["patches"],surface={x["id"]:x["center"]["y"] for x in evidence["rows"]},terrainExpected={k[8:]:v["digest"] for k,v in base["records"].items() if k.startswith("terrain:")})
    require(r["loadedVersion"]==17 and r["noPlaceWrites"] and r["all49Restored"] and r["resourceInverse"] and len(r["rows"])==216,"Preview inverse")
    r["stateDigest"]=base["stateDigest"];r["planDigest"]=sha(r)
    summary={k:r[k] for k in ("loadedVersion","stateDigest","planDigest","extraPaintColumns","paintMode","crossGrassCenters","crossGrassSamples","finalGrassCenters","finalGrassSamples","changedTiles","all49Restored","resourceInverse","noPlaceWrites","clientRenderVerified")}
    summary["categories"]={}
    summary["overlapPairs"]=r["overlapPairs"]
    summary["overlapPairCount"]=len(r["overlapPairs"])
    require(all(abs(x["scaleRatio"]-(2 if x["category"]=="stick" else 1))<1e-4 for x in r["rows"]),"Scale ratio")
    for cat in ("stone","stick"):
        rows=[x for x in r["rows"] if x["category"]==cat]
        summary["categories"][cat]={"count":len(rows),"scaleRatio":[min(x["scaleRatio"] for x in rows),max(x["scaleRatio"] for x in rows)],"deltaY":[min(x["deltaY"] for x in rows),max(x["deltaY"] for x in rows)],"paintSurfaceDelta":[min(x["paintSurfaceDelta"] for x in rows),max(x["paintSurfaceDelta"] for x in rows)],"baseGap":[min(x["baseGap"] for x in rows),max(x["baseGap"] for x in rows)],"maxGap":max(x["maxGap"] for x in rows),"minTopGap":min(x["topGap"] for x in rows),"burialZero":all(x["burial"]==0 for x in rows)}
    write(a.output/"contact-fix-preview.json",r);write(a.output/"contact-fix-summary.json",summary);print("S067_FIX_PREVIEW "+json.dumps(summary),flush=True)
if __name__=="__main__":main()
