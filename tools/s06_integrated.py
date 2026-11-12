"""Reviewed coupled S06 publication: bounded native preview, exact inverse, sharded observation."""
import argparse,json,hashlib,os,sys
from pathlib import Path
from collections import Counter
from scene_sync import ROOT,read,write,require,sha,state_path,task,key_for,reconcile
from deploy import load_all,resolve
from sharded_scene_sync import capture_sharded,latest
from default_clone_delta import split_default_clones
from p45_transaction import equal
from cloud_tasks import atomic_json
GAME=ROOT/"games/maps/mapa-principal";D=GAME/"docs/s06";SRC=GAME/"game/places/main/src"
def compose(base):
    forest=read(D/"regeneration-v16/plan.json");resources=read(D/"resources-v16/plan.json")
    for p in (forest,resources):require(p["planDigest"]==sha({k:v for k,v in p.items() if k!="planDigest"}) and p["stateDigest"]==base["stateDigest"],"Stale plan")
    require(resources["forestDigest"]==forest["planDigest"],"Plan linkage")
    specs=[("StarterPlayer","StarterPlayerScripts","RSWind","LocalScript","StarterPlayer/StarterPlayerScripts/RSWind.client.luau"),("StarterPlayer","StarterPlayerScripts","RSQualityPanel","LocalScript","StarterPlayer/StarterPlayerScripts/RSQualityPanel.client.luau"),("StarterPlayer","StarterPlayerScripts","RSVertexCanopyDemo","LocalScript","StarterPlayer/StarterPlayerScripts/RSVertexCanopyDemo.client.luau"),("ReplicatedStorage",None,"RSWindPolicy","ModuleScript","ReplicatedStorage/RSWindPolicy.luau"),("ReplicatedStorage",None,"RSBranchWind","ModuleScript","ReplicatedStorage/RSBranchWind.luau"),("ReplicatedStorage",None,"RSCanopyDeform","ModuleScript","ReplicatedStorage/RSCanopyDeform.luau"),("ServerScriptService",None,"RSCentralSpawnSafety","Script","ServerScriptService/RSCentralSpawnSafety.server.luau")]
    scripts=[]
    for svc,folder,name,cls,path in specs:
        matches=[r for r in base["records"].values() if r.get("service")==svc and r.get("name")==name and r.get("class")==cls]
        require(len(matches)<=1,"Script identity")
        r=dict(service=svc,name=name,**{"class":cls},source=(SRC/path).read_text())
        if folder:r["folder"]=folder
        if matches:r["beforeHash"]=matches[0]["properties"]["sourceHash"]
        scripts.append(r)
    opts={"forest":forest["rows"],"resources":resources["resources"],"patches":resources["patches"],"scripts":scripts,"baseTotal":base["total"],"cloneReserve":163,"terrainExpected":{k[8:]:v["digest"] for k,v in base["records"].items() if k.startswith("terrain:")}}
    opts["planDigest"]=sha(opts)
    physics=(SRC/"ServerScriptService/RSResourcePhysics.server.luau").read_text().split("-- __RS_RESOURCE_RUNTIME__")[0]
    # Existing large rocks are modified in-place by policy; capture their exact physical values for inverse.
    physics=physics.replace("local W=workspace","")
    physics+="\nlocal rockRest={}\nfor _,m in W.RSEnvironmentP4Detail.Models:GetChildren() do if m:IsA('Model') and m:GetAttribute('RSSpecies')=='Mossy_Rock1_M_Mossy_Rock_0_Node' then for _,p in m:GetDescendants() do if p:IsA('MeshPart') then table.insert(rockRest,{p=p,c=p.CanCollide,q=p.CanQuery,g=p.CollisionGroup}) end end end end\n"
    src=(ROOT/"tools/sync/s06_integrated.luau").read_text().replace("-- __RS_PHYSICS__",physics).replace("-- __RS_RESTORE_PHYSICS__","for _,r in rockRest do r.p.CanCollide=r.c;r.p.CanQuery=r.q;r.p.CollisionGroup=r.g end")
    return opts,"do\n"+src+"\nend"
def expected_from(base,r):
    records=dict(base["records"])
    for x in r["removed"]:del records[key_for(x)]
    for x in r["changed"]:records[key_for(x)]=x
    for t in r["terrain"]:records["terrain:"+t["id"]]=t
    records["environment:lighting"]=r["lighting"];records["environment:workspace"]=r["workspaceSettings"]
    return {**base,"total":r["afterTotal"],"records":records,"stateDigest":sha(records)}
