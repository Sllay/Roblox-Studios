"""Detached source-only audit. Third-party source is neither executed nor persisted.

Compile in a temporary directory using pinned official luau-compile. Report hashes,
syntax status and bounded heuristic API/dependency observations, not raw source.
A successful syntax check is NOT a security approval.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from collections import Counter
from pathlib import Path
from pipeline import ROOT, call, write, WorkspaceError
from deploy import load_all, resolve

TOKEN = re.compile(r'--\[(=*)\[.*?\]\1\]|--[^\n]*|\[(=*)\[.*?\]\2\]|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[A-Za-z_][A-Za-z_0-9]*|\d+(?:\.\d+)?|[^\s]', re.S)
SAFE_SERVICES={"RunService","CollectionService","Players","ReplicatedStorage","Workspace","TweenService","UserInputService","ContextActionService","Lighting","SoundService","HttpService","DataStoreService","TeleportService","AssetService","InsertService","Debris","ContentProvider","StarterGui","GuiService"}
RISK={"loadstring","getfenv","setfenv","HttpService","RequestAsync","GetAsync","PostAsync","LoadAsset","LoadAssetAsync","InsertService","DataStoreService","TeleportService","MessagingService","FireServer","InvokeServer","FireClient","FireAllClients","OnServerEvent","OnServerInvoke","Destroy","ClearAllChildren"}
VISUAL={"BulkMoveTo","CFrame","PivotTo","GetPivot","RenderStepped","Heartbeat","BindToRenderStep","PreRender","Beam","Trail","ParticleEmitter","Attachment","GlobalWind","GetTagged","GetInstanceAddedSignal","GetInstanceRemovedSignal","GetPartBoundsInRadius","GetPartBoundsInBox","Raycast","Noise","noise","CurrentCamera"}
def tokens(source):
    return [m.group(0) for m in TOKEN.finditer(source) if not m.group(0).startswith("--")]

def summarize(source):
    t=tokens(source)
    counts=Counter(t)
    services=sorted({t[i+2][1:-1] for i in range(len(t)-3) if t[i]=="GetService" and t[i+1]=="(" and t[i+2][0] in ("'",'"') and t[i+2][1:-1] in SAFE_SERVICES})
    req=[]
    for i,v in enumerate(t):
        if v!="require" or i+2>=len(t) or t[i+1]!="(": continue
        depth=1;arg=[]
        for token in t[i+2:i+102]:
            if token=="(":depth+=1
            elif token==")":
                depth-=1
                if depth==0:break
            arg.append(token)
        plain="".join(arg)
        if re.fullmatch(r"\d+",plain):
            req.append({"kind":"numeric_asset","assetId":plain})
        elif re.fullmatch(r"script(?:\.[A-Za-z_][A-Za-z_0-9]*)+",plain):
            req.append({"kind":"script_relative","path":plain})
        elif re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*",plain):
            req.append({"kind":"variable","name":plain})
        else:
            req.append({"kind":"expression_requires_review"})
    return {"services":services,"requires":req,"riskTokens":{v:counts[v] for v in sorted(RISK) if counts[v]},
            "visualTokens":{v:counts[v] for v in sorted(VISUAL) if counts[v]}}

def audit_source(source,compiler):
    digest=base64.b64encode(hashlib.sha256(source.encode("utf-8")).digest()).decode()
    with tempfile.TemporaryDirectory() as d:
        path=Path(d)/"source.luau"
        path.write_text(source,encoding="utf-8")
        proc=subprocess.run([compiler,"--null",str(path)],capture_output=True,timeout=20,check=False)
    return {"sha256":digest,"syntaxPassed":proc.returncode==0,**summarize(source),"importAuthorized":False}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--output",type=Path,default=ROOT/"dist/p4-code-audit")
    a=p.parse_args()
    try:
        compiler=shutil.which("luau-compile")
        if not compiler:raise WorkspaceError("Pinned compiler unavailable")
        games,targets=load_all()
        target=resolve(games,targets,"mapa-principal","main","staging")
        key=os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY")
        if not key:raise WorkspaceError("Missing Open Cloud key")
        root=ROOT/"games/maps/mapa-principal/game/assets/audits"
        evidence=[r for filename in ("p4-intake-43179500783.json","p4-intake-43179707585.json") for r in json.loads((root/filename).read_text())["results"] if r["scripts"]]
        results=[]
        for e in evidence:
            report=call(target,key,"code_source_audit",e["id"])
            if report.get("codeExecuted") is not False or len(report["scripts"])!=e["scripts"]:
                raise WorkspaceError("Source count changed or execution evidence invalid")
            expected=Counter(r["sha256"] for r in e["codeReview"])
            observed=Counter()
            reviewed=[]
            for row in report.pop("scripts"):
                source=row.pop("source")
                details=audit_source(source,compiler)
                observed[details["sha256"]]+=1
                reviewed.append({"name":row["name"],"class":row["class"],"selector":row["selector"],**details})
            if observed!=expected:raise WorkspaceError("Source fingerprints changed; re-inventory")
            result={"id":e["id"],"loadedVersion":report["loadedVersion"],"scripts":reviewed,"sourceHashesMatch":True,"codeExecuted":False,"importAuthorized":False}
            results.append(result)
            write(a.output/f"code-{e['id']}.json",result)
            print("CODE_AUDIT "+json.dumps(result,ensure_ascii=False),flush=True)
        write(a.output/"summary.json",{"schemaVersion":1,"results":results,"noPlaceWrites":True})
        return 0 if all(s["syntaxPassed"] for r in results for s in r["scripts"]) else 2
    except (WorkspaceError,OSError,ValueError,KeyError,subprocess.TimeoutExpired) as exc:
        # Do not echo external source or compiler diagnostics.
        print("Code audit stopped:",type(exc).__name__,flush=True)
        return 1

if __name__=="__main__":
    raise SystemExit(main())
