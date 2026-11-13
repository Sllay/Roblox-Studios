"""Export and render a geometry-only candidate; never publish or generate an atlas."""
import bpy,bmesh,sys,json,math
from pathlib import Path
from mathutils import Vector
src,out=map(Path,sys.argv[sys.argv.index("--")+1:]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
v=[];f=[]
for line in src.read_text().splitlines():
    a=line.split()
    if a[0]=='v':v.append(tuple(map(float,a[1:])))
    elif a[0]=='f':f.append(tuple(int(i)-1 for i in a[1:]))
mesh=bpy.data.meshes.new("LayeredHull");mesh.from_pydata(v,[],f);mesh.update()
o=bpy.data.objects.new("EggydrasilV2",mesh);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True)
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
for p in mesh.polygons:p.use_smooth=True
original=len(mesh.polygons)
if original>25000:
    mod=o.modifiers.new("Preview budget","DECIMATE");mod.ratio=24500/original;bpy.ops.object.modifier_apply(modifier=mod.name)
mesh=o.data
# ground at zero, normalize to 64 model units across the original reconstruction cube.
bottom=min(v.co.z for v in mesh.vertices)
for v in mesh.vertices:v.co.z-=bottom;v.co*=32
mesh.update()
m=bpy.data.materials.new("Clay bark preview");m.diffuse_color=(.25,.12,.055,1);m.use_nodes=True;m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=m.diffuse_color
m.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value=.82
mesh.materials.append(m)
bpy.ops.export_scene.gltf(filepath=str(out/"eggydrasil-v2.glb"),export_format="GLB",use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"eggydrasil-v2.blend"))
points=[v.co for v in mesh.vertices];lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(lo+hi)/2;size=max(hi-lo)
scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=48;scene.cycles.use_denoising=False
for layer in scene.view_layers: layer.cycles.use_denoising=False
scene.render.resolution_x=720;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.color_mode="RGBA"
scene.world=bpy.data.worlds.new("Studio");scene.world.use_nodes=True;scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.3,.3,.3,1);scene.world.node_tree.nodes["Background"].inputs[1].default_value=.65
def aim(o):o.rotation_euler=(center-o.location).to_track_quat("-Z","Y").to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=size*1.35;cam.data.clip_end=size*10
for d,power in [((3,-4,5),850),((-3,-1,2),450),((1,4,3),650)]:
    bpy.ops.object.light_add(type="AREA",location=center+Vector(d)*size);l=bpy.context.object;l.data.energy=power*size*size;l.data.size=size*2;aim(l)
for name,d in [("front",(0,-1,0)),("quarter",(1,-1,.35)),("back",(0,1,0))]:
    cam.location=center+Vector(d).normalized()*size*3;aim(cam);scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
(out/"preview-report.json").write_text(json.dumps(dict(sourceTriangles=original,previewTriangles=len(mesh.polygons),dimensions=list(hi-lo),uv=False,published=False),indent=2))
