import hashlib,json,shutil,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
src=root/"tools/asset_factory/approved"
subprocess.run([sys.executable,str(src.parent/"validate_approved.py")],check=True)
m=json.loads((src/"v6-manifest.json").read_text())
for a,key in zip(m["assets"],["sword","axe","pickaxe"]):
    f=src/a["file"];dst=root/"asset-library/approved"/key/"v6"
    entry={"path":f.name,"sha256":a["sha256"],"bytes":f.stat().st_size}
    manifest={"schema":1,"status":"approved","approval":"User approved V6 artistic assets and supplied A1 archive","technicalValidation":"validate_approved.py","files":[entry]}
    if dst.exists():
        assert json.loads((dst/"release-manifest.json").read_text())==manifest
        assert hashlib.sha256((dst/f.name).read_bytes()).hexdigest()==a["sha256"]
        continue
    dst.mkdir(parents=True);shutil.copy2(f,dst/f.name)
    (dst/"release-manifest.json").write_text(json.dumps(manifest,indent=2))
