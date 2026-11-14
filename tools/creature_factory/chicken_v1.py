"""S09.1 original stylized chicken candidate. One scene, six views, no Roblox writes."""
import bpy, math, json, sys, hashlib
from pathlib import Path
from mathutils import Vector
args=sys.argv[sys.argv.index("--")+1:]
job=Path(args[0]); out=Path(args[1]); out.mkdir(parents=True,exist_ok=True)
request=json.loads(job.read_text())
assert request["schema"]==1 and request["id"]=="chicken-v1" and request["mode"]=="text"
assert request["backend"]=="authored-chicken-v1"
budget=request["triangle_budget"]
bpy.ops.wm.read_factory_settings(use_empty=True)
parts=[]
def material(name, rgb):
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1)
    m.use_nodes=True; b=m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value=(*rgb,1); b.inputs["Roughness"].default_value=.84
    return m
cream=material("FeatherCream",(.85,.75,.57))
white=material("FeatherIvory",(.97,.91,.79))
warm=material("FeatherShadow",(.68,.52,.35))
red=material("CombCoral",(.68,.075,.055))
gold=material("BeakGold",(.92,.48,.075))
dark=material("EyeDark",(.045,.032,.025))
glint=material("EyeGlint",(.98,.97,.91))
def finish(o,name,mat,pivot=None):
    o.name=name; o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    if pivot is not None:
        # Move the origin without moving the evaluated geometry.
        d=Vector(pivot)-o.location
        for v in o.data.vertices:v.co-=d
        o.location=Vector(pivot)
    parts.append(o); return o
def ell(name,center,scale,mat,rotation=(0,0,0),pivot=None,segments=16,rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=center)
    o=bpy.context.object; o.scale=scale; o.rotation_euler=rotation
    return finish(o,name,mat,pivot)
def segment(name,a,b,r1,r2,mat):
    a,b=Vector(a),Vector(b); d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=r1,radius2=r2,depth=d.length,location=(a+b)/2)
    o=bpy.context.object; o.rotation_euler=d.to_track_quat("Z","Y").to_euler()
    return finish(o,name,mat,a)
# Blender Z up, -Y forward. Feet touch local z=0. Dimensions provisional.
ell("Body",(0,.11,.91),(.57,.72,.62),cream)
ell("Breast",(0,-.31,.93),(.47,.44,.49),white,(-.16,0,0))
ell("Neck",(0,-.45,1.30),(.32,.34,.48),cream,(-.24,0,0))
ell("Head",(0,-.64,1.64),(.37,.37,.35),white,pivot=(0,-.48,1.35))
# Tail has an overlapping fan silhouette, not independent floating objects.
for i,x in enumerate((-.24,0,.24)):
    ell("Tail_%02d"%i,(x,.69,1.15+(.10 if i==1 else 0)),(.16,.23,.46),warm if i!=1 else cream,(-.65,0,-x*.8),pivot=(0,.52,1.04),segments=12,rings=8)
for s,label in ((-1,"L"),(1,"R")):
    ell("Wing_"+label,(s*.49,.09,.98),(.16,.52,.33),white,(.22,0,s*.10),pivot=(s*.36,-.19,1.16))
    for i in range(2):
        ell("WingFeather_"+label+str(i),(s*.52,.28+i*.12,.83+i*.035),(.12,.27,.16),cream,(.32,0,0),pivot=(s*.36,-.19,1.16),segments=12,rings=8)
    ell("Eye_"+label,(s*.294,-.83,1.70),(.085,.075,.09),dark,pivot=(0,-.48,1.35),segments=12,rings=8)
    ell("EyeGlint_"+label,(s*.345,-.865,1.734),(.028,.026,.029),glint,pivot=(0,-.48,1.35),segments=8,rings=6)
    ell("Wattle_"+label,(s*.085,-.82,1.33),(.09,.12,.16),red,pivot=(0,-.48,1.35),segments=12,rings=8)
    x=s*.24
    segment("Shin_"+label,(x,.01,.61),(x,-.04,.13),.075,.057,gold)
    ell("Foot_"+label,(x,-.10,.08),(.11,.13,.08),gold,pivot=(x,-.04,.13),segments=12,rings=8)
    for i,dx in enumerate((-.105,0,.105)):
        segment("Toe_"+label+str(i),(x,-.12,.075),(x+dx,-.33,.055),.045,.025,gold)
    segment("Heel_"+label,(x,-.03,.075),(x,.11,.055),.042,.023,gold)
# Tapered beak with upper and lower pieces; no detached geometry.
segment("BeakUpper",(0,-.91,1.62),(0,-1.23,1.52),.145,.018,gold)
segment("BeakLower",(0,-.91,1.49),(0,-1.16,1.48),.105,.018,gold)
for i,(y,z,h) in enumerate(((-.81,1.89,.22),(-.64,1.98,.27),(-.46,1.90,.20))):
    ell("Comb_"+str(i),(0,y,z),(.095,.12,h),red,pivot=(0,-.48,1.35),segments=12,rings=8)
# Normalize the beak cone shading while keeping the silhouette. Every part has UV.
for o in parts:
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active=o
    if not o.data.uv_layers:
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(); bpy.ops.object.mode_set(mode="OBJECT")
    o.data.calc_loop_triangles()
triangles=sum(len(o.data.loop_triangles) for o in parts)
assert 0<triangles<=budget and all(o.data.uv_layers for o in parts), (triangles,budget)
assert len({o.name for o in parts})==len(parts)
points=[o.matrix_world@v.co for o in parts for v in o.data.vertices]
lo=[min(v[i] for v in points) for i in range(3)]; hi=[max(v[i] for v in points) for i in range(3)]
assert abs(lo[2])<.03 and 2<hi[2]<2.5
bpy.ops.object.select_all(action="DESELECT")
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB",use_selection=True)
# Render exactly the exported scene, not separately generated views.
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH"
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
sh=scene.display.shading;sh.color_type="MATERIAL";sh.light="STUDIO";sh.show_shadows=True
sh.show_cavity=True;sh.cavity_type="BOTH";sh.background_type="WORLD"
scene.world=bpy.data.worlds.new("ReviewWorld");scene.world.color=(.13,.16,.19)
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=3.15
center=Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,(lo[2]+hi[2])/2))
views={"front":(0,-5,0),"back":(0,5,0),"left":(-5,0,0),"right":(5,0,0),"top":(0,0,5),"three-quarter":(4,-5,2)}
for name,d in views.items():
    cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"asset.blend"))
# Reimport GLB in clean scene and verify geometry, UV and names survive serialization.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out/"asset.glb"))
imported=[o for o in bpy.context.scene.objects if o.type=="MESH"]
for o in imported:o.data.calc_loop_triangles()
assert len(imported)==len(parts) and sum(len(o.data.loop_triangles) for o in imported)==triangles
assert all(o.data.uv_layers for o in imported)
report={"schema":1,"id":request["id"],"state":"review_ready","mode":"authored_text_pilot","triangles":triangles,"triangleBudget":budget,"meshObjects":len(imported),"materials":7,"uv":True,"bounds":{"min":lo,"max":hi},"views":list(views),"roundtrip":True,"rigged":False,"texturedAtlas":False,"robloxPublished":False,"artisticApproval":False,"requestSha256":hashlib.sha256(job.read_bytes()).hexdigest()}
(out/"report.json").write_text(json.dumps(report,indent=2)+"\n")
