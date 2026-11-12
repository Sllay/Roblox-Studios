"""S07 integrated disposable preview; no save path."""
import os,json,time
from collections import Counter
from scene_sync import ROOT,read,write,require,task,state_path,sha,compose_task
from deploy import load_all,resolve
from sharded_scene_sync import latest
from workspace import WorkspaceError
GAME=ROOT/"games/maps/mapa-principal"
OUT=ROOT/"dist/s07"
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    base=read(state_path(target));pop=read(OUT/"repaired-population.json")
    require(base["loadedVersion"]==18 and base["stateDigest"]==sha(base["records"])==pop["stateDigest"] and pop["complete"] and pop["noPlaceWrites"],"Baseline")
    require(latest(target,key)==18,"Live head changed")
    old=read(GAME/"docs/s06/resources-v16/plan.json")
    fix=read(GAME/"docs/s06/resource-contact-scaled-v17/contact-fix-preview.json")
    columns=sorted({(c["x"],c["z"]) for p in old["patches"] for c in p["cells"]}|{(c["x"],c["z"]) for c in fix["extraPaint"]})
    def run(file,version,**cfg):
        src=(ROOT/"tools/sync"/file).read_text()
        size=len(compose_task(target,"do\n"+src+"\nend",**cfg).encode("utf-8"))
        print(f"{file}: {size} bytes",flush=True)
        require(size<=1048576,"Cloud script size exceeds limit")
        for delay in (15,30,60,120,None):
            try:
                r=task(target,key,"do\n"+src+"\nend",read_version=version,compile_source=True,**cfg)
                require(r["loadedVersion"]==version and r["noPlaceWrites"],"Disposable contract")
                return r
            except WorkspaceError as e:
                if not str(e).startswith("Roblox API HTTP 429:") or delay is None:raise
                time.sleep(delay)
    original=[]
    for i in range(0,len(columns),64):
        batch=[{"x":x,"z":z} for x,z in columns[i:i+64]]
        r=run("s07_original_columns.luau",16,columns=batch)
        require(len(r["columns"])==len(batch),"Historical columns")
        original.extend(r["columns"])
    write(OUT/"original-columns.json",original)
    sources={kind:min(r["id"] for r in old["resources"] if r["category"]==cat) for kind,cat in (("Branch","stick"),("Stone","stone"))}
    rows=[]
    for r in pop["rows"]:
        n=r["native"]
        require(n["accepted"] and n["gap"]<.22 and n["slope"]<=35 and len(n["frame"])==12,"Native proof")
        rows.append(dict(id=r["id"],kind=r["type"],tile=r["tile"],source=sources[r["type"]],size=n["newSize"],frame=n["frame"],groundY=r["groundY"],radius=r["radius"]))
    require(len({r["id"] for r in rows})==2000 and Counter(r["kind"] for r in rows)=={"Branch":1000,"Stone":1000},"Population")
    # Compact positional records retain exact numeric values and avoid repeated keys.
    packed=[[r["id"],r["kind"],r["tile"],r["source"],r["size"],r["frame"],r["groundY"],r["radius"]] for r in rows]
    opts=dict(rows=packed,sources=list(sources.values()),columns=original,terrainExpected={k[8:]:v["digest"] for k,v in base["records"].items() if k.startswith("terrain:")})
    r=run("s07_migration_preview.luau",18,**opts)
    write(OUT/"migration-preview.json",r)
    if r.get("inverseMismatch"): print(json.dumps(r),flush=True)
    require(r["preview"] and r["all49Restored"] and r["resourceInverse"] and r["counts"]=={"Branch":1000,"Stone":1000},"Preview gates")
    require(latest(target,key)==18,"Live head changed")
    write(OUT/"migration-preview.json",r)
    print(json.dumps(r),flush=True)
    if os.environ.get("S07_PUBLISH")=="1":
        reviewed=read(OUT/"reviewed/migration-preview.json")
        require(reviewed["preview"] and reviewed["noPlaceWrites"] and reviewed["all49Restored"] and reviewed["resourceInverse"],"Reviewed proof")
        require(all(r[k]==reviewed[k] for k in ("beforeFingerprint","afterFingerprint","terrain","counts","vegetationRotated","restoredMaterialVoxels")),"Fresh preview differs")
        require(latest(target,key)==18,"Head changed before save")
        src="do\n"+(ROOT/"tools/sync/s07_migration_preview.luau").read_text()+"\nend"
        expected=dict(expectedBefore=r["beforeFingerprint"],expectedAfter=r["afterFingerprint"],expectedTerrain={x["id"]:x["digest"] for x in r["terrain"]})
        apply={**opts,**expected,"mode":"apply"}
        require(len(compose_task(target,src,**apply).encode())<=1048576,"Apply size")
        from cloud_tasks import atomic_json
        receipt={"status":"started","beforeVersion":18,"retryAllowed":False,**expected}
        atomic_json(OUT/"publication-receipt.json",receipt)
        try:
            saved=task(target,key,src,compile_source=True,journal=OUT/"publication-task.json",**apply)
            require(saved["saved"] and saved["loadedVersion"]==18,"Save receipt")
            version=latest(target,key);require(version==19,"Expected v19")
            receipt.update(status="saved_pending_verification",afterVersion=version);atomic_json(OUT/"publication-receipt.json",receipt)
            proof=run("s07_migration_preview.luau",version,rows=[0]*2000,mode="verify",**expected)
            require(proof["verified"] and proof["afterFingerprint"]==expected["expectedAfter"],"Persisted proof")
            require(latest(target,key)==version,"Head changed after verify")
            write(OUT/"publication-verification.json",proof)
            receipt.update(status="verified");atomic_json(OUT/"publication-receipt.json",receipt)
            print("S07_PUBLISHED_VERIFIED",version,flush=True)
        except Exception:
            receipt["status"]="requires_reconciliation";atomic_json(OUT/"publication-receipt.json",receipt);raise
if __name__=="__main__":main()
