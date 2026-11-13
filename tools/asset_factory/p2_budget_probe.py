import bpy,math,sys,json
from pathlib import Path
from mathutils import Vector
out=Path(sys.argv[sys.argv.index("--")+1]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH";scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100
scene.display.shading.color_type="MATERIAL";scene.render.film_transparent=True
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=2.1
def material(name,c):
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=(*c,1);return m
wood=material("Wood",(.36,.19,.075));stone=material("Stone",(.32,.39,.36))
def build(n,rings,segments):
    v=[];f=[]
    for j in range(rings):
        t=j/(rings-1);z=1.35*t;x=.06*math.sin(math.pi*t)+.03*t;r=.085-.025*math.sin(math.pi*t)+.025*t
        v.extend([(x+r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for i in range(n)])
    for j in range(rings-1):
        for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    f.extend([tuple(reversed(range(n))),tuple(range((rings-1)*n,rings*n))])
    m=bpy.data.meshes.new("Handle");m.from_pydata(v,[],f);m.update();o=bpy.data.objects.new("Handle",m);scene.collection.objects.link(o);m.materials.append(wood)
    for p in m.polygons:p.use_smooth=len(p.vertices)==4
    bpy.ops.mesh.primitive_cube_add(size=1,location=(.22,0,1.25));h=bpy.context.object;h.scale=(.65,.25,.36);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);h.data.materials.append(stone)
    b=h.modifiers.new("Bevel","BEVEL");b.width=.07;b.segments=segments;bpy.ops.object.modifier_apply(modifier=b.name)
    return [o,h]
def count(obs):
    for o in obs:o.data.calc_loop_triangles()
    return sum(len(o.data.loop_triangles) for o in obs)
def render(name,obs):
    for o in scene.objects:
        if o.type=="MESH":o.hide_render=o not in obs
    for k,d in {"front":(0,-4,0),"quarter":(3,-4,2),"right":(4,0,0)}.items():
        c=Vector((.1,0,.7));cam.location=c+Vector(d);cam.rotation_euler=(c-cam.location).to_track_quat("-Z","Y").to_euler();scene.render.filepath=str(out/(name+"-"+k+".png"));bpy.ops.render.render(write_still=True)
def export(name,obs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.export_scene.gltf(filepath=str(out/(name+".glb")),export_format="GLB",use_selection=True)
high=build(48,72,12);render("master",high);export("master",high)
report={"master":count(high),"variants":[]}
for budget in (200,500,1000,3000,7000,10000):
    # Choose highest direct tessellation within budget, preserving separate components.
    options=[(n,r,s) for n in (6,8,12,16,24,32,48) for r in (4,6,10,16,24,40,72) for s in (1,2,3,4,6,8,12) if 2*n*r-4+12+24*s+8*s*s<=budget]
    n,r,s=max(options,key=lambda q:(min(q[0]/48,q[1]/72,q[2]/12),2*q[0]*q[1]+8*q[2]**2))
    direct=build(n,r,s)
    # Actual Blender triangle count is authoritative.
    while count(direct)>budget and r>4:
        for o in direct:bpy.data.objects.remove(o,do_unlink=True)
        r-=1;direct=build(n,r,s)
    assert count(direct)<=budget,(budget,count(direct))
    reduced=[]
    for src in high:
        o=src.copy();o.data=src.data.copy();scene.collection.objects.link(o);o.hide_render=False;bpy.context.view_layer.objects.active=o;o.select_set(True)
        mod=o.modifiers.new("Budget","DECIMATE");mod.ratio=min(1,budget/count(high));bpy.ops.object.modifier_apply(modifier=mod.name);reduced.append(o)
    for label,obs in (("direct",direct),("reduced",reduced)):
        name=f"{label}-{budget}";render(name,obs);export(name,obs);report["variants"].append({"method":label,"budget":budget,"triangles":count(obs)})
    for o in direct+reduced:bpy.data.objects.remove(o,do_unlink=True)
(out/"report.json").write_text(json.dumps(report,indent=2));print("P2_BUDGET "+json.dumps(report),flush=True)
