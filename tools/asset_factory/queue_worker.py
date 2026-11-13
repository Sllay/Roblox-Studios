"""Drain immutable queued requests; supported backends only."""
import hashlib,json,os,re,subprocess,sys,tempfile
from pathlib import Path
from job import load
root=Path(__file__).resolve().parents[2]
factory=root/"tools/asset_factory"
library=root/"asset-library"
queue=library/"queue"
backends={"axe":"p2_tint_probe.py","pickaxe":"p2_pickaxe_probe.py","sword":"p2_sword_probe.py"}
def save(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,indent=2)+"\n")
def commit(paths,message):
    subprocess.run(["git","add",*map(str,paths)],cwd=root,check=True)
    subprocess.run(["git","commit","-m",message],cwd=root,check=True)
    for attempt in range(3):
        subprocess.run(["git","fetch","origin","main"],cwd=root,check=True)
        subprocess.run(["git","rebase","origin/main"],cwd=root,check=True)
        if subprocess.run(["git","push","origin","HEAD:main"],cwd=root).returncode==0: return
    raise RuntimeError("Concurrent repository update; retry queue")
for request in sorted(queue.glob("*.json")):
    key=request.stem
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}",key): continue
    status=library/"status"/(key+".json")
    if status.exists() and json.loads(status.read_text())["state"] in ("review_ready","failed"): continue
    digest=hashlib.sha256(request.read_bytes()).hexdigest()
    record={"id":key,"requestSha256":digest,"runId":os.environ.get("GITHUB_RUN_ID"),"state":"running"}
    save(status,record);commit([status],"assets: start "+key)
    try:
        d=json.loads(request.read_text())
        if d.get("schema")!=1 or d.get("backend") not in backends: raise ValueError("Unsupported backend; arbitrary text/image generation not implemented")
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/"output";out.mkdir()
            if d["backend"] in ("axe","pickaxe"):
                dep=Path(tmp)/"p2-handle";dep.mkdir()
                subprocess.run(["blender","-b","--factory-startup","--python-exit-code","1","--python",str(factory/"p2_handle_probe.py"),"--",str(dep)],check=True,timeout=600)
            subprocess.run(["blender","-b","--factory-startup","--python-exit-code","1","--python",str(factory/backends[d["backend"]]),"--",str(out)],check=True,timeout=600)
            dest=library/"candidates"/key
            subprocess.run([sys.executable,str(factory/"persist_candidates.py"),str(out),str(dest)],check=True)
        record.update(state="review_ready",candidate=key)
        save(status,record);commit([status,dest],"assets: candidate "+key)
    except Exception as e:
        record.update(state="failed",error=str(e));save(status,record)
        commit([status],"assets: failed "+key)
        raise
