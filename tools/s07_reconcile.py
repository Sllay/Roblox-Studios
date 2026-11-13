import os,json
from scene_sync import ROOT,read,write,require,task
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
