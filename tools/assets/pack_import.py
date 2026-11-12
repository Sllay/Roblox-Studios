"""Safe Import v2 for exact MeshPart/SurfaceAppearance submodels.

Audit via official Content API plus offline RBXM inspection. Raw asset bytes are
temporary, never committed or uploaded. Staging only, reviewed plan required.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
import math
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from pipeline import ROOT,check_id,read,write,WorkspaceError
from pack import validate_selector
from placement import validate_profile
from cloud_tasks import run_task
from deploy import load_all,resolve
from scene_snapshot import capture,compare,canonical

SOURCE=Path(__file__).with_suffix(".luau")
MANIFEST=Path(__file__).parent/"rbx-audit/Cargo.toml"
URI=re.compile(r"rbxassetid://[1-9][0-9]*")
MANAGED=re.compile(r"[a-z][a-z0-9-]{2,63}")

def task(target,key,mode,asset,selector,**options):
    cfg=dict(mode=mode,assetId=check_id(asset),selector=validate_selector(selector),
             universeId=target["universeId"],placeId=target["placeId"],**options)
    payload=canonical(cfg)
    for n in range(1,16):
        eq="="*n
        if "]"+eq+"]" not in payload:
            src=SOURCE.read_text().replace("-- __RS_PLACEMENT__", SOURCE.with_name("placement.luau").read_text()).replace("__RS_CONFIG__","["+eq+"["+payload+"]"+eq+"]")
            return run_task(target["universeId"],target["placeId"],key,src)
    raise WorkspaceError("Invalid config")

def inspect_blob(report):
    encoded=report.pop("serializedBase64",None)
    if not isinstance(encoded,str) or len(encoded)>700000:
        raise WorkspaceError("Missing or oversized serialized model")
    blob=base64.b64decode(encoded,validate=True)
    digest=base64.b64encode(hashlib.sha256(blob).digest()).decode()
    if digest!=report.get("digest",report.get("persistedDigest")) or not blob.startswith(b"<roblox!"):
        raise WorkspaceError("Serialized model digest or format mismatch")
    with tempfile.TemporaryDirectory() as temp:
        path=Path(temp)/"model.rbxm";path.write_bytes(blob)
        result=subprocess.run(["cargo","run","--quiet","--manifest-path",str(MANIFEST),"--",str(path)],
                              capture_output=True,text=True,timeout=240,check=True)
    line=next((line for line in result.stdout.splitlines() if line.startswith("RBXM_PBR ")),None)
    if line is None: raise WorkspaceError("RBXM parser returned no report")
    return json.loads(line.removeprefix("RBXM_PBR "))

def audit_report(target,key,asset,selector):
    r=task(target,key,"audit",asset,selector)
    r["offlinePbr"]=inspect_blob(r)
    r["selector"]=selector
    validate_evidence(r)
    return r

def validate_evidence(r):
    a=r["audit"]
    if a["policyVersion"]!=2 or not 1<=a["parts"]<=100 or not 1<=a["instances"]<=350:
        raise WorkspaceError("Policy mismatch")
    surfaces=[row for row in a["rows"] if row["class"]=="SurfaceAppearance"]
    if len(surfaces)!=a["surfaces"] or len(r["offlinePbr"])!=len(surfaces):
        raise WorkspaceError("Offline surface count differs")
    # Compare public authoring maps against serialized fields; internal engine
    # texture pack is additional evidence, never modified or fetched as a script.
    for row in surfaces:
        name=row["path"][-1]["name"]
        matches=[x for x in r["offlinePbr"] if x["name"]==name]
        if len(matches)!=1: raise WorkspaceError("Ambiguous offline surface identity")
        props=matches[0]["properties"]
        for field,uri in row["maps"].items():
            old=field.removesuffix("Content")
            candidates=[props[k] for k in (field,old) if k in props]
            def val(v):
                if isinstance(v,str): return "" if v=="None" else v
                if isinstance(v,dict) and set(v)=={"Uri"}:return v["Uri"]
                return None
            if not candidates or uri not in [val(v) for v in candidates]:
                raise WorkspaceError(f"Offline map mismatch: {name}/{field}")
        if "TexturePackContent" not in props and "TexturePack" not in props:
            raise WorkspaceError("Serialized texture pack field missing")
        for k,v in props.items():
            if "TexturePack" in k:
                if isinstance(v,dict): v=v.get("Uri","" if not v else None)
                if v is None or (v not in ("","None") and not URI.fullmatch(v)):
                    raise WorkspaceError("Unknown runtime texture pack representation")
    fetched=r.get("dependencyFetch") or {}
    if fetched.get("verified") is not True:raise WorkspaceError("Dependency fetch not confirmed")
    for row in a["rows"]:
        if row["class"]=="MeshPart":
            if fetched.get("meshes",{}).get(row["mesh"])!="Success":raise WorkspaceError("Mesh fetch missing")
            if row["texture"] and fetched.get("textures",{}).get(row["texture"])!="Success":raise WorkspaceError("Texture fetch missing")
        elif row["class"]=="SurfaceAppearance":
            for uri in row["maps"].values():
                if uri and fetched.get("textures",{}).get(uri)!="Success":raise WorkspaceError("PBR texture fetch missing")
    if any(not URI.fullmatch(x) for x in a["dependencies"]):
        raise WorkspaceError("Unsupported dependency")
    return a

def validate_plan(t,p):
    if t["environment"]!="staging" or p.get("environment")!="staging" or any(p.get(k)!=t[k] for k in ("universeId","placeId","game","place")):
        raise WorkspaceError("Plan target mismatch")
    check_id(p["assetId"]);validate_selector(p["selector"])
    if not MANAGED.fullmatch(p["managedId"]):raise WorkspaceError("Invalid managed id")
    if not isinstance(p.get("rightsReview"),str) or len(p["rightsReview"])<20:raise WorkspaceError("Rights review required")
    if not isinstance(p.get("position"),list) or len(p["position"])!=3 or not all(type(x) in (int,float) and math.isfinite(x) and abs(x)<=100000 for x in p["position"]):raise WorkspaceError("Invalid position")
    if type(p.get("yaw")) not in (int,float) or not math.isfinite(p["yaw"]) or abs(p["yaw"])>360:raise WorkspaceError("Invalid yaw")
    r=p["evidence"]
    if any(r.get(k)!=p[k] for k in ("universeId","placeId","assetId")) or r["loadedVersion"]!=p["expectedVersion"]:
        raise WorkspaceError("Evidence target mismatch")
    validate_evidence(r)
    registry=read(ROOT/"games"/"maps"/t["game"]/"game/assets/visual-reviews"/(p["assetId"]+".json"))
    rows=[x for x in registry["reviews"] if x["selector"]==p["selector"] and x["visual"]["status"] in ("geometry_reviewed","visual_reviewed")]
    if len(rows)!=1 or p["biome"] not in rows[0]["visual"]["inferred"]["suitableBiomes"]:raise WorkspaceError("Visual review or biome mismatch")
    profile=validate_profile(p.get("placementProfile"))
    if profile!=rows[0].get("placementProfile"):raise WorkspaceError("Placement profile not reviewed for this model")
    if p["evidenceSha256"]!=hashlib.sha256(canonical(r).encode()).hexdigest():
        raise WorkspaceError("Evidence hash mismatch")
    if r["digest"]!=p["digest"]:raise WorkspaceError("Digest mismatch")
    if p.get("selector")!=r.get("selector"):raise WorkspaceError("Selector differs from audit")
    if p.get("schemaVersion")!=2 or not isinstance(p.get("biome"),str) or not p["biome"].strip():raise WorkspaceError("Invalid plan schema or biome")
    return p

def equivalent(a,b):
    if type(a)!=type(b):
        if type(a) in (int,float) and type(b) in (int,float):return abs(a-b)<0.025
        return False
    if isinstance(a,(int,float)) and not isinstance(a,bool):return abs(a-b)<0.025
    if isinstance(a,list):return len(a)==len(b) and all(equivalent(x,y) for x,y in zip(a,b))
    if isinstance(a,dict):return a.keys()==b.keys() and all(equivalent(a[k],b[k]) for k in a)
    return a==b

def apply(t,key,p,output):
    validate_plan(t,p)
    before=capture(t,key);write(output/"before.json",before)
    if before["loadedVersion"]!=p["expectedVersion"]:raise WorkspaceError("Place version changed; prepare new plan")
    if any(x.get("managedId")==p["managedId"] for x in before["objects"]):raise WorkspaceError("Already imported")
    options=dict(managedId=p["managedId"],digest=p["digest"],selectorJson=canonical(p["selector"]),
                 position=p["position"],yaw=p["yaw"],biome=p["biome"],placementProfile=p["placementProfile"])
    result=task(t,key,"apply",p["assetId"],p["selector"],expectedVersion=p["expectedVersion"],environment="staging",**options)
    write(output/"save-result.json",result)
    if result.get("saved") is not True:raise WorkspaceError("Save unconfirmed")
    v=task(t,key,"verify",p["assetId"],p["selector"],**options)
    v["offlinePbr"]=inspect_blob(v)
    validate_evidence(v)
    write(output/"verification.json",v)
    if not v["verified"] or v["loadedVersion"]<=before["loadedVersion"] or not equivalent(p["evidence"]["audit"],v["audit"]):
        raise WorkspaceError("Persisted model differs from reviewed source")
    # Authoring maps and engine-packed references must remain identical.
    if sorted(p["evidence"]["offlinePbr"],key=lambda x:x["name"])!=sorted(v["offlinePbr"],key=lambda x:x["name"]):
        raise WorkspaceError("Persisted PBR references changed")
    after=capture(t,key);write(output/"after.json",after)
    delta=compare(before,after);write(output/"diff.json",delta)
    if delta["removed"] or after["loadedVersion"]!=v["loadedVersion"]:
        raise WorkspaceError("Unexpected scene mutation or version")
    print(f"PACK IMPORT VERIFIED {p['managedId']} version {v['loadedVersion']}",flush=True)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("operation",choices=["audit","prepare","apply","placement-probe"])
    p.add_argument("--game",default="mapa-principal")
    p.add_argument("--place",default="main")
    p.add_argument("--asset-id")
    p.add_argument("--selector",type=Path)
    p.add_argument("--plan",type=Path)
    p.add_argument("--evidence",type=Path)
    p.add_argument("--managed-id",default="yasu-tree-01")
    p.add_argument("--biome",default="floresta-temperada")
    p.add_argument("--rights-review")
    p.add_argument("--position",nargs=3,type=float)
    p.add_argument("--yaw",type=float,default=0)
    p.add_argument("--confirm-staging",action="store_true")
    p.add_argument("--output",type=Path,default=ROOT/"dist"/"pack-import")
    a=p.parse_args()
    try:
        games,targets=load_all();t=resolve(games,targets,a.game,a.place,"staging")
        key=os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY","")
        if a.operation=="placement-probe":
            if not a.selector or not a.asset_id or not a.position:raise WorkspaceError("Selector, asset and position required")
            selector=json.loads(a.selector.read_text())
            registry=read(ROOT/"games"/"maps"/t["game"]/"game/assets/visual-reviews"/(check_id(a.asset_id)+".json"))
            rows=[x for x in registry["reviews"] if x["selector"]==selector]
            if len(rows)!=1:raise WorkspaceError("Missing model review")
            profile=validate_profile(rows[0].get("placementProfile"))
            report=task(t,key,"placement_probe",a.asset_id,selector,position=a.position,yaw=a.yaw,placementProfile=profile)
            write(a.output/"placement.json",report); print(json.dumps(report,ensure_ascii=False)); return 0
        if a.operation=="prepare":
            if not a.evidence or not a.plan or not a.rights_review or not a.position:raise WorkspaceError("Evidence, plan, explicit position and rights review required")
            r=read(a.evidence)
            plan=dict(schemaVersion=2,game=t["game"],place=t["place"],environment="staging",universeId=t["universeId"],placeId=t["placeId"],assetId=r["assetId"],selector=r["selector"],managedId=a.managed_id,biome=a.biome,rightsReview=a.rights_review,position=a.position,yaw=a.yaw,expectedVersion=r["loadedVersion"],digest=r["digest"],evidence=r,evidenceSha256=hashlib.sha256(canonical(r).encode()).hexdigest())
            registry=read(ROOT/"games"/"maps"/t["game"]/"game/assets/visual-reviews"/(r["assetId"]+".json"))
            rows=[x for x in registry["reviews"] if x["selector"]==r["selector"]]
            if len(rows)!=1:raise WorkspaceError("Missing placement review")
            plan["placementProfile"]=validate_profile(rows[0].get("placementProfile"))
            validate_plan(t,plan)
            if a.plan.exists():raise WorkspaceError("Plan already exists")
            write(a.plan,plan)
            print(f"Prepared plan {a.plan}; no write to Roblox")
            return 0
        if not key:raise WorkspaceError("Missing Open Cloud key")
        if a.operation=="audit":
            selector=json.loads(a.selector.read_text())
            report=audit_report(t,key,a.asset_id,selector)
            write(a.output/"audit.json",report)
            print("PACK_AUDIT",json.dumps(report,ensure_ascii=False),flush=True)
        else:
            if not a.confirm_staging or not a.plan:raise WorkspaceError("Explicit staging confirmation required")
            apply(t,key,read(a.plan),a.output)
        return 0
    except (WorkspaceError,OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError) as exc:
        print(f"ERROR: {exc}",file=sys.stderr)
        return 1
if __name__=="__main__":raise SystemExit(main())