def scope(base,expected,opts):
    ids={r["id"] for r in opts["forest"]+opts["resources"]}
    roots={"RSSceneBuilder","RSWorldVegetation","RSEnvironmentP4","RSEnvironmentP4Detail","RSManagedAssets","RSResourcesP45","RSVegetationS06"}
    scripts={r["name"] for r in opts["scripts"]}
    tiles={p["tile"] for p in opts["patches"]}
    for d in reconcile(base,expected)["external"]:
        k=d["key"]
        if k.startswith("terrain:"):
            require(k[8:] in tiles,"Unexpected terrain delta");continue
        for r in (base["records"].get(k),expected["records"].get(k)):
            if r is None:continue
            names=[x["name"] for x in r.get("path",[])]
            ok=r.get("service")=="Workspace" and names and names[0] in roots and (len(names)<=2 or names[0]=="RSVegetationS06" or any(n in ids or n.removesuffix("-cap") in ids for n in names) or names[0]=="RSEnvironmentP4Detail" and any("rock" in n.lower() for n in names))
            ok=ok or r.get("service") in {"StarterPlayer","ReplicatedStorage","ServerScriptService"} and (r.get("name") in scripts or names==["StarterPlayerScripts"])
            require(ok,"Unexpected scope "+k)
def main():
    p=argparse.ArgumentParser();p.add_argument("mode",choices=["preview","apply"]);p.add_argument("--output",type=Path,required=True);p.add_argument("--reviewed",type=Path);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target));key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    require(base["loadedVersion"]==16 and base["stateDigest"]==sha(base["records"]),"Baseline")
    opts,src=compose(base);sourceHash=hashlib.sha256(src.encode()).hexdigest()
    manifest={"version":16,"baseDigest":base["stateDigest"],"planDigest":opts["planDigest"],"sourceHash":sourceHash}
    if a.mode=="preview":
        r=task(target,key,src,read_version=16,compile_source=True,mode="preview",**opts)
        require(r["inverseVerified"] and r["noPlaceWrites"] and r["loadedVersion"]==16,"Inverse")
        expected=expected_from(base,r);scope(base,expected,opts)
        require(sum("class" in x for x in expected["records"].values())==expected["total"],"Complete expected inventory")
        manifest.update(beforeFingerprint=r["beforeFingerprint"],afterFingerprint=r["afterFingerprint"],expectedDigest=expected["stateDigest"],expectedTotal=expected["total"],inverseVerified=True)
        write(a.output/"manifest.json",manifest);write(a.output/"expected.json",expected)
        print("S066_PREVIEW "+json.dumps(manifest),flush=True);return
    require(a.reviewed is not None,"Reviewed manifest")
    m=read(a.reviewed/"manifest.json");expected=read(a.reviewed/"expected.json")
    require(all(m[k]==v for k,v in manifest.items()) and m["inverseVerified"] and expected["stateDigest"]==sha(expected["records"])==m["expectedDigest"],"Review mismatch")
    scope(base,expected,opts)
    # Fresh head is checked in native fingerprint before save, no historical write.
    receipt={**m,"status":"started","retryAllowed":False};a.output.mkdir(parents=True,exist_ok=True)
    with (a.output/"receipt.json").open("x") as o:json.dump(receipt,o);o.flush();os.fsync(o.fileno())
    try:
        r=task(target,key,src,compile_source=True,journal=a.output/"cloud-task.json",mode="apply",confirmStaging=True,beforeFingerprint=m["beforeFingerprint"],afterFingerprint=m["afterFingerprint"],**opts)
        require(r["saved"] and r["loadedVersion"]==16,"Save receipt")
        version=latest(target,key);require(version>16,"Version not advanced")
        actual,pages,calls=capture_sharded(target,key,version);write(a.output/"after.json",actual)
        require(latest(target,key)==version,"Head changed")
        scoped,clones=split_default_clones(expected,actual,reconcile(expected,actual)["external"])
        for d in scoped:
            k=d["key"];require(k in expected["records"] and k in actual["records"] and equal(expected["records"][k],actual["records"][k]),"Persisted mismatch "+k)
        scope(base,expected,opts)
        classes=Counter(r["class"] for r in actual["records"].values() if "class" in r)
        summary={k:actual[k] for k in ("schemaVersion","universeId","placeId","loadedVersion","stateDigest","total")}
        summary.update(classes=dict(classes),workspaceRoots=[{"name":v["name"],"class":v["class"],"key":k,"managedId":v["managedId"]} for k,v in actual["records"].items() if v.get("service")=="Workspace" and len(v["path"])==1],terrain={k:v for k,v in actual["records"].items() if k.startswith("terrain:")},coverageNote="Scoped inventory, not full backup. Sharded observed state.")
        write(state_path(target),actual);write(state_path(target).with_suffix(".summary.json"),summary)
        receipt.update(status="verified",afterVersion=version,afterDigest=actual["stateDigest"],total=actual["total"],defaultCloneDelta=len(clones),shardedCalls=calls)
        atomic_json(a.output/"receipt.json",receipt);print("S066_VERIFIED "+json.dumps(receipt),flush=True)
    except Exception:
        receipt["status"]="requires_reconciliation";atomic_json(a.output/"receipt.json",receipt);raise
if __name__=="__main__":main()
