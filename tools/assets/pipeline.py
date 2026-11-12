"""Audit a detached model, prepare a reviewed import plan, or apply it to staging.

No production writes. No automatic purchase, asset permissions change or code execution.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
import re
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tools"))
from cloud_tasks import run_task
from deploy import load_all,resolve,WorkspaceError
from scene_snapshot import capture,compare,canonical

SOURCE=Path(__file__).with_name("static_asset.luau")
ID=re.compile(r"^[1-9][0-9]{0,15}$")
MANAGED=re.compile(r"^[a-z][a-z0-9-]{2,63}$")
def check_id(value):
    if not isinstance(value,str) or not ID.fullmatch(value) or int(value)>9007199254740991:
        raise WorkspaceError("Invalid or imprecise asset ID")
    return value
def build_source(config):
    payload=canonical(config)
    for n in range(1,16):
        equal="="*n
        if "]"+equal+"]" not in payload:
            return SOURCE.read_text().replace("__RS_CONFIG__","["+equal+"["+payload+"]"+equal+"]")
    raise WorkspaceError("Cannot encode configuration")

def call(target,key,mode,asset_id,**extra):
    config=dict(mode=mode,assetId=check_id(asset_id),universeId=target["universeId"],placeId=target["placeId"],**extra)
    return run_task(target["universeId"],target["placeId"],key,build_source(config))

def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

def read(path):
    data=json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data,dict): raise WorkspaceError("Expected JSON object")
    return data

def validate_report(report,target,asset_id):
    if report.get("universeId")!=target["universeId"] or report.get("placeId")!=target["placeId"] or report.get("assetId")!=asset_id:
        raise WorkspaceError("Audit target/asset mismatch")
    audit=report.get("audit") or {}
    if audit.get("policyVersion")!=1 or audit.get("allowed") is not True or audit.get("issues")!=[]:
        raise WorkspaceError("Asset failed policy or has no approved audit")
    rows=audit.get("signature")
    if not isinstance(rows,list) or not rows or len(rows)>350 or not all(isinstance(x,str) for x in rows):
        raise WorkspaceError("Invalid audit signature")
    if not isinstance(audit.get("parts"),int) or not 1<=audit["parts"]<=100:
        raise WorkspaceError("Invalid audit part count")
    if not isinstance(report.get("loadedVersion"),int) or report["loadedVersion"]<1:
        raise WorkspaceError("Audit missing Place version")
    return audit

def prepare(target,asset_id,managed_id,position,yaw,biome,rights,report,catalog):
    check_id(asset_id)
    if target["environment"]!="staging": raise WorkspaceError("Import plans are staging-only")
    if not MANAGED.fullmatch(managed_id): raise WorkspaceError("Invalid managed ID")
    if not isinstance(position,list) or len(position)!=3 or not all(isinstance(v,(int,float)) and not isinstance(v,bool) and math.isfinite(v) and abs(v)<=100000 for v in position):
        raise WorkspaceError("Invalid position")
    if not isinstance(yaw,(int,float)) or not math.isfinite(yaw) or abs(yaw)>360: raise WorkspaceError("Invalid yaw")
    if not isinstance(biome,str) or not biome.strip() or len(biome)>80: raise WorkspaceError("Biome required")
    if not isinstance(rights,str) or len(rights.strip())<12 or len(rights)>500: raise WorkspaceError("Document rights/permission review explicitly")
    candidates=[a for a in catalog.get("assets",[]) if a.get("id")==asset_id and a.get("reviewStatus")=="visual_shortlisted" and a.get("biome")==biome]
    if len(candidates)!=1: raise WorkspaceError("Asset must be visually shortlisted for this biome")
    audit=validate_report(report,target,asset_id)
    return dict(schemaVersion=1,game=target["game"],place=target["place"],environment="staging",
        universeId=target["universeId"],placeId=target["placeId"],assetId=asset_id,
        managedId=managed_id,position=position,yaw=yaw,biome=biome,rightsReview=rights,
        expectedVersion=report["loadedVersion"],audit=report,
        auditSha256=hashlib.sha256(canonical(report).encode()).hexdigest())

def apply(target,key,plan,catalog,output):
    expected=prepare(target,plan["assetId"],plan["managedId"],plan["position"],plan["yaw"],plan["biome"],
                    plan["rightsReview"],plan["audit"],catalog)
    if expected!=plan: raise WorkspaceError("Plan does not match reviewed target/evidence")
    before=capture(target,key)
    write(output/"before.json",before)
    if before["loadedVersion"]!=plan["expectedVersion"]:
        raise WorkspaceError("Place changed since audit; review a new plan")
    if any(x.get("managedId")==plan["managedId"] for x in before["objects"]):
        raise WorkspaceError("Managed ID already exists")
    # The loader returns latest content; audit again in the SAME task before saving.
    audit=plan["audit"]["audit"]
    result=call(target,key,"apply",plan["assetId"],managedId=plan["managedId"],
        expectedVersion=plan["expectedVersion"],signature=audit["signature"],
        position=plan["position"],yaw=plan["yaw"],biome=plan["biome"])
    write(output/"save-result.json",result)
    if result.get("saved") is not True: raise WorkspaceError("Save unconfirmed")
    verified=call(target,key,"verify",plan["assetId"],managedId=plan["managedId"],parts=audit["parts"])
    write(output/"verification.json",verified)
    if verified.get("verified") is not True or verified["loadedVersion"]<=before["loadedVersion"]:
        raise WorkspaceError("Persistence/version not confirmed; investigate before retry")
    after=capture(target,key)
    write(output/"after.json",after)
    write(output/"diff.json",compare(before,after))
    print(f"STAGING IMPORT VERIFIED: {plan['managedId']} version {verified['loadedVersion']}")

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("mode",choices=["audit","prepare","apply"])
    p.add_argument("--game",default="mapa-principal")
    p.add_argument("--place",default="main")
    p.add_argument("--environment",choices=["production","staging"],default="staging")
    p.add_argument("--asset-id")
    p.add_argument("--managed-id")
    p.add_argument("--position",nargs=3,type=float)
    p.add_argument("--yaw",type=float,default=0)
    p.add_argument("--biome")
    p.add_argument("--rights-review")
    p.add_argument("--audit",type=Path)
    p.add_argument("--plan",type=Path)
    p.add_argument("--confirm-staging",action="store_true")
    p.add_argument("--output",type=Path,default=ROOT/"dist"/"asset-pipeline")
    args=p.parse_args()
    try:
        games,targets=load_all()
        target=resolve(games,targets,args.game,args.place,args.environment)
        key=os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY","")
        if args.mode=="audit":
            if not key: raise WorkspaceError("Missing Open Cloud key")
            report=call(target,key,"audit",args.asset_id)
            write(args.output/"audit.json",report)
            print("AUDIT RESULT:",json.dumps({k:v for k,v in report["audit"].items() if k!="signature"}))
            return 0 if report["audit"]["allowed"] else 2
        if args.environment!="staging": raise WorkspaceError("Writes are staging-only")
        catalog=read(ROOT/"games"/"maps"/args.game/"game/assets/catalog.json")
        if args.mode=="prepare":
            if not args.audit or not args.plan: raise WorkspaceError("Audit and plan paths required")
            plan=prepare(target,args.asset_id,args.managed_id,args.position,args.yaw,args.biome,args.rights_review,read(args.audit),catalog)
            if args.plan.exists(): raise WorkspaceError("Plan already exists")
            write(args.plan,plan)
            print(f"REVIEW PLAN ONLY: {args.plan}")
            return 0
        if not args.confirm_staging or not args.plan or not key:
            raise WorkspaceError("Explicit staging confirmation, plan and key required")
        from script_quality import main as check_luau
        if check_luau([])!=0: raise WorkspaceError("Luau quality gate failed")
        apply(target,key,read(args.plan),catalog,args.output)
        return 0
    except (WorkspaceError,OSError,ValueError,TypeError,KeyError) as exc:
        print(f"ERROR: {exc}",file=sys.stderr)
        return 1
if __name__=="__main__":
    raise SystemExit(main())
