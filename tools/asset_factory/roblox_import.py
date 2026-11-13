"""Prepare verified GLB for Open Cloud; no place mutation."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument("release",type=Path);p.add_argument("--publish",action="store_true");p.add_argument("--receipt",type=Path,required=True)
a=p.parse_args()
root=Path(__file__).resolve().parents[2]/"asset-library/approved"
r=a.release.resolve()
if not r.is_relative_to(root.resolve()): p.error("Approved release required")
m=json.loads((r/"release-manifest.json").read_text())
if m.get("status")!="approved" or not m.get("approval"): p.error("Approval required")
models=[e for e in m["files"] if e["path"].endswith(".glb")]
if len(models)!=1: p.error("Exactly one GLB required")
e=models[0];f=(r/e["path"]).resolve()
if not f.is_relative_to(r): p.error("Unsafe path")
b=f.read_bytes()
if hashlib.sha256(b).hexdigest()!=e["sha256"] or len(b)!=e["bytes"] or len(b)>20_000_000 or b[:4]!=b"glTF": p.error("Invalid GLB")
if not a.publish:
    print("Preflight PASS",e["sha256"]);raise SystemExit(0)
if a.receipt.exists(): p.error("Existing receipt: reconcile before retry")
key=os.environ["ROBLOX_API_KEY"];owner=os.environ["ROBLOX_CREATOR_ID"];kind=os.environ.get("ROBLOX_CREATOR_KIND","userId")
if kind not in ("userId","groupId") or not owner.isdigit(): p.error("Invalid creator")
req={"assetType":"Model","displayName":r.parent.name+" "+r.name,"description":"Black Islands approved asset","creationContext":{"creator":{kind:owner}}}
a.receipt.parent.mkdir(parents=True,exist_ok=True)
a.receipt.write_text(json.dumps({"state":"submission_started","sha256":e["sha256"]}))
res=subprocess.run(["curl","--silent","--show-error","--fail-with-body","--max-time","120","-H","x-api-key: "+key,"-F","request="+json.dumps(req),"-F","fileContent=@"+str(f)+";type=model/gltf-binary","https://apis.roblox.com/assets/v1/assets"],capture_output=True,text=True)
a.receipt.write_text(json.dumps({"state":"submitted" if res.returncode==0 else "submission_uncertain","sha256":e["sha256"],"response":res.stdout}))
if res.returncode: raise SystemExit("Upload failed; reconcile receipt before retry")
print("Submitted; operation and runtime validation required")
