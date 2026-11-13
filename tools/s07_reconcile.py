import os,json,time
from scene_sync import ROOT,read,write,require,task as raw_task
from workspace import WorkspaceError

def task(*args, **kwargs):
    # This module only opens disposable historical/read-only sessions.
    # Pace requests and retry explicit rate-limit rejection, never a save.
    require(kwargs.get('read_version') in (18,19), 'Explicit historical version required')
    for attempt in range(5):
        time.sleep(12 if attempt == 0 else min(120, 30 * 2**(attempt-1)))
        try:
            return raw_task(*args, **kwargs)
        except WorkspaceError as exc:
            if 'HTTP 429:' not in str(exc) or attempt == 4: raise

from deploy import load_all,resolve
from sharded_scene_sync import latest
g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
out=ROOT/"dist/s07";reviewed=read(out/"reviewed/migration-preview.json")
version=latest(target,key);require(version==19,"Unexpected live version; no writes")
src=(ROOT/"tools/sync/s07_migration_preview.luau").read_text()
r=task(target,key,"do\n"+src+"\nend",read_version=version,compile_source=True,rows=[0]*2000,mode="diagnose",audit=True,expectedTerrain={x["id"]:x["digest"] for x in reviewed["terrain"]})
require(r["loadedVersion"]==version and r["noPlaceWrites"],"Read-only contract")
r["expectedFingerprint"]=reviewed["afterFingerprint"]
r["fingerprintMatches"]=r["afterFingerprint"]==r["expectedFingerprint"]
write(out/"reconciliation.json",r)
print("S07_RECONCILIATION",json.dumps({k:v for k,v in r.items() if k!="terrain"}),flush=True)
require(latest(target,key)==version,"Head changed")

# Reproduce the reviewed preview on historical v18, never the live head.
from scene_sync import state_path,sha,compose_task
base=read(state_path(target));pop=read(out/"repaired-population.json")
require(base["loadedVersion"]==18 and base["stateDigest"]==sha(base["records"])==pop["stateDigest"],"Historical baseline")
old=read(ROOT/"games/maps/mapa-principal/docs/s06/resources-v16/plan.json")
sources={kind:min(x["id"] for x in old["resources"] if x["category"]==cat) for kind,cat in (("Branch","stick"),("Stone","stone"))}
rows=[[x["id"],x["type"],x["tile"],sources[x["type"]],x["native"]["newSize"],x["native"]["frame"],x["groundY"],x["radius"]] for x in pop["rows"]]
opts=dict(mode="historicalAudit",rows=rows,sources=list(sources.values()),columns=read(out/"reviewed/original-columns.json"),terrainExpected={k[8:]:v["digest"] for k,v in base["records"].items() if k.startswith("terrain:")},audit=True)
dispatch="do\n"+src+"\nend"
require(len(compose_task(target,dispatch,**opts).encode())<=1048576,"Historical audit size")
p=task(target,key,dispatch,read_version=18,compile_source=True,**opts)
require(p["loadedVersion"]==18 and p["historicalAudit"] and p["noPlaceWrites"] and p["afterFingerprint"]==reviewed["afterFingerprint"],"Historical preview proof")
diff=[k for k in sorted(set(p["audit"])|set(r["audit"])) if p["audit"].get(k)!=r["audit"].get(k)]
write(out/"property-audit.json",{"differences":diff,"expected":p["audit"],"actual":r["audit"]})
print("S07_PROPERTY_DIFFERENCES",json.dumps(diff),flush=True)
require(latest(target,key)==19,"Head changed")

# Compare complete root multisets; path-keyed records collapse duplicate siblings.
from collections import Counter
roots={}
for v in (18,19):
    z=task(target,key,dispatch,read_version=v,compile_source=True,rows=[0]*2000,mode="controllerMultiset")
    require(z["loadedVersion"]==v and z["noPlaceWrites"],"Multiset read-only")
    roots[v]=z["roots"]
def counter(v):
    return Counter((x["name"],x["class"],x["count"],x["digest"]) for x in roots[v])
a,b=counter(18),counter(19)
report={"roots":roots,"removed":[[list(k),n] for k,n in (a-b).items()],"added":[[list(k),n] for k,n in (b-a).items()]}
write(out/"controller-multiset.json",report)
print("S07_CONTROLLER_MULTISET",json.dumps(report),flush=True)
require(latest(target,key)==19,"Head changed")

# Compare every controller record with multiplicity, including the extra
# StarterPlayerScripts module. No normalization or place write is permitted.
players={}
for v in (18,19):
    z=task(target,key,dispatch,read_version=v,compile_source=True,rows=[0]*2000,mode="playerAudit")
    require(z["loadedVersion"]==v and z["noPlaceWrites"],"Controller records read-only")
    players[v]=z["playerRecords"]
def record_delta(left,right):
    return [{"key":k,"count":x["count"]-right.get(k,{}).get("count",0),"row":x["row"]}
            for k,x in left.items() if x["count"]>right.get(k,{}).get("count",0)]
removed=record_delta(players[18],players[19])
added=record_delta(players[19],players[18])
write(out/"controller-record-delta.json",{"removed":removed,"added":added})
print("S07_CONTROLLER_RECORD_DELTA",json.dumps({"removed":sum(x["count"] for x in removed),"added":sum(x["count"] for x in added),"starterScripts":[x for x in added if x["row"]["path"][0]["name"]=="StarterPlayerScripts"]}),flush=True)
require(latest(target,key)==19,"Head changed")
