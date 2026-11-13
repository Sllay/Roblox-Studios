import bpy,sys,json
from pathlib import Path
import numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent))
from references import load_views
from multiview import reconstruct,projections,surface,iou
from refine import choose
out=Path(sys.argv[sys.argv.index("--")+1]);out.mkdir(parents=True,exist_ok=True)
views={"front":(0,-4,0),"right":(4,0,0),"top":(0,0,4)}
reports={}
for kind in ("organic","hard"):
    folder=out/kind;folder.mkdir(exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if kind=="organic":
        n=48;x,y,z=np.indices((n,n,n));v=((x-23)/15)**2+((y-25)/11)**2+((z-22)/17)**2<=1
        refs=projections(v)
    else:
        refs,_=load_views({k:out.parent/"p2-color"/("reference-"+k+".png") for k in views},64)
    verts,faces=surface(reconstruct(refs))
    m=bpy.data.meshes.new("Hull");m.from_pydata(verts,[],faces);m.update()
    source=bpy.data.objects.new("Hull",m);bpy.context.collection.objects.link(source)
    scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH";scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100;scene.render.film_transparent=True
    bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=2
    def measure(obj,label):
        for o in scene.objects:
            if o.type=="MESH":o.hide_render=o!=obj
        for k,d in views.items():
            cam.location=Vector(d);cam.rotation_euler=(0,0,0) if k=="top" else (-cam.location).to_track_quat("-Z","Y").to_euler()
            scene.render.filepath=str(folder/(label+"-"+k+".png"));bpy.ops.render.render(write_still=True)
        masks,_=load_views({k:folder/(label+"-"+k+".png") for k in views},len(next(iter(refs.values()))))
        return {k:iou(refs[k],masks[k]) for k in views}
    result,report=choose(source,kind,measure)
    assert report["accepted"],report
    if kind=="hard":assert report["after"]["triangles"]<report["before"]["triangles"]
    else:assert abs(report["after"]["area"]-report["before"]["area"])>1e-5
    for o in list(scene.objects):
        if o.type=="MESH" and o!=result:bpy.data.objects.remove(o,do_unlink=True)
    result.hide_render=False;bpy.ops.object.select_all(action="DESELECT");result.select_set(True);bpy.context.view_layer.objects.active=result
    bpy.ops.export_scene.gltf(filepath=str(folder/"asset.glb"),export_format="GLB",use_selection=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/"asset.blend"))
    reports[kind]=report
(out/"report.json").write_text(json.dumps(reports,indent=2));print("P2_REFINE "+json.dumps(reports),flush=True)
