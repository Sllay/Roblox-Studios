"""Repair only rejected S07 positions; retain native-approved transforms."""
import os,time,json,math
from collections import Counter
from scene_sync import ROOT,read,write,require,task,state_path,sha
from deploy import load_all,resolve
from workspace import WorkspaceError
from spatial_engine import load_native,prior_rows
from spatial_index import SurfaceIndex,Occupancy,observed_occupancy
from prop_framework import resolve as resolve_spec,rng_for
GAME=ROOT/"games/maps/mapa-principal"
OUT=ROOT/"dist/s07"
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    base=read(state_path(target));plan=read(OUT/"plan.json")
    require(base["loadedVersion"]==18 and base["stateDigest"]==plan["stateDigest"]==sha(base["records"]),"Baseline")
    rows={r["id"]:r for r in plan["rows"]}
    require(len(rows)==2000 and Counter(r["type"] for r in rows.values())=={"Branch":1000,"Stone":1000},"Population")
    reports={}
    for p in sorted(OUT.glob("population-*.json")):
        a=read(p);require(a["stateDigest"]==base["stateDigest"] and a["noPlaceWrites"] and a["tested"]==a["expected"]==len(a["rows"]),"Report")
        for r in a["rows"]:
            require(r["id"] in rows and r["id"] not in reports and r["tile"]==rows[r["id"]]["tile"],"Identity")
            reports[r["id"]]=r
    require(set(reports)==set(rows),"Incomplete population")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    tiles,materials,_=load_native(target,key,base,ROOT/".rs-cache/surface")
    index=SurfaceIndex(tiles,materials)
    old=read(GAME/"docs/s06/resources-v16/plan.json")["resources"]
    legacy={r["id"] for r in old}
    fixed=[r for r in observed_occupancy(base,{r["id"]:r["name"] for r in prior_rows()}) if r["id"] not in legacy]
    occ=Occupancy(fixed+[r for r in rows.values() if reports[r["id"]]["accepted"]])
    specs={s["id"]:resolve_spec(s) for s in plan["specs"]}
    src=(ROOT/"tools/sync/s07_geometry_probe.luau").read_text()
    def probe(batch):
        for delay in (15,30,60,120,None):
            try:
                a=task(target,key,"do\n"+src+"\nend",read_version=18,compile_source=True,rows=batch)
                require(a["loadedVersion"]==18 and a["noPlaceWrites"] and a["all49Restored"],"Native contract")
                require(len(a["rows"])==len(batch) and {r["id"] for r in a["rows"]}=={r["id"] for r in batch},"Batch identity")
                return a["rows"]
            except WorkspaceError as e:
                if not str(e).startswith("Roblox API HTTP 429:") or delay is None: raise
                time.sleep(delay)
    def checkpoint():
        accepted=[{**rows[i],"native":reports[i]} for i in sorted(rows) if reports[i]["accepted"]]
        write(OUT/"repaired-population.json",{"stateDigest":base["stateDigest"],"loadedVersion":18,"rows":accepted,"complete":len(accepted)==2000,"noPlaceWrites":True,"rejected":[i for i in sorted(rows) if not reports[i]["accepted"]]})
    for round in range(12):
        pending=[i for i in sorted(rows) if not reports[i]["accepted"]]
        if not pending:break
        batch=[]
        for i in pending:
            r=rows[i];s=specs[r["type"]];radius=s["radius"]*(1+s["variation"])
            rule={**s,"radius":radius,"footprint":radius,"supportRadius":max(.5,radius)}
            rng=rng_for(73007,i,"repair",round)
            b=index.tiles[r["tile"]]
            for attempt in range(3000):
                x=rng.uniform(b[0]+4,b[3]-4);z=rng.uniform(b[2]+4,b[5]-4)
                why,support=index.evaluate(x,z,rule,occ)
                if why:continue
                candidate={**r,"x":x,"z":z,"groundY":support["height"],"normal":support["normal"],"yaw":rng.uniform(0,360)}
                source=min((o for o in old if o["category"]==s["legacyCategory"]),key=lambda o:o["id"])
                factors=s["dimensionFactorsFromV18"]
                bounds=[d*f*(2 if r["type"]=="Branch" else 1) for d,f in zip(source["bounds"],factors)]
                rows[i]=candidate;occ.add(candidate)
                batch.append({**candidate,"sourceId":source["id"],"factors":factors,"bounds":bounds})
                break
        for start in range(0,len(batch),32):
            for result in probe(batch[start:start+32]):
                i=result["id"];reports[i]=result
                if not result["accepted"]:occ.remove(i)
            checkpoint()
        print("Repair round",round+1,"accepted",sum(r["accepted"] for r in reports.values()),flush=True)
    checkpoint()
    require(all(r["accepted"] for r in reports.values()),"Unresolved native positions")
    require(all(r.get("frame") and r["gap"]<.22 and r["slope"]<=35 for r in reports.values()),"Native transform gate")
if __name__=="__main__":main()
