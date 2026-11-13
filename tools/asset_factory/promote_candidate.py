"""Promote an explicitly reviewed candidate bundle without altering source bytes."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument("--candidate",required=True)
p.add_argument("--asset",required=True)
p.add_argument("--revision",required=True)
p.add_argument("--approval",required=True)
p.add_argument("--file",action="append",required=True)
a=p.parse_args()
for v in (a.candidate,a.asset,a.revision):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}",v): p.error("Invalid identifier")
if not a.approval.strip(): p.error("Explicit approval reference required")
root=Path(__file__).resolve().parents[2]/"asset-library"
src=root/"candidates"/a.candidate
dst=root/"approved"/a.asset/a.revision
if dst.exists(): p.error("Immutable release already exists")
m=json.loads((src/"candidate-manifest.json").read_text())
entries={x["path"]:x for x in m["files"]}
selected=[]
for name in dict.fromkeys(a.file):
    if name not in entries: p.error("Not in candidate manifest: "+name)
    q=src/name
    if not q.resolve().is_relative_to(src.resolve()) or q.is_symlink(): p.error("Unsafe path")
    data=q.read_bytes(); e=entries[name]
    if len(data)!=e["bytes"] or hashlib.sha256(data).hexdigest()!=e["sha256"]: p.error("Hash mismatch: "+name)
    selected.append(e)
if not any(e["path"].endswith(".glb") for e in selected): p.error("GLB required")
# This command records review evidence; it does not substitute for technical UV validation.
dst.mkdir(parents=True)
for e in selected:
    q=dst/e["path"];q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src/e["path"],q)
(dst/"release-manifest.json").write_text(json.dumps({"schema":1,"status":"approved","candidate":a.candidate,"sourceCommit":m.get("sourceCommit"),"approval":a.approval,"files":selected},indent=2))
print(dst)
