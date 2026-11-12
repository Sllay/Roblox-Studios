"""P4 bounded environment expansion; preview read-only, reviewed staging apply."""
from __future__ import annotations
import argparse
import json
import math
import os
import sys
from pathlib import Path
from scene_sync import ROOT, require, require_current, task, capture, reconcile, sha, read, write
from deploy import load_all, resolve, WorkspaceError

GAME=ROOT/"games/maps/mapa-principal"
SPEC=GAME/"game/assets/environment-p4.json"
sys.path.insert(0,str(ROOT/"tools/assets"))
from pack_import import inspect_blob, validate_evidence, validate_selector
from default_clone_delta import split_default_clones
def validate(plan):
    require(plan["schemaVersion"]==1 and plan["environment"]=="staging","Scope")
    root=plan.get("rootName","RSEnvironmentP4")
    require(root in ("RSEnvironmentP4","RSEnvironmentP4Detail"),"Managed environment root")
    budget=24 if root=="RSEnvironmentP4" else 20
    require(plan["maxNewModels"]==budget and sum(a["count"] for a in plan["assets"])==budget,"Model budget")
    require(len(plan["assets"])==4 and len({a["name"] for a in plan["assets"]})==4,"Asset selection")
    require(all(a["auditStatus"]=="exact_v2_pass" and a["sourceDigest"] and a["profile"]["calibrationStatus"]=="provisional" for a in plan["assets"]),"Source evidence")
    require(len(plan["placement"]["regionIds"])==9 and len(set(plan["placement"]["regionIds"]))==9,"Terrain scope")
    for a in plan["assets"]:
        validate_selector(a["selector"])
        p=a["profile"];scale=p["scale"]
        require(len(scale)==2 and all(type(x) in (int,float) and math.isfinite(x) for x in scale) and 0.01<=scale[0]<=scale[1]<=2,"Scale limits")
        require(0<=p["burial"]<=16 and 0.1<=p["support"]<=32,"Contact limits")
        if p.get("collider"):
            require(0.5<=p["collider"]["radius"]<=4 and 2<=p["collider"]["height"]<=24,"Collider budget")
    return plan
def dispatch():
    p=(ROOT/"tools/assets/pack_import.luau").read_text()
    helpers=p[p.index("local allowed="):p.index("local function cloneSelected")]
    helpers='local Assets=game:GetService("AssetService")\nlocal Serial=game:GetService("SerializationService")\n'+helpers
    source=(ROOT/"tools/sync/environment_layout.luau").read_text().replace("-- __RS_ASSET_HELPERS__",helpers)
    surface=(ROOT/"tools/terrain/surface_fields.luau").read_text()
    require(source.count("-- __RS_SURFACE_FIELDS__")==1,"Surface injection marker")
    source=source.replace("-- __RS_SURFACE_FIELDS__","local Surface=(function()\n"+surface+"\nend)()")
    return "do\n"+source+"\nend"
