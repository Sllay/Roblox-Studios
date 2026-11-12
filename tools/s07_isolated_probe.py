"""Read-only native geometry checkpoint, two resources per type per tile."""
import os,json,time
from workspace import WorkspaceError
from scene_sync import ROOT,read,write,require,task,state_path
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    base=read(state_path(target));plan=read(ROOT/"dist/s07/plan.json")
    require(plan["complete"] and plan["stateDigest"]==base["stateDigest"] and base["loadedVersion"]==18,"Plan baseline")
    old=read(GAME/"docs/s06/resources-v16/plan.json")["resources"]
    specs={s["id"]:s for s in plan["specs"]}
    src=(ROOT/"tools/sync/s07_geometry_probe.luau").read_text()
    reports=[]
    def probe(rows):
        # Historical disposable sessions only. Never retry ambiguous publication.
        for delay in (15,30,60,120,None):
            try:
                return task(target,os.environ['ROBLOX_OPEN_CLOUD_API_KEY'],'do\n'+src+'\nend',read_version=18,compile_source=True,rows=rows)
            except WorkspaceError as exc:
                if not str(exc).startswith('Roblox API HTTP 429:') or delay is None: raise
                print(f'Historical probe rate limited; waiting {delay}s',flush=True)
                time.sleep(delay)

    for tile in ["chunk-1-0"]:
        rows=[]
        for name,s in specs.items():
            source=sorted((r for r in old if r["category"]==s["legacyCategory"]),key=lambda r:r["id"])[0]
            factors=s["dimensionFactorsFromV18"]
            bounds=[d*f*(2 if name=="Branch" else 1) for d,f in zip(source["bounds"],factors)]
            candidates=[r for r in plan["rows"] if r["tile"]==tile and r["type"]==name]
            for r in candidates[:2]:rows.append({**r,"sourceId":source["id"],"factors":factors,"bounds":bounds})
        rows=[r for r in rows if r["id"]=="s07:Branch:chunk-1-0:0002"]
        require(len(rows)==1,"Isolated target missing")
        result=probe(rows)
        require(result["loadedVersion"]==18 and result["noPlaceWrites"] and result["all49Restored"],"Native probe contract")
        reports.extend(result["rows"])
        write(ROOT/"dist/s07/geometry-progress.json",{"rows":reports,"noPlaceWrites":True})
    summary={"tested":len(reports),"accepted":sum(r["accepted"] for r in reports),"rows":reports,"noPlaceWrites":True}
    write(ROOT/"dist/s07/geometry.json",summary);print(json.dumps(summary),flush=True)
    require(len(reports)==1 and summary["accepted"]==1,"Native geometry needs refinement")
if __name__=="__main__":main()
