"""Read-only exact asset audits and existing canopy inventory for the P4 expansion."""
from __future__ import annotations
import json
import os
import sys
from pathlib import Path
from pack_import import audit_report
from pipeline import ROOT, write, WorkspaceError
from deploy import load_all,resolve
from scene_sync import require_current,task
from scene_patch import prepare

GAME=ROOT/"games/maps/mapa-principal"
SRC=GAME/"game/places/main/src"
def build_patch(base):
    records=base["records"]
    def find(name,cls,service):
        keys=[k for k,r in records.items() if r.get("name")==name and r.get("class")==cls and r.get("service")==service]
        if len(keys)!=1:raise WorkspaceError("Missing or ambiguous "+name)
        return keys[0]
    starter=find("StarterPlayerScripts","StarterPlayerScripts","StarterPlayer")
    ops=[]
    for name,cls,relative,parent in [
        ("RSWorldClock","ModuleScript","ReplicatedStorage/RSWorldClock.luau","service:ReplicatedStorage"),
        ("RSWorldTime","Script","ServerScriptService/RSWorldTime.server.luau","service:ServerScriptService"),
        ("RSWorldTime","LocalScript","StarterPlayer/StarterPlayerScripts/RSWorldTime.client.luau",starter),
        ("RSWindPolicy","ModuleScript","ReplicatedStorage/RSWindPolicy.luau","service:ReplicatedStorage"),
        ("RSWind","Script","ServerScriptService/RSWind.server.luau","service:ServerScriptService"),
        ("RSWind","LocalScript","StarterPlayer/StarterPlayerScripts/RSWind.client.luau",starter)]:
        ops.append({"kind":"create_script","name":name,"class":cls,"id":"p4-"+cls.lower()+"-"+name.lower(),"parentKey":parent,"sourcePath":str((SRC/relative).relative_to(ROOT))})
    ops.append({"kind":"update_script","targetKey":find("RSBoundaryGrid","LocalScript","StarterPlayer"),"archiveId":"p4-boundary-v10","sourcePath":str((SRC/"StarterPlayer/StarterPlayerScripts/RSBoundaryGrid.client.luau").relative_to(ROOT))})
    return {"schemaVersion":1,"expectedVersion":base["loadedVersion"],"baselineDigest":base["stateDigest"],"operations":ops}

def main():
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    games,targets=load_all()
    t=resolve(games,targets,"mapa-principal","main","staging")
    out=ROOT/"dist/p4-environment"
    base=require_current(t,key)
    plan=build_patch(base)
    ops=prepare(t,base,plan)
    preview=task(t,key,"do\n"+(ROOT/"tools/sync/patch.luau").read_text()+"\nend",mode="preview",environment="staging",expectedVersion=base["loadedVersion"],operations=ops)
    write(out/"script-patch.json",plan);write(out/"script-preview.json",preview)
    print("ENV_PATCH "+json.dumps({"plan":plan,"preview":preview}),flush=True)
    # Use exact observed existing model records to verify the canopy selection.
    rows={}
    for r in base["records"].values():
        if r.get("service")!="Workspace" or r.get("class")!="MeshPart":continue
        path=[x["name"] for x in r.get("path",[])]
        if not path or path[0] not in ("RSSceneBuilder","RSWorldVegetation"):continue
        name=r["name"];mat=r.get("properties",{}).get("material")
        k=name+"|"+str(mat)
        rows[k]=rows.get(k,0)+1
    write(out/"existing-meshes.json",rows)
    print("ENV_EXISTING "+json.dumps(rows),flush=True)
    spec=json.loads((GAME/"game/assets/environment-p4.json").read_text())
    results=[]
    for a in spec["assets"]:
        try:
            report=audit_report(t,key,a["assetId"],a["selector"])
            if report["loadedVersion"]!=base["loadedVersion"]:raise WorkspaceError("Place changed")
            write(out/(a["name"]+"-audit.json"),report)
            item={"name":a["name"],"assetId":a["assetId"],"status":"exact_v2_pass","loadedVersion":report["loadedVersion"],
                "digest":report["digest"],"parts":report["audit"]["parts"],"surfaces":report["audit"]["surfaces"],
                "bounds":report["audit"]["bounds"],"meshNames":[x["path"][-1]["name"] for x in report["audit"]["rows"] if x["class"]=="MeshPart"],
                "meshRows":[x for x in report["audit"]["rows"] if x["class"]=="MeshPart"],"dependencies":report["audit"]["dependencies"],"importAuthorized":False}
        except (WorkspaceError,ValueError,KeyError,OSError) as exc:
            item={"name":a["name"],"assetId":a["assetId"],"status":"blocked","diagnostic":str(exc)[:400],"importAuthorized":False}
        results.append(item)
        print("ENV_ASSET "+json.dumps(item),flush=True)
        if item["status"]=="blocked" and ("429" in item.get("diagnostic","") or "Place changed" in item.get("diagnostic","")):break
    write(out/"summary.json",{"results":results,"loadedVersion":base["loadedVersion"],"noPlaceWrites":True})
    return 0 if len(results)==len(spec["assets"]) and all(x["status"]=="exact_v2_pass" for x in results) else 2
if __name__=="__main__":
    raise SystemExit(main())
