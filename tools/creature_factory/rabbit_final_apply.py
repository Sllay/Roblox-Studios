"""Apply the single paint atlas to the exact polished mesh and revalidate GLB."""
import bpy,sys,json,struct,hashlib
from pathlib import Path
import numpy as np
out=Path(sys.argv[sys.argv.index("--")+1])
bpy.ops.wm.open_mainfile(filepath=str(out/"polished.blend"))
meta=json.loads((out/"atlas-input.json").read_text());uv=np.load(out/"atlas-output.npz")
im=bpy.data.images.load(str(out/"rabbit_basecolor_4096.png"));im.pack()
mat=bpy.data.materials.new("Rabbit_FinalAtlas_PaintBase");mat.use_nodes=True
bs=mat.node_tree.nodes.get("Principled BSDF");bs.inputs["Roughness"].default_value=.84
tex=mat.node_tree.nodes.new("ShaderNodeTexImage");tex.image=im;tex.label="Replace with final painted albedo (same UV)";mat.node_tree.nodes.active=tex
mat.node_tree.links.new(tex.outputs["Color"],bs.inputs["Base Color"])
objects=[]
for m in meta:
    o=bpy.data.objects[m["name"]];objects.append(o);mesh=o.data
    assert len(mesh.loops)==m["loops"] and len(mesh.vertices)==m["vertices"]
    for layer in list(mesh.uv_layers):mesh.uv_layers.remove(layer)
    layer=mesh.uv_layers.new(name="Rabbit_Atlas");u=uv[f'uv{m["index"]}']
    assert u.shape==(len(mesh.loops),2)
    layer.data.foreach_set("uv",u.ravel())
    mesh.materials.clear();mesh.materials.append(mat)
    for p in mesh.polygons:p.material_index=0
    # Keep the original vertex colors as an editable reference, but do not
    # export them as a second multiplicative color channel.
    for a in list(mesh.color_attributes):mesh.color_attributes.remove(a)
rig=bpy.data.objects["RabbitRig"];scene=bpy.context.scene;scene.display.shading.color_type="TEXTURE"
from mathutils import Vector
center=Vector((0,0,1.8));cam=scene.camera
for n,d in {"atlas-front":(0,-6,0),"atlas-right":(6,0,0),"atlas-three-quarter":(-4,-6,1.3)}.items():
    cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(n+".png"));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="DESELECT");rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(out/"asset.blend"))
for o in objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB",use_selection=True,export_animations=False)
raw=(out/"asset.glb").read_bytes();n,t=struct.unpack_from("<II",raw,12);j=json.loads(raw[20:20+n])
pr=[p for m in j["meshes"] for p in m["primitives"]]
assert all({"TEXCOORD_0","JOINTS_0","WEIGHTS_0"}<=set(p["attributes"]) for p in pr)
assert len(j["images"])==1 and j.get("skins")
assert sum(j["accessors"][p["indices"]]["count"]//3 for p in pr)==sum(m["triangles"] for m in meta)
report=json.loads((out/"polish-report.json").read_text());report["uv"]=json.loads((out/"uv-report.json").read_text())
report.update({"schema":1,"id":"rabbit-final-uv","category":"creature","state":"paint_ready_review","triangles":sum(m["triangles"] for m in meta),"exportedVertices":sum(j["accessors"][p["attributes"]["POSITION"]]["count"] for p in pr),"rigged":True,"atlasImages":1,"artisticApproval":False,"robloxPublished":False,"runtimePackagingRequired":True,"geometryFrozenForPainting":False,"limitations":["UV is a definitive candidate, freeze only after owner approves polished geometry and atlas.","Provisional clean base color is not final artistic texture.","Roblox mesh partitioning and full animation collision checks remain pending."]})
(out/"report.json").write_text(json.dumps(report,indent=2)+"\n");print(json.dumps(report),flush=True)
