"""P4 user-selected packs: detached read-only inventory, max 3 per invocation."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
from pipeline import ROOT, check_id, write, WorkspaceError
from pack import inspect
from access import classify_failure
from deploy import load_all, resolve

def load_intake(path):
    data=json.loads(path.read_text(encoding="utf-8"))
    if data.get("schemaVersion")!=1 or data.get("game")!="mapa-principal" or data.get("environment")!="staging":
        raise WorkspaceError("Invalid P4 intake scope")
    rows=data["assets"]
    ids=[check_id(row["id"]) for row in rows]
    if len(ids)!=len(set(ids)) or not ids:
        raise WorkspaceError("Duplicate or empty intake")
    return rows

def inspect_mixed(target,key,asset_id):
    return inspect(target,key,asset_id,components=True)

def run_batch(target,key,rows,output,inspect_fn=inspect_mixed):
    results=[]
    for row in rows:
        asset_id=row["id"]
        try:
            report=inspect_fn(target,key,asset_id)
            pack=report["pack"]
            write(output/f"pack-{asset_id}.json",report)
            mixed=pack.get("componentInventory")
            if not isinstance(mixed,dict) or mixed.get("codeExecuted") is not False:
                raise WorkspaceError("Mixed inventory evidence missing")
            result={"id":asset_id,"status":"inventory_truncated" if pack["inventoryTruncated"] or mixed["truncated"] else "inventory_observed",
                    "models":pack["totalModels"],"scripts":pack["scriptsInPack"],
                    "components":mixed["total"],"classes":mixed["classes"],"importAuthorized":False,
                    "loadedVersion":report.get("loadedVersion"),"staticAudit":pack.get("staticAudit"),
                    "sampleAudit":pack.get("sampleAudit"),"codeReview":mixed.get("codeReview",[]),
                    "codeReviewTruncated":mixed.get("codeReviewTruncated",False),
                    "modelCandidates":[{"name":c["name"],"parts":c["parts"],"pbr":c["pbr"],"eligible":c["technicalCandidate"]} for c in pack.get("candidates",[])][:100]}
        except WorkspaceError as exc:
            status,action=classify_failure(exc)
            if "Asset is not a Model" in str(exc):
                status,action="unsupported_asset_type","Inspect the Creator Store asset type with a dedicated read-only tool."
            result={"id":asset_id,"status":status,"diagnostic":str(exc)[:1000],"nextAction":action,"importAuthorized":False}
        results.append(result)
        print("AUDIT_RESULT "+json.dumps(result,ensure_ascii=False),flush=True)
        write(output/"summary.json",{"schemaVersion":1,"requested":[r["id"] for r in rows],
            "results":results,"noPlaceWrites":True,"complete":len(results)==len(rows)})
        if result["status"] in ("rate_limited","cloud_access_denied","unknown_error"):
            break
    return results

def pending_rows(rows):
    return [r for r in rows if r.get("auditEvidence",{}).get("inventoryStatus") not in ("inventory_observed","inventory_truncated")]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--batch",required=True,choices=["all","resume","1","2","3","4"])
    p.add_argument("--output",type=Path,default=ROOT/"dist"/"p4-intake")
    a=p.parse_args()
    try:
        rows=load_intake(ROOT/"games/maps/mapa-principal/game/assets/intake-p4.json")
        games,targets=load_all()
        target=resolve(games,targets,"mapa-principal","main","staging")
        key=os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY")
        if not key: raise WorkspaceError("Missing Open Cloud key")
        if a.batch=="resume":
            rows=pending_rows(rows)
        batches=range(1,(len(rows)+2)//3+1) if a.batch in ("all","resume") else [int(a.batch)]
        all_results=[]
        for batch in batches:
            selected=rows[(batch-1)*3:batch*3]
            results=run_batch(target,key,selected,a.output/f"batch-{batch}")
            all_results.extend(results)
            if any(r["status"] in ("rate_limited","cloud_access_denied","unknown_error") for r in results):
                break
        expected=len(rows) if a.batch in ("all","resume") else 3
        write(a.output/"summary.json",{"schemaVersion":1,"results":all_results,"requestedCount":expected,
            "complete":len(all_results)==expected,"noPlaceWrites":True})
        return 0 if len(all_results)==expected and all(r["status"] in ("inventory_observed","inventory_truncated") for r in all_results) else 2
    except (WorkspaceError,OSError,ValueError,KeyError) as exc:
        print(f"ERROR: {exc}")
        return 1

if __name__=="__main__":
    raise SystemExit(main())