def verify_layout(plan,rows):
    require(len(rows)==plan["maxNewModels"] and len({r["id"] for r in rows})==len(rows),"Incomplete or duplicate layout")
    for a in plan["assets"]:
        matches=[r for r in rows if r["name"]==a["name"]]
        require(len(matches)==a["count"] and all(r["assetId"]==a["assetId"] and r["sourceDigest"]==a["sourceDigest"] and a["profile"]["scale"][0]<=r["scale"]<=a["profile"]["scale"][1] for r in matches),"Asset/layout mismatch")
    for i,a in enumerate(rows):
        require(a["tile"] in plan["placement"]["regionIds"] and a["slope"]<=15,"Support")
        for b in rows[:i]:
            x=a["position"][0]-b["position"][0];z=a["position"][2]-b["position"][2]
            require(x*x+z*z+0.001>=(a["radius"]+b["radius"]+2)**2,"Overlap")
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("operation",choices=["preview","apply"])
    p.add_argument("--reviewed",type=Path)
    p.add_argument("--spec",choices=["base","detail"],default="base")
    p.add_argument("--confirm-staging",action="store_true")
    p.add_argument("--output",type=Path,default=ROOT/"dist/p4-layout")
    a=p.parse_args()
    spec_path=SPEC if a.spec=="base" else GAME/"game/assets/environment-p4-detail-layout.json"
    plan=validate(read(spec_path));games,targets=load_all()
    t=resolve(games,targets,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    base=require_current(t,key)
    terrain={i:base["records"]["terrain:"+i]["digest"] for i in plan["placement"]["regionIds"]}
    opts=dict(environment="staging",plan=plan,expectedVersion=base["loadedVersion"],terrainExpected=terrain)
    if a.operation=="preview":
        report=task(t,key,dispatch(),mode="preview",**opts)
        verify_layout(plan,report["rows"])
        reviewed={"schemaVersion":1,"expectedVersion":base["loadedVersion"],"baselineDigest":base["stateDigest"],"plan":plan,"rows":report["rows"],"stats":report["stats"],"existingCount":report["existingCount"],"terrainExpected":terrain,"noPlaceWrites":True}
        reviewed["planDigest"]=sha(reviewed)
        write(a.output/"layout.json",reviewed)
        print("ENV_LAYOUT "+json.dumps(reviewed),flush=True)
        return
    require(a.confirm_staging and a.reviewed is not None,"Explicit reviewed staging plan required")
    reviewed=read(a.reviewed);digest=reviewed.pop("planDigest")
    require(sha(reviewed)==digest and reviewed["plan"]==plan and reviewed["expectedVersion"]==base["loadedVersion"] and reviewed["baselineDigest"]==base["stateDigest"] and reviewed["terrainExpected"]==terrain,"Stale reviewed layout")
    require(plan.get("importAuthorized") is True and all(a.get("rightsStatus")=="reviewed_platform_use" and a.get("importAuthorized") is True for a in plan["assets"]),"Explicit asset approval and rights review required before apply")
    verify_layout(plan,reviewed["rows"])
    runtime=(ROOT/"tools/scene_builder_ground.server.luau").read_text()
    result=task(t,key,dispatch(),mode="apply",layoutRows=reviewed["rows"],planDigest=digest,confirmStaging=True,runtimeSource=runtime,**opts)
    write(a.output/"save.json",result)
    require(result.get("saved") is True,"Save not confirmed")
    after=capture(t,key);write(a.output/"after.json",after)
    require(after["loadedVersion"]>base["loadedVersion"],"Persisted version not advanced")
    delta=reconcile(base,after);write(a.output/"changes.json",delta)
    scoped,defaults=split_default_clones(base,after,delta["external"])
    if defaults:write(a.output/"default-clone-delta.json",defaults)
    for change in scoped:
        r=after["records"].get(change["key"])
        require(change["change"]=="added" and r and r.get("service")=="Workspace" and r.get("path",[{}])[0]["name"]==plan.get("rootName","RSEnvironmentP4"),"Unexpected scene delta: "+change["key"])
    for row in reviewed["rows"]:
        r=after["records"].get("managed:"+row["id"])
        require(r is not None and r["class"]=="Model" and r["properties"]["pivot"][:3] and all(abs(a-b)<0.03 for a,b in zip(r["properties"]["pivot"][:3],row["position"])),"Persisted model mismatch")
    verification=task(t,key,dispatch(),mode="verify",environment="staging",plan=plan,expectedVersion=after["loadedVersion"],terrainExpected=terrain,layoutRows=reviewed["rows"],planDigest=digest,runtimeSource=runtime)
    require(verification.get("verified") is True and verification["loadedVersion"]==after["loadedVersion"],"Independent verification failed")
    for sample in verification.pop("samples").values():
        sample["offlinePbr"]=inspect_blob(sample)
        validate_evidence(sample)
    write(a.output/"verification.json",verification)
    print("ENV_LAYOUT_VERIFIED "+json.dumps({"version":after["loadedVersion"],"models":result["models"],"colliders":result["colliders"],"offlinePbrVerified":True}),flush=True)
if __name__=="__main__":
    try: main()
    except (WorkspaceError,OSError,KeyError,ValueError) as exc:
        print("ERROR:",exc);raise SystemExit(1)
