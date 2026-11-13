import bpy,sys,json
from pathlib import Path
import numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent))
from references import load_views,read_reference
from multiview import reconstruct,surface,iou
from smooth_hull import continuous_surface
out=Path(sys.argv[sys.argv.index("--")+1]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out.parent/"p1-smoke"/"asset.glb"))
original=[o for o in bpy.context.scene.objects if o.type=="MESH"]
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH";scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.render.film_transparent=True
scene.display.shading.color_type="MATERIAL"
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO"
center=Vector((.1,0,.7));scale=2.1
views={"front":(0,-4,0),"right":(4,0,0),"top":(0,0,4),"quarter":(3,-4,2),"rear":(-3,4,2)}
def render(label,objects,origin,scale):
    for o in scene.objects:
        if o.type=="MESH":o.hide_render=o not in objects
    cam.data.ortho_scale=scale
    for k,d in views.items():
        cam.location=origin+Vector(d);cam.rotation_euler=(0,0,0) if k=="top" else (origin-cam.location).to_track_quat("-Z","Y").to_euler()
        scene.render.filepath=str(out/(label+"-"+k+".png"));bpy.ops.render.render(write_still=True)
    return {k:read_reference(out/(label+"-"+k+".png"),192)[0] for k in views}
ref=render("original",original,center,scale)
masks={k:ref[k] for k in ("front","right","top")}
def make(name,geometry):
    v,f=geometry;m=bpy.data.meshes.new(name);m.from_pydata(v,[],f);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);return o
# Compare old 64-cell hull to continuous 192-cell reconstruction.
oldm,_=load_views({k:out/("original-"+k+".png") for k in masks},64)
old=make("Voxel",surface(reconstruct(oldm)))
new=make("Continuous",continuous_surface(masks))
bpy.ops.object.select_all(action="DESELECT");new.select_set(True);bpy.context.view_layer.objects.active=new
mod=new.modifiers.new("Reduce","DECIMATE");new.data.calc_loop_triangles();mod.ratio=min(1,1100/len(new.data.loop_triangles));bpy.ops.object.modifier_apply(modifier=mod.name)
for p in new.data.polygons:p.use_smooth=True
base=render("voxel",[old],Vector((0,0,0)),2)
result=render("smooth",[new],Vector((0,0,0)),2)
scores={k:iou(ref[k],result[k]) for k in views};baseline={k:iou(ref[k],base[k]) for k in views}
new.data.calc_loop_triangles();tri=len(new.data.loop_triangles)
report={"baseline":baseline,"smooth":scores,"triangles":tri,"resolution":192}
print("P2_SMOOTH "+json.dumps(report),flush=True);(out/"report.json").write_text(json.dumps(report,indent=2))
assert min(scores[k] for k in masks)>=.90
assert sum(scores[k] for k in ("quarter","rear"))>=sum(baseline[k] for k in ("quarter","rear"))
assert 0<tri<=1200
bpy.ops.object.select_all(action="DESELECT");new.select_set(True);bpy.context.view_layer.objects.active=new
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB",use_selection=True)
