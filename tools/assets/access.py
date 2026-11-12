"""Asset access preflight: detached audit, no permission changes, no save.

The result is scoped to one Universe/Place and one asset, never a universal grant.
"""
from __future__ import annotations
import argparse
import json
import os
import sys
from pathlib import Path
from pipeline import ROOT, call, write, check_id, WorkspaceError
from deploy import load_all, resolve

def classify_failure(exc):
    message = str(exc)
    lower = message.lower()
    if "http 429" in lower:
        return "rate_limited", "Stop the batch; retry later."
    if "asset load denied or unavailable:" in lower:
        if any(x in lower for x in ("not authorized", "not permitted", "permission", "access denied")):
            return "asset_access_denied", "Acquire the free model using the Creator Store or request sharing from its owner; then recheck. Ownership and experience permissions matter."
        return "asset_unavailable", "Check asset ID, availability and permissions; do not import."
    if "http 401" in lower or "http 403" in lower:
        return "cloud_access_denied", "Check API key scope and access to the target Universe."
    return "unknown_error", "Inspect the API diagnostic; no approval and no write."

def assess(target,key,asset_id):
    check_id(asset_id)
    result = {"schemaVersion":1, "game":target["game"], "place":target["place"],
              "environment":target["environment"], "universeId":target["universeId"],
              "placeId":target["placeId"], "assetId":asset_id,
              "sourceUrl":f"https://create.roblox.com/store/asset/{asset_id}",
              "importAuthorized":False}
    try:
        report=call(target,key,"audit",asset_id)
    except WorkspaceError as exc:
        state,action=classify_failure(exc)
        return {**result,"status":state,"loadable":False if state=="asset_access_denied" else None,
                "policyPassed":None,"diagnostic":str(exc)[:1000],"nextAction":action}
    audit=report.get("audit") or {}
    if audit.get("policyVersion")!=1 or not isinstance(audit.get("allowed"),bool):
        raise WorkspaceError("Malformed audit result")
    passed=audit["allowed"]
    incomplete=audit.get("inspectionComplete") is False
    status="loadable_audit_incomplete" if incomplete else ("loadable_policy_pass" if passed else "loadable_policy_rejected")
    return {**result,"status":status,
            "loadable":True,"policyPassed":passed,"loadedVersion":report["loadedVersion"],
            "nextAction":("Inspect restricted texture properties via an authorized offline model inspection path; do not import." if incomplete else
                          ("Review visuals, rights and dependencies; prepare a staging plan." if passed else
                           "Reject model under static decoration policy; choose another candidate.")),
            "auditReport":report}

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game",default="mapa-principal")
    p.add_argument("--place",default="main")
    p.add_argument("--environment",choices=["staging","production"],default="staging")
    p.add_argument("--asset-id",action="append",required=True)
    p.add_argument("--output",type=Path,default=ROOT/"dist"/"asset-access")
    args=p.parse_args(argv)
    try:
        ids=list(dict.fromkeys(check_id(x) for x in args.asset_id))
        if not 1<=len(ids)<=3:
            raise WorkspaceError("Check at most three unique asset IDs per run")
        games,targets=load_all()
        target=resolve(games,targets,args.game,args.place,args.environment)
        key=os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY","")
        if not key: raise WorkspaceError("Missing Open Cloud key")
        results=[]
        for asset_id in ids:
            report=assess(target,key,asset_id)
            results.append(report)
            write(args.output/f"access-{asset_id}.json",report)
            print(f"{asset_id}: {report['status']} | {report['nextAction']}",flush=True)
            if report["status"] in ("rate_limited","cloud_access_denied","unknown_error"):
                break
        write(args.output/"summary.json",{"schemaVersion":1,"requested":ids,"results":results,
            "complete":len(results)==len(ids),"noPlaceWrites":True})
        return 0 if len(results)==len(ids) and all(r["status"] in
            ("asset_access_denied","loadable_policy_pass","loadable_policy_rejected","loadable_audit_incomplete") for r in results) else 2
    except (WorkspaceError,OSError,ValueError) as exc:
        print(f"ERROR: {exc}",file=sys.stderr)
        return 1

if __name__=="__main__":
    raise SystemExit(main())
