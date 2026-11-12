"""Bounded read-only integration test of actual Creator Store decoration candidates."""
from __future__ import annotations
import json
import os
from pathlib import Path
from discover import search_models
from pipeline import call,write,ROOT,WorkspaceError
from deploy import load_all,resolve

def main():
    games,targets=load_all()
    target=resolve(games,targets,"mapa-principal","main","production")
    key=os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY","")
    if not key: raise WorkspaceError("Missing key")
    output=ROOT/"dist"/"asset-pipeline"
    candidates=search_models("low poly tree",6)
    checked=[]
    for item in candidates:
        aid=item["id"]
        try:
            report=call(target,key,"audit",aid)
            write(output/f"audit-{aid}.json",report)
            audit=report["audit"]
            print(f"Candidate {aid} {item['name']!r}: allowed={audit['allowed']}; parts={audit['parts']}; issues={audit['issues']}",flush=True)
            checked.append({"assetId":aid,"name":item["name"],"allowed":audit["allowed"],"issues":audit["issues"]})
            if audit["allowed"]:
                write(output/"sample-summary.json",{"checked":checked,"acceptedAssetId":aid,"note":"Policy-only, not visually approved or imported"})
                return 0
        except WorkspaceError as exc:
            print(f"Candidate {aid} unavailable: {exc}",flush=True)
            checked.append({"assetId":aid,"error":str(exc)})
            if "HTTP 429" in str(exc):
                print("Rate limit reached; stopping without retry",flush=True)
                break
    write(output/"sample-summary.json",{"checked":checked,"acceptedAssetId":None,"note":"No candidate passed strict policy; no import"})
    return 2
if __name__=="__main__":
    raise SystemExit(main())
