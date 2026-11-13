"""Real asset visual roundtrip: original, unpainted, UV checker, restored.
Uses original embedded artwork and UVs; not a new artistic reconstruction.
"""
import bpy,sys,json,hashlib,struct,math
from pathlib import Path
from mathutils import Vector
src,out=map(Path,sys.argv[sys.argv.index("--")+1:])
out.mkdir(parents=True,exist_ok=False)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src.resolve()))
objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
assert objects
points=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box]
lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
center=(lo+hi)/2;size=max(hi-lo)
scene=bpy.context.scene
scene.render.engine="CYCLES";scene.cycles.samples=24
scene.render.resolution_x=720;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new("Studio");scene.world.use_nodes=True
scene.world.node_tree.nodes["Background"].inputs[0].default_value=(0.22,0.22,0.22,1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value=0.65
def aim(o,p): o.rotation_euler=(p-o.location).to_track_quat("-Z","Y").to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=size*1.5
for direction,power in [((3,-4,5),850),((-3,-1,2),450),((1,4,3),650)]:
    bpy.ops.object.light_add(type="AREA",location=center+Vector(direction)*size)
    l=bpy.context.object;l.data.energy=power*size*size;l.data.shape="DISK";l.data.size=size*2;aim(l,center)
def render(label):
    for name,d in [("front",(0,-1,0.15)),("quarter",(1,-1,0.55))]:
        cam.location=center+Vector(d).normalized()*size*4;aim(cam,center)
        scene.render.filepath=str(out/f"{label}-{name}.png");bpy.ops.render.render(write_still=True)
render("original")
slots=[]
for o in objects:
    for i,s in enumerate(o.material_slots):
        if s.material: slots.append((o,i,s.material))
assert slots
neutral=bpy.data.materials.new("Neutral");neutral.diffuse_color=(0.55,0.55,0.55,1)
for o,i,m in slots:o.material_slots[i].material=neutral
render("unpainted")
checker=bpy.data.materials.new("UV checker");checker.use_nodes=True
n=checker.node_tree.nodes;l=checker.node_tree.links
t=n.new("ShaderNodeTexChecker");t.inputs["Scale"].default_value=12
u=n.new("ShaderNodeTexCoord");l.new(u.outputs["UV"],t.inputs["Vector"]);l.new(t.outputs["Color"],n.get("Principled BSDF").inputs["Base Color"])
for o,i,m in slots:o.material_slots[i].material=checker
render("uv")
for o,i,m in slots:o.material_slots[i].material=m
render("restored")
(out/"report.json").write_text(json.dumps({"source":str(src),"sha256":hashlib.sha256(src.read_bytes()).hexdigest(),"objects":len(objects),"materialSlots":len(slots),"scope":"visual material restoration on original UV; not bind_paint integration or new artwork","published":False},indent=2))
