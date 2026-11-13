"""Prepare a real-model paint candidate without changing its existing UVs.
Extract exact embedded PNG from the approved GLB, remove only its color link
on a disposable copy, then use the production binder with an explicit contract.
"""
import bpy,sys,json,struct,hashlib
from pathlib import Path
src,out=map(Path,sys.argv[sys.argv.index("--")+1:])
out.mkdir(parents=True,exist_ok=False)
raw=src.read_bytes();n,kind=struct.unpack_from("<II",raw,12)
doc=json.loads(raw[20:20+n]);binary=raw[28+n:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src.resolve()))
chosen=None
for o in bpy.context.scene.objects:
    if o.type!="MESH":continue
    for i,s in enumerate(o.material_slots):
        m=s.material
        if not m or not m.use_nodes:continue
        bs=[x for x in m.node_tree.nodes if x.type=="BSDF_PRINCIPLED"]
        if len(bs)!=1:continue
        links=bs[0].inputs["Base Color"].links
        if len(links)!=1 or links[0].from_node.type!="TEX_IMAGE":continue
        im=links[0].from_node.image
        if not im or not im.packed_file:continue
        data=bytes(im.packed_file.data)
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):continue
        if not any(binary[v.get("byteOffset",0):v.get("byteOffset",0)+v["byteLength"]]==data for v in [doc["bufferViews"][x["bufferView"]] for x in doc.get("images",[]) if "bufferView" in x]):continue
        chosen=(o,i,m,bs[0],data);break
    if chosen:break
assert chosen,"No exact embedded PNG color texture"
o,i,m,bs,data=chosen
assert o.data.uv_layers.active
o.data=o.data.copy();m=m.copy();o.material_slots[i].material=m
bs=next(x for x in m.node_tree.nodes if x.type=="BSDF_PRINCIPLED")
for l in list(bs.inputs["Base Color"].links):m.node_tree.links.remove(l)
(out/"color.png").write_bytes(data)
bpy.ops.export_scene.gltf(filepath=str(out/"unpainted.glb"),export_format="GLB")
name=o.name
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out/"unpainted.glb"))
o=bpy.data.objects[name];uv=o.data.uv_layers.active
h=hashlib.sha256()
for p in o.data.polygons:
    if p.material_index==i:
        h.update(struct.pack("<I",len(p.loop_indices)))
        for j in p.loop_indices:h.update(struct.pack("<Iff",o.data.loops[j].vertex_index,*uv.data[j].uv))
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
(out/"contract.json").write_text(json.dumps({"schema":1,"modelSha256":digest(out/"unpainted.glb"),"pngSha256":digest(out/"color.png"),"object":o.name,"materialSlot":i,"material":o.material_slots[i].material.name,"uv":uv.name,"uvSha256":h.hexdigest()},indent=2))
(out/"provenance.json").write_text(json.dumps({"sourceSha256":digest(src),"scope":"existing UV exact original PNG roundtrip; not new atlas or new art"},indent=2))
