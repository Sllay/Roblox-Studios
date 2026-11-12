"""Build an exact v15 staging diagnostic/physics script plan and probe it without saving."""
import argparse,json,os
from pathlib import Path
from scene_sync import ROOT,read,write,require,sha,state_path,task
from deploy import load_all,resolve
from scene_patch import prepare
GAME=ROOT/"games/maps/mapa-principal"
SRC=GAME/"game/places/main/src"
PLAN=GAME/"docs/sync/main/patches/s06-1-diagnostics-v15.json"
def make_plan(base):
    require(base["loadedVersion"]==15 and base["stateDigest"]=="a971ba91f62e695308612ebe49b71d0df34ddd4cd09feb3a48bf03763ec429c0","Expected reviewed v15 baseline")
    matches=[k for k,r in base["records"].items() if r.get("service")=="StarterPlayer" and r.get("name")=="RSQualityPanel" and r.get("class")=="LocalScript"]
    require(len(matches)==1,"Unique diagnostic script")
    require(not any(r.get("name")=="RSResourcePhysics" for r in base["records"].values()),"Physics script already present")
    def rel(p):return str(p.relative_to(ROOT))
    return {"schemaVersion":1,"expectedVersion":15,"baselineDigest":base["stateDigest"],"operations":[{"kind":"update_script","targetKey":matches[0],"archiveId":"s06-quality-v15","sourcePath":rel(SRC/"StarterPlayer/StarterPlayerScripts/RSQualityPanel.client.luau")},{"kind":"create_script","parentKey":"service:ServerScriptService","id":"s06-resource-physics","name":"RSResourcePhysics","class":"Script","sourcePath":rel(SRC/"ServerScriptService/RSResourcePhysics.server.luau")}]}
def main():
    a=argparse.ArgumentParser();a.add_argument("--output",type=Path,default=ROOT/"dist/s06");p=a.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    plan=make_plan(base);ops=prepare(target,base,plan)
    write(PLAN,plan)
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    source=(SRC/"ServerScriptService/RSResourcePhysics.server.luau").read_text().split("-- __RS_RESOURCE_RUNTIME__")[0]
    probe=source+'''
local api,backend=configure(W)
local stones,sticks,rocks=applyResources(W)
assert(stones==108 and sticks==108 and rocks==6,"Resource inventory")
assert(api:CollisionGroupsAreCollidable(RESOURCE,RESOURCE) and not api:CollisionGroupsAreCollidable(PLAYER,RESOURCE),"Collision matrix")
local p=Instance.new("Part");p.CollisionGroup=PLAYER;p.CanCollide=true
local r=Instance.new("Part");r.CollisionGroup=RESOURCE;r.CanCollide=true;r.Anchored=false
assert(p.CollisionGroup==PLAYER and r.CollisionGroup==RESOURCE and r.CanCollide and not r.Anchored,"Dynamic resource properties")
p:Destroy();r:Destroy()
return syncResult({backend=backend,stones=stones,sticks=sticks,largeRocks=rocks,matrixVerified=true,runtimeSimulationVerified=false,noPlaceWrites=true})
'''
    proof=task(target,key,"do\n"+probe+"\nend",read_version=15,compile_source=True)
    require(proof["matrixVerified"] and proof["noPlaceWrites"] and proof["loadedVersion"]==15,"Physics probe")
    write(p.output/"physics-proof.json",proof)
    write(p.output/"plan.json",plan)
    print("S06_PHYSICS "+json.dumps(proof),flush=True)
    print("S06_PLAN "+json.dumps({"planDigest":sha(plan),"preparedDigest":sha(ops)}),flush=True)
if __name__=="__main__":main()
