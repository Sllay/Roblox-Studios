"""Verify and import the approved Rabbit V1 concept bundle. No Roblox writes."""
import hashlib, json, pathlib, zipfile
from PIL import Image
from io import BytesIO

ROOT=pathlib.Path(__file__).resolve().parents[2]
DIR=ROOT/"asset-library/references/rabbit-v1"
manifest=json.loads((DIR/"manifest.json").read_text())
expected={v["path"]:v for v in manifest["references"].values()}
assert set(expected)=={"hero.png","views.png"}
with zipfile.ZipFile(DIR/"concepts.zip") as archive:
    prefix="asset-library/references/rabbit-v1/"
    names=archive.namelist()
    assert set(names)=={prefix+n for n in expected} and len(names)==len(expected), names
    data={}
    for name,record in expected.items():
        raw=archive.read(prefix+name)
        assert hashlib.sha256(raw).hexdigest()==record["sha256"], name+" hash mismatch"
        with Image.open(BytesIO(raw)) as im:
            assert im.format=="PNG" and list(im.size)==record["size"], name+" wrong format/size"
            assert "A" in im.getbands() and im.getchannel("A").getextrema()[0]==0, name+" alpha missing"
            im.load()
        dest=DIR/name
        assert not dest.exists() or dest.read_bytes()==raw, name+" existing file differs"
        data[name]=raw
    for name,raw in data.items():
        (DIR/name).write_bytes(raw)
manifest["status"]="approved-design-references-verified"
(DIR/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("Rabbit V1: both original PNGs verified against approved SHA-256.")
