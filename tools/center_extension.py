"""P3 pilot: extend native terrain, replace default spawns, archive originals."""
from __future__ import annotations
import argparse,json,os,sys
from pathlib import Path
from deploy import load_all,resolve,WorkspaceError
from scene_sync import ROOT,task,require_current,read,write,state_path,capture,reconcile,require

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("mode",choices=["preview","apply","verify","rollback"])
    ap.add_argument("--confirm-staging",action="store_true")
    ap.add_argument("--evidence",type=Path)
    ap.add_argument("--reviewed-after",type=Path,help="Explicit previously observed post-save inventory for read-only reconciliation")
    a=ap.parse_args()
    games,targets=load_all();t=resolve(games,targets,"mapa-principal","main","staging")
    require((t["universeId"],t["placeId"])==("10769712441","93428341652658"),"Wrong target")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    p=read(ROOT/"games/maps/mapa-principal/game/terrain/center-extension.json")
    out=ROOT/"dist/center-extension"
    base=read(state_path(t))
    require(a.mode in ("preview","apply") or a.evidence is not None,"Evidence required")
    baseline=base if a.mode in ("preview","apply") else read(a.evidence)["baseline"]
    rows=[]
    for name in ("Baseplate","SpawnLocation"):
        matches=[r for r in baseline["records"].values() if r.get("service")=="Workspace" and r.get("name")==name and len(r["path"])==1]
        require(len(matches)==1 and not matches[0]["ambiguous"],"Default identity not unique")
        rows.append(matches[0])
    source=(ROOT/"tools/sync/center_extension.luau").read_text()
    runtime=(ROOT/"tools/sync/central_spawn.server.luau").read_text()
    # dispatch returns before final inventory return, wrapped in do for Luau syntax.
    dispatch="do\n"+source+"\nend"
    opts=dict(plan=p,targets=rows,runtimeSource=runtime,environment="staging")
    if a.mode in ("preview","apply"):
        current=require_current(t,key,p["expectedVersion"])
        r=task(t,key,dispatch,mode="preview",expectedVersion=p["expectedVersion"],**opts)
        write(out/"preview.json",r)
        print("CENTER_PREVIEW",json.dumps(r),flush=True)
        if a.mode=="preview":return
        require(a.confirm_staging,"Explicit confirmation")
        result=task(t,key,dispatch,mode="apply",expectedVersion=p["expectedVersion"],**opts)
        write(out/"save.json",result)
        require(result.get("saved") is True,"Save unconfirmed")
        evidence={"baseline":current,"result":result}
        write(out/"rollback-evidence.json",evidence)
    else:
        require(a.evidence is not None,"Evidence required")
        evidence=read(a.evidence);result=evidence["result"]
    if a.mode=="rollback":
        require(a.confirm_staging,"Explicit rollback confirmation")
        now=require_current(t,key)
        require(now["loadedVersion"]==7,"Rollback only on original extension version")
        r=task(t,key,dispatch,mode="rollback",expectedVersion=7,expectedDigest=result["terrainDigest"],**opts)
        write(out/"rollback.json",r)
        require(r.get("rolledBack") is True,"Rollback save unconfirmed")
        restored=capture(t,key);write(out/"restored.json",restored)
        require(restored["loadedVersion"]>7,"Rollback not persisted")
        for name in ("Baseplate","SpawnLocation"):
            require(any(v.get("name")==name and v.get("service")=="Workspace" and len(v.get("path",[]))==1 for v in restored["records"].values()),"Default not restored")
        return
    v=task(t,key,dispatch,mode="verify",expectedDigest=result["terrainDigest"],**opts)
    write(out/"verification.json",v)
    require(v["verified"] is True and v["loadedVersion"]>p["expectedVersion"],"Persistence failed")
    after=capture(t,key);write(out/"after.json",after)
    delta=reconcile(baseline,after);write(out/"changes.json",delta)
    # The migration initially failed closed on an unrelated engine-default delta.
    # A later read-only review may acknowledge only the exact recorded state;
    # never waive unexpected changes during apply.
    reviewed=read(a.reviewed_after) if a.mode=="verify" and a.reviewed_after else None
    if reviewed:
        require(after==reviewed,"Reviewed post-save inventory changed")
    unexpected=[]
    for k,r in baseline["records"].items():
        path=r.get("path",[])
        if r.get("service")=="Workspace" and path and path[0]["name"] in ("Baseplate","SpawnLocation"):continue
        if after["records"].get(k)!=r:unexpected.append(k)
    if unexpected:
        require(reviewed is not None,"Unrelated record changed: "+unexpected[0])
        print("REVIEWED_UNRELATED_DELTA",json.dumps(unexpected),flush=True)
    require(after["loadedVersion"]==v["loadedVersion"],"Version changed")
    print("CENTER_VERIFIED",json.dumps(v),flush=True)
if __name__=="__main__":
    try:main()
    except (WorkspaceError,ValueError,KeyError,OSError) as e:print("ERROR:",e,file=sys.stderr);raise SystemExit(1)
