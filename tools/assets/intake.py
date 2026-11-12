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

def run_batch(target,key,rows,output,inspect_fn=inspect):
    results=[]
    for row in rows:
        asset_id=row["id"]
        try:
            report=inspect_fn(target,key,asset_id)
            pack=report["pack"]
            write(output/f"pack-{asset_id}.json",report)
            result={"id":asset_id,"status":"inventory_truncated" if pack["inventoryTruncated"] else "inventory_observed",
                    "models":pack["totalModels"],"scripts":pack["scriptsInPack"],"importAuthorized":False}
        except WorkspaceError as exc:
            status,action=classify_failure(exc)
            result={"id":asset_id,"status":status,"diagnostic":str(exc)[:1000],"nextAction":action,"importAuthorized":False}
        results.append(result)
        write(output/"summary.json",{"schemaVersion":1,"requested":[r["id"] for r in rows],
            "results":results,"noPlaceWrites":True,"complete":len(results)==len(rows)})
        if result["status"] in ("rate_limited","cloud_access_denied","unknown_error"):
            break
    return results

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--batch",type=int,required=True,choices=range(1,5))
    p.add_argument("--output",type=Path,default=ROOT/"dist"/"p4-intake")
    a=p.parse_args()
    try:
        rows=load_intake(ROOT/"games/maps/mapa-principal/game/assets/intake-p4.json")
        games,targets=load_all()
        target=resolve(games,targets,"mapa-principal","main","staging")
        key=os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY")
        if not key: raise WorkspaceError("Missing Open Cloud key")
        selected=rows[(a.batch-1)*3:a.batch*3]
        results=run_batch(target,key,selected,a.output/f"batch-{a.batch}")
        print(json.dumps(results,ensure_ascii=False))
        return 0 if len(results)==len(selected) and all(r["status"]=="inventory_observed" for r in results) else 2
    except (WorkspaceError,OSError,ValueError,KeyError) as exc:
        print(f"ERROR: {exc}")
        return 1

if __name__=="__main__":
    raise SystemExit(main())
