import argparse,json,subprocess,hashlib,shutil
from pathlib import Path
from job import load
def main():
    p=argparse.ArgumentParser();p.add_argument("--job",type=Path,required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    d,h=load(a.job);a.out.mkdir(parents=True,exist_ok=True)
    def checkpoint(state): (a.out/"checkpoint.json").write_text(json.dumps({"job":d,"referenceHashes":h,"state":state},indent=2))
    checkpoint("validated")
    if d["id"]!="p1-smoke" or d["mode"]!="text": raise SystemExit("P1 only supports the checked-in authored smoke; reference authoring backend pending")
    blender=shutil.which("blender")
    if not blender:raise SystemExit("Blender unavailable")
    checkpoint("running")
    try:
        subprocess.run([blender,"-b","--factory-startup","--python-exit-code","1","--python",str(Path(__file__).with_name("blender_smoke.py")),"--",str(a.out.resolve())],check=True,timeout=600)
        names=["asset.glb","asset.blend","report.json"]+[v+".png" for v in ("front","back","left","right","top","bottom")]
        assert all((a.out/n).stat().st_size>0 for n in names)
        r=json.loads((a.out/"report.json").read_text());assert r["triangles"]<=d["triangle_budget"] and r["uv"]
        (a.out/"manifest.json").write_text(json.dumps({n:hashlib.sha256((a.out/n).read_bytes()).hexdigest() for n in names},indent=2))
        checkpoint("review_ready")
    except Exception:
        checkpoint("failed");raise
if __name__=="__main__":main()
