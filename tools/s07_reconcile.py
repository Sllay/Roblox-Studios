import os,json
from scene_sync import ROOT,read,write,require,task
from deploy import load_all,resolve
from sharded_scene_sync import latest
g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
out=ROOT/"dist/s07";reviewed=read(out/"reviewed/migration-preview.json")
version=latest(target,key);require(version==19,"Unexpected live version; no writes")
src=(ROOT/"tools/sync/s07_migration_preview.luau").read_text()
r=task(target,key,"do\n"+src+"\nend",read_version=version,compile_source=True,rows=[0]*2000,mode="diagnose",expectedTerrain={x["id"]:x["digest"] for x in reviewed["terrain"]})
require(r["loadedVersion"]==version and r["noPlaceWrites"],"Read-only contract")
r["expectedFingerprint"]=reviewed["afterFingerprint"]
r["fingerprintMatches"]=r["afterFingerprint"]==r["expectedFingerprint"]
write(out/"reconciliation.json",r)
print("S07_RECONCILIATION",json.dumps({k:v for k,v in r.items() if k!="terrain"}),flush=True)
require(latest(target,key)==version,"Head changed")
