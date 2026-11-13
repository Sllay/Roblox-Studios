"""Bind exact PNG artwork to an explicit existing UV layout; candidate only."""
import bpy, sys, json, hashlib, struct
from pathlib import Path
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def require(ok,msg):
    if not ok: raise ValueError(msg)
src,png,contract,out=map(Path,sys.argv[sys.argv.index("--")+1:])
spec=json.loads(contract.read_text())
require(spec.get("schema")==1,"Unsupported contract")
require(digest(src)==spec["modelSha256"],"Model hash mismatch")
require(digest(png)==spec["pngSha256"],"PNG hash mismatch")
require(not out.exists(),"Output must be new")
require(png.read_bytes()[:8]==b"\x89PNG\r\n\x1a\n","Expected PNG")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src.resolve()))
obj=bpy.data.objects.get(spec["object"])
require(obj is not None and obj.type=="MESH","Missing mesh")
idx=spec["materialSlot"]
require(type(idx)==int and 0<=idx<len(obj.material_slots),"Invalid material slot")
mat=obj.material_slots[idx].material
require(mat is not None and mat.name==spec["material"],"Material mismatch")
uv=obj.data.uv_layers.get(spec["uv"])
require(uv is not None,"Missing UV")
require(any(p.material_index==idx for p in obj.data.polygons),"Unused material slot")
h=hashlib.sha256()
for p in obj.data.polygons:
    if p.material_index==idx:
        h.update(struct.pack("<I",len(p.loop_indices)))
        for i in p.loop_indices:
            h.update(struct.pack("<Iff",obj.data.loops[i].vertex_index,*uv.data[i].uv))
require(h.hexdigest()==spec["uvSha256"],"Artwork UV layout mismatch")
# Copy material and mesh to avoid changing other users of shared data.
obj.data=obj.data.copy()
mat=mat.copy();obj.material_slots[idx].material=mat
mat.use_nodes=True
nodes=mat.node_tree.nodes;links=mat.node_tree.links
bsdfs=[n for n in nodes if n.type=="BSDF_PRINCIPLED"]
require(len(bsdfs)==1,"Expected one Principled BSDF")
bsdf=bsdfs[0]
require(not bsdf.inputs["Base Color"].is_linked,"Existing color texture: explicit replacement not supported")
image=bpy.data.images.load(str(png.resolve()),check_existing=False)
require(image.size[0]>0 and image.size[1]>0,"Invalid image")
image.colorspace_settings.name="sRGB"
image.pack()
tex=nodes.new("ShaderNodeTexImage");tex.image=image
coord=nodes.new("ShaderNodeUVMap");coord.uv_map=uv.name
links.new(coord.outputs["UV"],tex.inputs["Vector"])
links.new(tex.outputs["Color"],bsdf.inputs["Base Color"])
out.mkdir(parents=True)
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB")
# Verify the exported GLB embeds the exact original PNG, not a re-encoded substitute.
raw=(out/"asset.glb").read_bytes()
n,kind=struct.unpack_from("<II",raw,12)
require(kind==0x4e4f534a,"Invalid GLB JSON")
doc=json.loads(raw[20:20+n]);pos=20+n
length,kind=struct.unpack_from("<II",raw,pos)
require(kind==0x004e4942,"Missing GLB BIN")
binary=raw[pos+8:pos+8+length]
matches=[]
for im in doc.get("images",[]):
    if "bufferView" in im:
        v=doc["bufferViews"][im["bufferView"]];start=v.get("byteOffset",0)
        if hashlib.sha256(binary[start:start+v["byteLength"]]).hexdigest()==spec["pngSha256"]: matches.append(im)
require(bool(matches),"Export did not preserve exact PNG bytes")
(out/"paint-report.json").write_text(json.dumps({"status":"candidate","contract":spec,"outputSha256":digest(out/"asset.glb"),"exactPngEmbedded":True},indent=2))
