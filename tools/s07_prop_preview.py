"""S07 v18-bound resource scatter preview; no Place writes."""
import os,json,math
from scene_sync import ROOT,read,write,require,sha,state_path
from deploy import load_all,resolve
from spatial_engine import load_native,prior_rows
from spatial_index import SurfaceIndex,observed_occupancy
from prop_framework import plan
GAME=ROOT/"games/maps/mapa-principal"
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    base=read(state_path(target))
    require(base["loadedVersion"]==18 and base["stateDigest"]==sha(base["records"]),"Expected verified v18")
    tiles,materials,metrics=load_native(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],base,ROOT/".rs-cache/surface")
    index=SurfaceIndex(tiles,materials)
    fixed=observed_occupancy(base,{r["id"]:r["name"] for r in prior_rows()})
    old=read(GAME/"docs/s06/resources-v16/plan.json")["resources"]
    ids={r["id"] for r in old}
    fixed=[r for r in fixed if r["id"] not in ids]
    specs=read(GAME/"game/assets/prop-registry-s07.json")["props"]
    # Conservative radius includes largest legacy geometry, new dimensions and variation.
    for s in specs:
        cat=s["legacyCategory"]; factors=s["dimensionFactorsFromV18"]
        s["radius"]=max(math.sqrt(sum((d*f*(2 if cat=="stick" else 1))**2 for d,f in zip(r["bounds"],factors)))/2 for r in old if r["category"]==cat)
    result=plan(index,fixed,specs,73007)
    result.update(version=18,stateDigest=base["stateDigest"],specs=specs,metrics=metrics,applyAuthorized=False)
    out=ROOT/"dist/s07";write(out/"plan.json",result)
    summary={k:v for k,v in result.items() if k!="rows"};write(out/"summary.json",summary)
    print(json.dumps(summary),flush=True)
    require(result["complete"],"Capacity shortfall; no publication")
if __name__=="__main__":main()
