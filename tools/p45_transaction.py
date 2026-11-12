"""One scoped staging publication from exact S03/S04 plans, with durable preview preimages."""
import argparse,base64,hashlib,json,os,sys,subprocess
from pathlib import Path
from scene_sync import ROOT,read,write,require,sha,state_path,task,capture,normalize,reconcile,require_current
from cloud_tasks import atomic_json
from default_clone_delta import split_default_clones
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
DATA=GAME/"docs/spatial/v14"
SRC=ROOT/"tools/sync/p45_transaction.luau"
WIND=GAME/"game/places/main/src/StarterPlayer/StarterPlayerScripts/RSWind.client.luau"
def dispatch():
    pack=(ROOT/"tools/assets/pack_import.luau").read_text()
    helpers='local Assets=game:GetService("AssetService")\nlocal Serial=game:GetService("SerializationService")\n'+pack[pack.index("local allowed="):pack.index("local function cloneSelected")]
    stick=(ROOT/"tools/assets/component_extract.luau").read_text()
    # Reuse exact vetted extractor, returning the detached model instead of destroying it.
    start=stick.index("local Assets=");end=stick.index("clones[1]:Destroy();result:Destroy();root:Destroy()")
    body=stick[start:end].replace('local root=Assets:LoadAssetAsync(tonumber(cfg.assetId))','local root=Assets:LoadAssetAsync(tonumber(cfg.assetId))')
    helper='local function extractStick()\nlocal cfg={assetId="9204066145",componentMode="extract",selector=cfg.stick.source.selector}\n'+body+'\nassert(digest==cfgExpectedStickDigest,"Stick source changed")\nclones[1]:Destroy();root:Destroy();return result\nend'
    source=SRC.read_text().replace("-- __RS_ROCK_HELPERS__",helpers).replace("-- __RS_STICK_HELPER__","local cfgExpectedStickDigest=cfg.stick.digest\n"+helper)
    verifier=(ROOT/"tools/sync/p45_verify.luau").read_text().replace("return syncResult({","return ({")
    source=source.replace("-- __RS_VERIFY_HELPER__","local function verifyPrepared()\n"+verifier+"\nend")
    return "do\n"+source+"\nend"
def plans(base):
    r=read(DATA/"s03/resource-plan.json");c=read(DATA/"s04/collider-plan.json")
    for p in (r,c):require(p["planDigest"]==sha({k:v for k,v in p.items() if k!="planDigest"}) and p["stateDigest"]==base["stateDigest"] and p["loadedVersion"]==base["loadedVersion"] and p["applyAuthorized"] is False,"Stale source plan")
    require(len(r["resources"])==216 and len(r["bushMoves"])==3 and len(c["profiles"])==94 and not c["blocked"],"Incomplete source plan")
    rock=next(x for x in read(GAME/"game/assets/environment-p4.json")["assets"] if x["name"]=="Rock")
    stick=read(GAME/"game/assets/audits/s03-stick-extraction-v14.json")
    require(rock["importAuthorized"] and stick["roundtripVerified"] and stick["codeExecuted"] is False,"Source authorization/evidence")
    wind=next(x for x in base["records"].values() if x.get("name")=="RSWind" and x.get("service")=="StarterPlayer" and x.get("class")=="LocalScript")
    opts={"environment":"staging","resources":r["resources"],"bushMoves":r["bushMoves"],"colliders":c["profiles"],"rock":rock,"stick":stick,"windBeforeHash":wind["properties"]["sourceHash"],"windSource":WIND.read_text(),"terrainExpected":{k[8:]:v["digest"] for k,v in base["records"].items() if k.startswith("terrain:")},"cloneReserve":163}
    # New models have one MeshPart each. Caps and standalone shaft add 95 Parts.
    opts["budget"]={"current":base["total"],"newRecords":208*2+95+3,"cloneEstimate":163,"reserve":500,"limit":5000}
    require(sum(opts["budget"][k] for k in ("current","newRecords","cloneEstimate","reserve"))<=5000,"Inventory budget")
    opts["planDigest"]=sha(opts)
    return opts
def equal(a,b):
    if type(a)!=type(b) and not (type(a) in (float,int) and type(b) in (float,int)):return False
    if type(a) in (float,int):return abs(a-b)<.005
    if isinstance(a,dict):return a.keys()==b.keys() and all(equal(a[k],b[k]) for k in a)
    if isinstance(a,list):return len(a)==len(b) and all(equal(x,y) for x,y in zip(a,b))
    return a==b
def scope(base,after,opts):
    old=base["records"];now=after["records"]
    delta=reconcile(base,after)["external"];scoped,clones=split_default_clones(base,after,delta)
    ids={r["id"] for r in opts["resources"]+opts["bushMoves"]};trees={r["id"] for r in opts["colliders"]}
    def allowed(r):
        path=r.get("path",[]);names=[x["name"] for x in path]
        if r.get("service")=="Workspace":
            if names and names[0]=="RSResourcesP45":return True
            if names[:2]==["RSEnvironmentP4","Models"]:return len(names)==2 or names[2] in ids
            if names and names[0] in {"RSSceneBuilder","RSWorldVegetation","RSEnvironmentP4","RSEnvironmentP4Detail","RSManagedAssets"}:
                if len(names)==1 and names[0]=="RSManagedAssets":return True
                if len(names)>=2 and names[1]=="Collisions":return len(names)==2 or (len(names)==3 and (names[2] in trees or names[2].removesuffix("-cap") in trees))
        return r.get("service")=="StarterPlayer" and names==["StarterPlayerScripts","RSWind"]
    for d in scoped:
        for r in (old.get(d["key"]),now.get(d["key"])):
            if r is not None:require(allowed(r),"Unexpected delta "+d["key"])
    require(all(now.get(k)==v for k,v in old.items() if k.startswith("terrain:")),"Terrain delta")
    return len(scoped),len(clones)
