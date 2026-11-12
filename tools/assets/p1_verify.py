
"""Resume the P1 verification after a rate limit. No task saves the Place."""
from __future__ import annotations
import argparse,json,os
from pathlib import Path
from pack_import import ROOT,task,inspect_blob,validate_evidence,equivalent,WorkspaceError,read,write
from deploy import load_all,resolve
from scene_snapshot import capture,compare,canonical
from placement import validate_profile

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prior",type=Path,required=True)
    a=parser.parse_args()
    games,targets=load_all();t=resolve(games,targets,"mapa-principal","main","staging")
    if (t["universeId"],t["placeId"])!=("10769712441","93428341652658"):raise WorkspaceError("Unexpected target")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    old=read(a.prior/"before.json");saved=read(a.prior/"save.json");original=read(a.prior/"original.json")
    if old["loadedVersion"]!=2 or saved.get("saved") is not True:raise WorkspaceError("Missing prior save evidence")
    folder=ROOT/"games/maps/mapa-principal/game/assets"
    p=read(folder/"imports/tree-01-p1.json")
    item=next(x for x in read(folder/"visual-reviews/79689531752352.json")["reviews"] if x["name"]=="Tree_01")
    profile=validate_profile(item["placementProfile"])
    pos=saved["placement"]["position"]
    client=Path(__file__).with_name("lighting_lab.client.luau").read_text()
    out=ROOT/"dist"/"p1-verify"
    v=task(t,key,"verify",p["assetId"],p["selector"],managedId=p["managedId"],digest=p["digest"],selectorJson=canonical(p["selector"]),yaw=p["yaw"],biome=p["biome"],position=pos,verifyLab=True,clientSource=client,placementProfile=profile)
    v["offlinePbr"]=inspect_blob(v);validate_evidence(v);write(out/"verification.json",v)
    if v["loadedVersion"]!=3 or not v["verified"] or not equivalent(v["audit"],original["audit"]) or v["offlinePbr"]!=original["offlinePbr"]:raise WorkspaceError("Persisted model mismatch")
    if not equivalent(v["controlAudit"],original["audit"]):raise WorkspaceError("Source comparison differs")
    if not equivalent(v["placement"]["position"],pos):raise WorkspaceError("Ground result mismatch")
    after=capture(t,key);write(out/"after.json",after)
    delta=compare(old,after);write(out/"diff.json",delta)
    prefix="Workspace.RSManagedAssets.yasu-tree-01"
    if len(delta["removed"])!=3 or len(delta["added"])!=3 or any(not x["path"].startswith(prefix) for x in delta["removed"]+delta["added"]):raise WorkspaceError("Unexpected workspace diff")
    if after["loadedVersion"]!=v["loadedVersion"]:raise WorkspaceError("Version changed")
    print("P1_FINAL_VERIFIED",json.dumps({"version":3,"position":pos,"placement":v["placement"],"lighting":saved["lighting"],"postEffects":saved["postEffects"],"changedWorkspaceRecords":len(delta["added"]),"controlMatches":True,"pbrMatches":True}),flush=True)
    return 0
if __name__=="__main__":raise SystemExit(main())
