import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector
import numpy as np
from scipy.interpolate import PchipInterpolator
sys.path.insert(0,str(Path(__file__).parent))
from references import read_reference
from multiview import iou
out=Path(sys.argv[sys.argv.index("--")+1]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out.parent/"p2-budget"/"direct-200.glb"))
original=[o for o in bpy.context.scene.objects if o.type=="MESH" and "Handle" in o.name]
assert len(original)==1
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH";scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.render.film_transparent=True
scene.display.shading.color_type="MATERIAL"
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=2.1
center=Vector((.1,0,.7))
views={"front":(0,-4,0),"right":(4,0,0),"quarter":(3,-4,2),"rear":(-3,4,2)}
def render(label,objects):
    for o in scene.objects:
        if o.type=="MESH":o.hide_render=o not in objects
    for k,d in views.items():
        cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler();scene.render.filepath=str(out/(label+"-"+k+".png"));bpy.ops.render.render(write_still=True)
    return {k:read_reference(out/(label+"-"+k+".png"),384)[0] for k in views}
ref=render("reference",original)
# Only the two isolated component silhouettes are inputs to the fit.
f,r=ref["front"],ref["right"];rows=np.flatnonzero(f.any(axis=1)&r.any(axis=1));assert len(rows)>20
def spans(mask):
    return np.array([(np.flatnonzero(mask[j])[0],np.flatnonzero(mask[j])[-1]) for j in rows],float)
a,b=spans(f),spans(r);step=2.1/384
z=.7+(191.5-rows)*step
values=np.column_stack((.1+(a.mean(axis=1)-191.5)*step,(b.mean(axis=1)-191.5)*step,(a[:,1]-a[:,0]+1)*step/2,(b[:,1]-b[:,0]+1)*step/2))
# Ignore rasterized end caps for radius estimation; preserve measured height.
from scipy.ndimage import median_filter
values=median_filter(values,size=(5,1))
fit=PchipInterpolator(z[::-1],values[::-1],axis=0)
v=[];faces=[];n=10;rings=9
for j,h in enumerate(np.linspace(z.min(),z.max(),rings)):
    x,y,rx,ry=fit(h)
    for i in range(n):
        t=i*math.tau/n;v.append((x+rx*math.cos(t),y+ry*math.sin(t),h))
for j in range(rings-1):
    for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
faces.extend([tuple(reversed(range(n))),tuple(range((rings-1)*n,rings*n))])
m=bpy.data.meshes.new("RecoveredHandle");m.from_pydata(v,[],faces);m.update();o=bpy.data.objects.new("RecoveredHandle",m);scene.collection.objects.link(o)
mat=bpy.data.materials.new("Wood");mat.diffuse_color=(.36,.19,.075,1);mat.use_nodes=True;mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=mat.diffuse_color;m.materials.append(mat)
for p in m.polygons:p.use_smooth=len(p.vertices)==4
result=render("recovered",[o]);scores={k:iou(ref[k],result[k]) for k in views};m.calc_loop_triangles()
report={"iou":scores,"triangles":len(m.loop_triangles),"input":"isolated front/right masks","heldOut":["quarter","rear"]}
print("P2_HANDLE "+json.dumps(report),flush=True);(out/"report.json").write_text(json.dumps(report,indent=2))
assert min(scores.values())>=.90,report
bpy.ops.object.select_all(action="DESELECT");o.select_set(True);bpy.context.view_layer.objects.active=o
bpy.ops.export_scene.gltf(filepath=str(out/"handle.glb"),export_format="GLB",use_selection=True)
