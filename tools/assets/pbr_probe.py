"""Internal read-only diagnostic. Binary stays in process memory; no asset export."""
import base64
import json
import os
from pathlib import Path
from pipeline import ROOT,build_source,WorkspaceError
from cloud_tasks import run_task
from deploy import load_all,resolve
from scene_snapshot import canonical
def main():
    games,targets=load_all()
    t=resolve(games,targets,"mapa-principal","main","staging")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    selector=json.loads((ROOT/"games/maps/mapa-principal/docs/tree-01-selector.json").read_text())
    config=canonical(dict(universeId=t["universeId"],placeId=t["placeId"],assetId="79689531752352",selector=selector))
    source=Path(__file__).with_suffix(".luau").read_text().replace("__RS_CONFIG__","[==["+config+"]==]")
    report=run_task(t["universeId"],t["placeId"],key,source)
    blob=base64.b64decode(report.pop("serializedBase64"),validate=True)
    print("PROBE",json.dumps(report,ensure_ascii=False),flush=True)
    # Inspect header/chunk names only for format compatibility. Never log model bytes.
    print("RBXM_HEADER",blob[:8].hex(),"length",len(blob),flush=True)
    # temporary file used exclusively by parser, not uploaded
    import tempfile,subprocess
    with tempfile.TemporaryDirectory() as d:
        p=Path(d)/"model.rbxm";p.write_bytes(blob)
        subprocess.run(["cargo","run","--quiet","--manifest-path",str(ROOT/"tools/assets/rbx-audit/Cargo.toml"),"--",str(p)],check=True)
if __name__=="__main__":main()
