"""Drain immutable queued requests; supported backends only."""
import hashlib,json,os,re,subprocess,sys,tempfile
from pathlib import Path
from job import load
root=Path(__file__).resolve().parents[2]
factory=root/"tools/asset_factory"
library=root/"asset-library"
queue=library/"queue"
backends={"axe":"p2_tint_probe.py","pickaxe":"p2_pickaxe_probe.py","sword":"p2_sword_probe.py","axe-paint-roundtrip":"real_paint_probe.py","axe-atlas-bake":"atlas_bake_organized.py","atlas-bake":"atlas_bake_organized.py"}
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
                # Reuse the immutable, validated geometry fixture from the successful S08 run.
                source=library/"candidates"/"43368150648-1"/"p2-budget"/"direct-200.glb"
                payload=source.read_bytes()
                if hashlib.sha256(payload).hexdigest()!="c765aef2eb5ddfacb8d73911a3601c4b9c4e3e76d89cc83bbf75bbd2e4b83cc1":
                    raise ValueError("Handle source fixture hash mismatch")
                budget=Path(tmp)/"p2-budget";budget.mkdir()
                (budget/"direct-200.glb").write_bytes(payload)
                dep=Path(tmp)/"p2-handle";dep.mkdir()
                subprocess.run(["blender","-b","--factory-startup","--python-exit-code","1","--python",str(factory/"p2_handle_probe.py"),"--",str(dep)],check=True,timeout=600)
            if d["backend"]=="axe-paint-roundtrip":
                source=library/"approved"/"axe"/"v6"/"machado-v6.glb"
                if hashlib.sha256(source.read_bytes()).hexdigest()!="6089929739d0a08983faa5d5f7ecaf26d6e42896880cd98a2c7aa2be470a7507": raise ValueError("Approved source hash mismatch")
                def blender(script,*args):
                    subprocess.run(["blender","-b","--factory-startup","--python-exit-code","1","--python",str(factory/script),"--",*map(str,args)],check=True,timeout=900)
                prep=out/"prep"
                blender("real_paint_probe.py",source,prep)
                blender("bind_paint.py",prep/"unpainted.glb",prep/"color.png",prep/"contract.json",out/"painted")
                blender("uv_audit.py",out/"painted"/"asset.glb",out/"legacy-uv-audit.json")
            elif d["backend"] in ("axe-atlas-bake","atlas-bake"):
                source=library/"approved"/"axe"/"v6"/"machado-v6.glb"
                if hashlib.sha256(source.read_bytes()).hexdigest()!="6089929739d0a08983faa5d5f7ecaf26d6e42896880cd98a2c7aa2be470a7507": raise ValueError("Approved source hash mismatch")
                if d["backend"]=="atlas-bake":
                    source=(root/d["source"]).resolve()
                    if not source.is_relative_to((library/"approved").resolve()) or source.suffix.lower()!=".glb":raise ValueError("Source must be an approved GLB")
                    if hashlib.sha256(source.read_bytes()).hexdigest()!=d["sourceSha256"]:raise ValueError("Source hash mismatch")
                def blender(script,*args):
                    subprocess.run(["blender","-b","--factory-startup","--python-exit-code","1","--python",str(factory/script),"--",*map(str,args)],check=True,timeout=1200)
                baked=out/"baked"
                blender("atlas_bake_organized.py",source,baked)
                blender("uv_audit.py",baked/"asset.glb",baked/"audit.json","--shared","--uv-index","1")
                blender("uv_islands.py",baked/"asset.glb",baked)
                blender("visual_paint_probe.py",source,out/"reference")
                blender("visual_paint_probe.py",baked/"asset.glb",out/"review")
                subprocess.run([sys.executable,str(factory/"compare_paint.py"),str(out/"reference"),str(out/"review"),str(baked/"visual-fidelity.json")],check=True)
            else:
                subprocess.run(["blender","-b","--factory-startup","--python-exit-code","1","--python",str(factory/backends[d["backend"]]),"--",str(out)],check=True,timeout=600)
            dest=library/"candidates"/key
            subprocess.run([sys.executable,str(factory/"persist_candidates.py"),str(out),str(dest)],check=True)
        record.update(state="review_ready",candidate=key)
        save(status,record);commit([status,dest],"assets: candidate "+key)
    except Exception as e:
        record.update(state="failed",error=str(e));save(status,record)
        commit([status],"assets: failed "+key)
        raise
