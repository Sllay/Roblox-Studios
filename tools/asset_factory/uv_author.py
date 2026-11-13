"""Blender entrypoint: unwrap NEW unpainted meshes; never overwrite approved assets."""
import bpy,sys,json,math
from pathlib import Path
args=sys.argv[sys.argv.index("--")+1:]
src,out=map(Path,args)
if out.exists(): raise ValueError("Output must be new")
out.mkdir(parents=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src.resolve()))
report=[]
objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
if not objects: raise ValueError("No mesh objects")
# Never unwrap an already painted mesh: changing its UVs destroys artwork alignment.
for obj in objects:
    for mat in obj.data.materials:
        if mat and mat.use_nodes and any(n.type=="TEX_IMAGE" and n.image for n in mat.node_tree.nodes):
            raise ValueError(f"{obj.name}: textured input requires UV preservation")
    if obj.data.users>1: obj.data=obj.data.copy()
for obj in objects:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True);bpy.context.view_layer.objects.active=obj
    mesh=obj.data
    # Use connected smooth regions, split sharp edges and material boundaries.
    import bmesh
    bm=bmesh.new();bm.from_mesh(mesh)
    for e in bm.edges:
        e.seam=not e.is_manifold or e.calc_face_angle(0)>math.radians(55) or len({f.material_index for f in e.link_faces})>1
    bm.to_mesh(mesh);bm.free()
    bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED",margin=0.02)
    bpy.ops.uv.average_islands_scale();bpy.ops.uv.pack_islands(margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
# Pack all objects together into one atlas, including shared material users.
bpy.ops.object.select_all(action="DESELECT")
for obj in objects: obj.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.average_islands_scale()
bpy.ops.uv.pack_islands(margin=0.02)
bpy.ops.object.mode_set(mode="OBJECT")
for obj in objects:
    mesh=obj.data
    uv=mesh.uv_layers.active.data
    bad=sum(1 for p in mesh.polygons if abs(sum(uv[i].uv.x*uv[j].uv.y-uv[j].uv.x*uv[i].uv.y for i,j in zip(p.loop_indices,list(p.loop_indices)[1:]+[p.loop_indices[0]])))<1e-10)
    if bad: raise ValueError(f"{obj.name}: degenerate UV faces {bad}")
    report.append({"object":obj.name,"faces":len(mesh.polygons),"degenerate":bad})
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB")
(out/"uv-report.json").write_text(json.dumps({"status":"candidate","objects":report,"limitations":"Shared atlas packed across all mesh objects; overlap and distortion require independent validation"},indent=2))
