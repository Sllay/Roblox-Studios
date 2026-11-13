import bpy,sys,json
from pathlib import Path
import numpy as np
from PIL import Image
sys.path.insert(0,str(Path(__file__).parent))
from references import load_views
from multiview import reconstruct,projections,iou,surface
from mathutils import Vector
out=Path(sys.argv[sys.argv.index("--")+1]);out.mkdir(parents=True,exist_ok=True)
# Rendered color fixture: a curved handle and asymmetric stone head.
# Reuse the independently authored P1 GLB, not its mesh in reconstruction.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out.parent/"p1-smoke"/"asset.glb"))
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH";scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100
scene.display.shading.color_type="MATERIAL";scene.render.film_transparent=True
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=2.1
center=Vector((.1,0,.7))
views={"front":(0,-4,0),"right":(4,0,0),"top":(0,0,4)}
for k,d in views.items():
    cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/("reference-"+k+".png"));bpy.ops.render.render(write_still=True)
# Camera right view horizontal axis is +Y; top view vertical axis is +Y.
refs={k:out/("reference-"+k+".png") for k in views}
masks,methods=load_views(refs,64)
v=reconstruct(masks);scores={k:iou(m,projections(v)[k]) for k,m in masks.items()}
assert min(scores.values())>=.90,scores
verts,faces=surface(v)
bpy.ops.wm.read_factory_settings(use_empty=True)
mesh=bpy.data.meshes.new("ColorReferenceHull");mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new("ColorReferenceHull",mesh);bpy.context.collection.objects.link(o);o.select_set(True);bpy.context.view_layer.objects.active=o
mod=o.modifiers.new("Planar","DECIMATE");mod.decimate_type="DISSOLVE";mod.angle_limit=.01;bpy.ops.object.modifier_apply(modifier=mod.name)
o.data.calc_loop_triangles();tri=len(o.data.loop_triangles);assert tri>0
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB",use_selection=True)
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH";scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100;scene.render.film_transparent=True
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=2
for k,d in views.items():
    cam.location=Vector(d);cam.rotation_euler=(-cam.location).to_track_quat("-Z","Y").to_euler();scene.render.filepath=str(out/("render-"+k+".png"));bpy.ops.render.render(write_still=True)
render_masks,_=load_views({k:out/("render-"+k+".png") for k in views},64)
render_scores={k:iou(m,render_masks[k]) for k,m in masks.items()}
assert min(render_scores.values())>=.85,render_scores
bpy.ops.wm.save_as_mainfile(filepath=str(out/"asset.blend"))
report={"input":"color renders of independently authored P1 asset","methods":methods,"silhouetteIoU":scores,"renderIoU":render_scores,"triangles":tri,"meshObjects":1,"published":False}
(out/"report.json").write_text(json.dumps(report,indent=2));print("P2_COLOR "+json.dumps(report),flush=True)
