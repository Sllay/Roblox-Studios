import bpy,sys,json,math
from pathlib import Path
import numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent))
from multiview import reconstruct,projections,iou,surface
out=Path(sys.argv[sys.argv.index("--")+1]);out.mkdir(parents=True,exist_ok=True)
# Independent analytic ellipsoid masks, asymmetric center, common orthographic scale.
n=32
x,y,z=np.indices((n,n,n));truth=((x-14)/10)**2+((y-17)/7)**2+((z-15)/12)**2<=1
refs=projections(truth)
def save_mask(name,mask):
    im=bpy.data.images.new(name,width=n,height=n,alpha=True)
    a=np.ones((n,n,4),dtype=np.float32);a[:,:,:3]=mask[::-1,:,None]
    im.pixels.foreach_set(a.ravel());im.filepath_raw=str(out/(name+".png"));im.file_format="PNG";im.save();bpy.data.images.remove(im)
for k,m in refs.items():save_mask("reference-"+k,m)
loaded={}
for k in refs:
    im=bpy.data.images.load(str(out/("reference-"+k+".png")));a=np.array(im.pixels[:]).reshape(n,n,4);loaded[k]=a[::-1,:,0]>.5;bpy.data.images.remove(im)
v=reconstruct(loaded);scores={k:iou(m,projections(v)[k]) for k,m in loaded.items()}
assert min(scores.values())>=.98
verts,faces=surface(v)
bpy.ops.wm.read_factory_settings(use_empty=True)
mesh=bpy.data.meshes.new("Reconstruction");mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new("Reconstruction",mesh);bpy.context.collection.objects.link(o);o.select_set(True);bpy.context.view_layer.objects.active=o
mesh.calc_loop_triangles();before=len(mesh.loop_triangles)
mod=o.modifiers.new("Planar simplification","DECIMATE");mod.decimate_type="DISSOLVE";mod.angle_limit=.01;bpy.ops.object.modifier_apply(modifier=mod.name)
mesh=o.data;mesh.calc_loop_triangles();tri=len(mesh.loop_triangles);assert 0<tri<=before
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB",use_selection=True)
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH";scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=2
for name,d in {"front":(0,-4,0),"right":(4,0,0),"top":(0,0,4),"back":(0,4,0),"left":(-4,0,0),"bottom":(0,0,-4)}.items():
    cam.location=Vector(d);cam.rotation_euler=(-cam.location).to_track_quat("-Z","Y").to_euler();scene.render.filepath=str(out/("render-"+name+".png"));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"asset.blend"))
report={"input":"three PNG orthographic masks","silhouetteIoU":scores,"volumeIoU":iou(v,truth),"trianglesBefore":before,"triangles":tri,"meshObjects":1,"published":False,"limitations":"synthetic aligned masks; concavities and arbitrary photos not validated"}
(out/"report.json").write_text(json.dumps(report,indent=2));print("P2_REPORT "+json.dumps(report),flush=True)
