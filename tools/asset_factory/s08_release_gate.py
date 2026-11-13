"""Read-only S08 release gate: verify files, receipts, native proof and candidate registry.
No upload, no credentials and no Place mutations.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "asset-library/approved"
REC = ROOT / "asset-library/roblox-receipts"
REG = ROOT / "games/maps/mapa-principal/game/assets/prop-registry-s08-candidates.json"

def read(p):
    return json.loads(p.read_text())

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def receipt(name, aid, path):
    r = read(REC / "s08-props" / (name + ".json"))
    assert r["state"] == "created" and r["assetId"] == aid and r["noPlaceWrites"]
    assert r["sha256"] == digest(path) and r["bytes"] == path.stat().st_size
    assert r["source"] == str(path.relative_to(ROOT))
    return r

def validate():
    reg = read(REG)
    assert reg["status"] == "candidate-only" and not reg["writeAuthorized"]
    proof = read(REC / "s08-runtime-proof.json")
    tree = read(REC / "s08-eggydrasil-pbr-proof.json")
    for p in (proof, tree):
        assert p["noPlaceWrites"] and p["placeId"] == reg["target"]["placeId"]
        assert p["universeId"] == reg["target"]["universeId"]
    rows = {p["id"]:p for p in reg["props"]}
    assert len(reg["props"]) == len(rows) == 4
    assert set(rows) == {"Stone", "Branch", "Log", "Eggydrasil"}
    for name, key in (("stone","Stone"),("stick","Branch"),("log","Log")):
        r = rows[key]
        folder = APP / name / "v1"
        m = read(folder / "runtime/manifest.json")
        assert r["state"] == "native-verified"
        assert m["geometryUnchanged"] and m["meshes"] == m["materials"] == r["parts"] == 1
        assert m["triangles"] == r["triangles"] and m["uv"] == "TEXCOORD_0"
        assert m["sourceSha256"] == digest(folder / "asset.glb")
        assert m["sha256"] == digest(folder / "runtime/asset.glb")
        assert m["atlasSha256"] == digest(folder / "atlas.png")
        receipt(name+"-v1-runtime",r["assetId"],folder/"runtime/asset.glb")
        receipt(name+"-v1-atlas",r["atlasId"],folder/"atlas.png")
        q = proof["props"][name]
        assert q["assetId"] == r["assetId"] and q["atlasId"] == r["atlasId"]
        assert q["meshId"] == "rbxassetid://"+r["meshId"] and q["parts"] == 1 and q["scripts"] == 0
        assert q["meshLoaded"] and q["imageLoaded"] and q["textureBound"]
    r = rows["Eggydrasil"]
    folder = APP / "eggydrasil/v8"
    native = read(folder / "native/manifest.json")
    receipt("eggydrasil-v8-pbr",r["assetId"],folder/"native/eggydrasil-v8-pbr.rbxm")
    assert native["sha256"] == digest(folder/"native/eggydrasil-v8-pbr.rbxm")
    assert native["nativeRoundTrip"] and native["noPlaceWrites"] and tree["assetId"] == r["assetId"]
    assert native["proof"] == tree["proof"]
    assert tree["proof"]["meshCount"] == r["parts"] == 5
    for k,v in r["foliage"].items():
        assert tree["proof"][k] == v
    for color in ("white","gray"):
        receipt("eggydrasil-"+color,r["foliage"][color+"Uri"].split("://")[1],folder/("leaves-"+color+".png"))
    assert r["count"] == 1 and rows["Stone"]["count"] == rows["Branch"]["count"] == 1000
    assert rows["Log"]["count"] is None
    assert not reg["clientRenderVerified"]
    return {"assets":4,"nativeVerified":True,"mapWriteAuthorized":False,"clientRenderVerified":False,"loadedProofVersion":proof["loadedVersion"]}

if __name__ == "__main__":
    print(json.dumps(validate(),indent=2))
