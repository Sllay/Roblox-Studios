"""Validate immutable approved GLB candidates before asset pipeline intake."""
import hashlib,json,struct,sys
from pathlib import Path
root=Path(__file__).resolve().parent/"approved"
manifest=json.loads((root/"v6-manifest.json").read_text())
for asset in manifest["assets"]:
    p=root/asset["file"]
    if not p.is_file(): raise SystemExit(f"Missing approved binary: {p}")
    data=p.read_bytes()
    assert hashlib.sha256(data).hexdigest()==asset["sha256"],p
    magic,version,size=struct.unpack_from("<4sII",data)
    assert (magic,version,size)==(b"glTF",2,len(data)),p
    n,kind=struct.unpack_from("<I4s",data,12)
    assert kind==b"JSON"
    doc=json.loads(data[20:20+n])
    mats=doc["materials"]
    tint=[i for i,m in enumerate(mats) if m.get("name")==asset["tintMaterial"]]
    assert len(tint)==1,(p,"tint material")
    count=0; used=set()
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            assert prim.get("mode",4)==4
            assert "TEXCOORD_0" in prim["attributes"]
            count+=doc["accessors"][prim["indices"]]["count"]//3
            used.add(prim["material"])
    assert count==asset["triangles"],(p,count)
    assert tint[0] in used and len(used)>1,(p,"material separation")
    for i in used:
        tex=mats[i]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
        im=doc["images"][doc["textures"][tex]["source"]]
        assert "bufferView" in im,(p,"texture not embedded")
    print(f"PASS {p.name}: {count} triangles, embedded textures, separate tint")
