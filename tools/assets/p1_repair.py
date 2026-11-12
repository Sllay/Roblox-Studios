
"""One-time staging calibration and lighting lab, with independent persistence checks."""
from __future__ import annotations
import json,os,sys
from pathlib import Path
from pack_import import ROOT,task,inspect_blob,validate_evidence,equivalent,WorkspaceError,read,write
from deploy import load_all,resolve
from scene_snapshot import capture,compare,canonical
from placement import validate_profile,pivot_y

def main():
    games,targets=load_all()
    t=resolve(games,targets,"mapa-principal","main","staging")
    if (t["universeId"],t["placeId"])!=("10769712441","93428341652658"):raise WorkspaceError("P1 repair target changed")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    folder=ROOT/"games/maps/mapa-principal/game/assets"
    p=read(folder/"imports/tree-01-p1.json")
    registry=read(folder/"visual-reviews/79689531752352.json")
    item=next(x for x in registry["reviews"] if x["name"]=="Tree_01")
    profile=validate_profile(item["placementProfile"])
    out=ROOT/"dist"/"p1-repair"
    before=capture(t,key);write(out/"before.json",before)
    if before["loadedVersion"]!=2:raise WorkspaceError("Expected staging version 2; inspect before retry")
    client=Path(__file__).with_name("lighting_lab.client.luau").read_text()
    old=p["position"]
    old_pivot=old+[1,0,0,0,1,0,0,0,1]
    opts=dict(managedId=p["managedId"],digest=p["digest"],selectorJson=canonical(p["selector"]),yaw=p["yaw"],biome=p["biome"])
    probe=task(t,key,"placement_probe",p["assetId"],p["selector"],position=old,yaw=p["yaw"],placementProfile=profile)
    write(out/"placement-probe.json",probe)
    if probe["loadedVersion"]!=2 or probe["digest"]!=p["digest"]:raise WorkspaceError("Placement source/version mismatch")
    pos=probe["placement"]["position"]
    if abs(pos[1]-pivot_y(probe["placement"]["groundY"],probe["placement"]["bottomOffset"],profile["buryDepthStuds"]))>0.01:raise WorkspaceError("Placement math mismatch")
    original=task(t,key,"verify",p["assetId"],p["selector"],position=old,**opts)
    original["offlinePbr"]=inspect_blob(original);validate_evidence(original)
    if not equivalent(original["audit"],p["evidence"]["audit"]) or original["offlinePbr"]!=p["evidence"]["offlinePbr"]:raise WorkspaceError("Original differs from source")
    write(out/"original.json",original)
    result=task(t,key,"repair",p["assetId"],p["selector"],expectedVersion=2,environment="staging",
                position=pos,oldPivot=old_pivot,placementProfile=profile,clientSource=client,**opts)
    write(out/"save.json",result)
    if not result.get("saved"):raise WorkspaceError("Save not confirmed")
    v=task(t,key,"verify",p["assetId"],p["selector"],position=pos,verifyLab=True,clientSource=client,**opts)
    v["offlinePbr"]=inspect_blob(v);validate_evidence(v);write(out/"verification.json",v)
    if v["loadedVersion"]<=2 or not equivalent(v["audit"],original["audit"]) or v["offlinePbr"]!=original["offlinePbr"]:raise WorkspaceError("Persisted appearance differs")
    after=capture(t,key);write(out/"after.json",after)
    delta=compare(before,after);write(out/"diff.json",delta)
    prefix="Workspace.RSManagedAssets.yasu-tree-01"
    if len(delta["removed"])!=3 or len(delta["added"])!=3 or any(not x["path"].startswith(prefix) for x in delta["removed"]+delta["added"]):raise WorkspaceError("Unexpected workspace changes")
    if after["loadedVersion"]!=v["loadedVersion"]:raise WorkspaceError("Version changed during verification")
    print("P1_REPAIR_VERIFIED",json.dumps({"version":v["loadedVersion"],"position":pos,"lighting":result["lighting"],"postEffects":result["postEffects"],"placement":result["placement"],"changedWorkspaceRecords":len(delta["added"])},ensure_ascii=False),flush=True)
    return 0
if __name__=="__main__":
    try:raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}",file=sys.stderr);raise