def verify_expected(expected,actual,base,opts):
    scope(base,actual,opts)
    diff=reconcile(expected,actual)["external"];scoped,clones=split_default_clones(expected,actual,diff)
    for d in scoped:
        k=d["key"];require(k in expected["records"] and k in actual["records"] and equal(expected["records"][k],actual["records"][k]),"Persisted preview mismatch "+k)
    return len(clones)
def check_backups(rows):
    require(len(rows)==105,"Expected 8 rocks + 3 bushes + 93 shafts + wind")
    keys=set()
    for r in rows:
        key=sha([r["service"],r["path"]]);require(key not in keys,"Duplicate preimage");keys.add(key)
        blob=base64.b64decode(r["serializedBase64"],validate=True)
        require(blob.startswith(b"<roblox!") and base64.b64encode(hashlib.sha256(blob).digest()).decode()==r["digest"],"Backup digest")
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("mode",choices=["preview","apply"]);p.add_argument("--reviewed",type=Path);p.add_argument("--confirm-staging",action="store_true");p.add_argument("--output",type=Path,default=ROOT/"dist/s05");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];base=require_current(target,key,14);opts=plans(base);src=dispatch()
    manifest={"schemaVersion":1,"version":14,"stateDigest":base["stateDigest"],"planDigest":opts["planDigest"],"sourceSha256":hashlib.sha256(src.encode()).hexdigest(),"budget":opts["budget"]}
    if a.mode=="preview":
        r=task(target,key,src,read_version=14,compile_source=True,mode="preview",**opts)
        require(r["preview"] and r["noPlaceWrites"] and r["planDigest"]==opts["planDigest"],"Preview contract")
        expected=normalize({**r["after"],"loadedVersion":14});check_backups(r["backups"])
        changes,clones=scope(base,expected,opts);require(clones==0,"Unexpected preview clone")
        require(r["inverseVerified"] is True and r["inverseRecordCount"]==base["total"],"Isolated inverse did not restore baseline")
        manifest.update(expectedDigest=expected["stateDigest"],backupDigest=sha(r["backups"]),backupCount=len(r["backups"]),expectedTotal=expected["total"],beforeFingerprint=r["beforeFingerprint"],afterFingerprint=r["afterFingerprint"],isolatedInverseVerified=True)
        atomic_json(a.output/"manifest.json",manifest);write(a.output/"expected.json",expected);write(a.output/"preimages.json",r["backups"])
        print("S05_PREVIEW "+json.dumps({**manifest,"changes":changes}),flush=True);return
    require(a.confirm_staging and a.reviewed is not None,"Reviewed staging authorization")
    m=read(a.reviewed/"manifest.json");expected=read(a.reviewed/"expected.json");backups=read(a.reviewed/"preimages.json")
    require(all(m[k]==v for k,v in manifest.items()) and expected["stateDigest"]==sha(expected["records"])==m["expectedDigest"] and sha(backups)==m["backupDigest"],"Reviewed manifest mismatch")
    check_backups(backups);scope(base,expected,opts)
    require(m["isolatedInverseVerified"] is True,"Recovery proof required")
    receipt={**manifest,"status":"started","retryAllowed":False}
    a.output.mkdir(parents=True,exist_ok=True)
    with (a.output/"receipt.json").open("x") as o:json.dump(receipt,o);o.flush();os.fsync(o.fileno())
    try:
        r=task(target,key,src,compile_source=True,journal=a.output/"cloud-task.json",mode="apply",confirmStaging=True,backupCount=m["backupCount"],beforeFingerprint=m["beforeFingerprint"],afterFingerprint=m["afterFingerprint"],**opts)
        require(r["saved"] and r["loadedVersion"]==14 and r["planDigest"]==opts["planDigest"],"Save unconfirmed")
        write(a.output/"save.json",{k:v for k,v in r.items() if k!="after"})
        after=capture(target,key);write(a.output/"after.json",after);require(after["loadedVersion"]>14,"Version not advanced")
        cloneCount=verify_expected(expected,after,base,opts)
        verification=task(target,key,"do\n"+(ROOT/"tools/sync/p45_verify.luau").read_text()+"\nend",read_version=after["loadedVersion"],compile_source=True,**opts)
        require(verification["verified"] and verification["loadedVersion"]==after["loadedVersion"] and verification["stones"]==108 and verification["sticks"]==108 and verification["treeProfiles"]==94,"Independent persisted physics/resource proof")
        write(a.output/"verification.json",verification)
        subprocess.run([sys.executable,"tools/scene_sync.py","--record","--expected-version",str(after["loadedVersion"]),"--expected-digest",after["stateDigest"]],cwd=ROOT,check=True)
        receipt.update(status="verified",afterVersion=after["loadedVersion"],afterDigest=after["stateDigest"],total=after["total"],defaultCloneDelta=cloneCount,terrainUnchanged=49)
        atomic_json(a.output/"receipt.json",receipt);print("S05_VERIFIED "+json.dumps(receipt),flush=True)
    except Exception:
        receipt["status"]="requires_reconciliation";atomic_json(a.output/"receipt.json",receipt);raise
if __name__=="__main__":main()
