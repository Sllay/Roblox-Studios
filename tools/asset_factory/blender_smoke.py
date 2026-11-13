"""P1 authored geometry smoke, not an automatic image reconstruction engine."""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
out=Path(sys.argv[sys.argv.index("--")+1]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);return m
wood=mat("Wood",(.36,.19,.075));stone=mat("Stone",(.32,.39,.36))
def mesh(name,verts,faces,material):
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);o.data.materials.append(material);return o
# Tapered curved handle with closed rings.
verts=[];faces=[];n=12
for z,x,r in [(0,0,.085),(.35,.025,.075),(.9,.06,.09),(1.35,.03,.11)]:
    verts.extend([(x+r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for i in range(n)])
for j in range(3):
    for i in range(n): faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
faces.extend([tuple(reversed(range(n))),tuple(range(3*n,4*n))])
handle=mesh("Handle",verts,faces,wood)
# Beveled stone head, closed mesh with deliberately asymmetric silhouette.
bpy.ops.mesh.primitive_cube_add(size=1,location=(.22,0,1.25))
head=bpy.context.object;head.name="StoneHead";head.scale=(.65,.25,.36);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
head.data.materials.append(stone);b=head.modifiers.new("Rounded edge","BEVEL");b.width=.07;b.segments=2
bpy.ops.object.modifier_apply(modifier=b.name)
for o in [handle,head]:
    bpy.ops.object.select_all(action="DESELECT");o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT");bpy.ops.uv.smart_project();bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.select_all(action="DESELECT")
for o in [handle,head]:o.select_set(True)
bpy.context.view_layer.objects.active=handle
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB",use_selection=True)
scene=bpy.context.scene
scene.render.engine="BLENDER_WORKBENCH";scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100
scene.display.shading.color_type="MATERIAL";scene.display.shading.light="STUDIO";scene.display.shading.show_shadows=True
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=2.1
for name,d in {"front":(0,-4,0),"back":(0,4,0),"left":(-4,0,0),"right":(4,0,0),"top":(0,0,4),"bottom":(0,0,-4)}.items():
    center=Vector((.1,0,.7));cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"asset.blend"))
tri=0
for o in [handle,head]:o.data.calc_loop_triangles();tri+=len(o.data.loop_triangles)
assert 0<tri<=1200
(out/"report.json").write_text(json.dumps({"triangles":tri,"meshObjects":2,"views":6,"uv":all(o.data.uv_layers for o in [handle,head]),"published":False,"mode":"authored_smoke","blender":bpy.app.version_string},indent=2))
