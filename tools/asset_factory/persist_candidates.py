"""Archive completed cloud outputs before artistic approval."""
import hashlib,json,os,shutil,sys
from pathlib import Path
src=Path(sys.argv[1]); dst=Path(sys.argv[2])
if dst.exists(): raise SystemExit("Candidate revision already exists")
dst.mkdir(parents=True)
files=[]
for p in sorted(src.rglob("*")):
    if not p.is_file(): continue
    if p.is_symlink(): raise ValueError("symlink")
    rel=p.relative_to(src)
    q=dst/rel;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
    files.append({"path":rel.as_posix(),"bytes":q.stat().st_size,"sha256":hashlib.sha256(q.read_bytes()).hexdigest()})
if not any(x["path"].endswith(".glb") for x in files): raise ValueError("No model")
(dst/"candidate-manifest.json").write_text(json.dumps({"schema":1,"status":"candidate","sourceCommit":os.environ.get("GITHUB_SHA"),"runId":os.environ.get("GITHUB_RUN_ID"),"files":files},indent=2))
print("Persisted",len(files),"files")
