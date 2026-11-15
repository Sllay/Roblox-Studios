"""Rabbit articulation candidate: real separated forelimbs and deformable hind legs."""
import bpy,bmesh,sys,json,math,struct
from pathlib import Path
from mathutils import Vector,Quaternion
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parent))
from rabbit_limb_surface import separate
out=Path(sys.argv[sys.argv.index("--")+1]);source=Path(sys.argv[sys.argv.index("--")+2])
bpy.ops.wm.open_mainfile(filepath=str(source/"asset.blend"))
body=bpy.data.objects["Rabbit_Neural_Body"];m=body.data;m.calc_loop_triangles()
v=np.array([tuple(x.co) for x in m.vertices],dtype=np.float64)
f=np.array([tuple(x.vertices) for x in m.loop_triangles],dtype=np.int32)
c=np.array([tuple(x.color) for x in m.color_attributes["BasePalette"].data],dtype=np.float64)
parts,cut=separate(v,f,c)
mat=body.data.materials[0]
bpy.data.objects.remove(body,do_unlink=True)
def active(o):
    bpy.ops.object.select_all(action="DESELECT");o.select_set(True);bpy.context.view_layer.objects.active=o
def mesh(name,data):
    V,F,C=data;m=bpy.data.meshes.new(name);m.from_pydata(V.tolist(),[],F.tolist());m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o)
    bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges);bm.to_mesh(m);bm.free();m.update()
    for p in m.polygons:p.use_smooth=True
    ca=m.color_attributes.new(name="BasePalette",type="FLOAT_COLOR",domain="POINT");ca.data.foreach_set("color",C.astype(np.float32).ravel());m.color_attributes.active_color=ca
    m.materials.append(mat);active(o);bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.012);bpy.ops.object.mode_set(mode="OBJECT")
    return o
objs={k:mesh(k,d) for k,d in parts.items()}
# Shared skeleton with independent front and rear chains.
arm=bpy.data.armatures.new("RabbitSkeleton");rig=bpy.data.objects.new("RabbitRig",arm);bpy.context.collection.objects.link(rig)
active(rig);bpy.ops.object.mode_set(mode="EDIT")
def bone(name,h,t,parent=None):
    b=arm.edit_bones.new(name);b.head=h;b.tail=t
    if parent:b.parent=arm.edit_bones[parent]
    return b
bone("Root",(0,0,.12),(0,0,.45))
bone("Pelvis",(0,.18,.65),(0,.12,1.07),"Root")
bone("Chest",(0,.12,1.07),(0,-.12,1.86),"Pelvis")
bone("Head",(0,-.12,1.86),(0,-.20,2.58),"Chest")
bone("Tail",(0,.48,.92),(0,.83,1.02),"Pelvis")
for tag,s in (("L",-1),("R",1)):
    bone("Ear_"+tag,(s*.32,.20,2.61),(s*.49,.25,3.45),"Head")
    bone("Shoulder_"+tag,(s*.38,-.12,1.84),(s*.44,-.31,1.46),"Chest")
    bone("Forearm_"+tag,(s*.44,-.31,1.46),(s*.25,-.54,1.12),"Shoulder_"+tag)
    bone("FrontPaw_"+tag,(s*.25,-.54,1.12),(s*.20,-.62,.94),"Forearm_"+tag)
    bone("Hip_"+tag,(s*.47,.18,1.02),(s*.51,-.04,.60),"Pelvis")
    bone("Shin_"+tag,(s*.51,-.04,.60),(s*.48,.18,.24),"Hip_"+tag)
    bone("HindPaw_"+tag,(s*.48,.18,.24),(s*.48,-.46,.10),"Shin_"+tag)
bpy.ops.object.mode_set(mode="OBJECT");rig.show_in_front=True
def ss(a,b,x):
    t=np.clip((x-a)/(b-a),0,1);return float(t*t*(3-2*t))
def assign(o,fn):
    groups={}
    for vert in o.data.vertices:
        weights={k:float(w) for k,w in fn(*vert.co).items() if w>1e-6}
        total=sum(weights.values());assert total>0
        for k,w in weights.items():
            if k not in groups:groups[k]=o.vertex_groups.new(name=k)
            groups[k].add([vert.index],w/total,"REPLACE")
    o.parent=rig;mod=o.modifiers.new("RabbitDeformation","ARMATURE");mod.object=rig;mod.use_deform_preserve_volume=True
    assert all(abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in o.data.vertices)
def frontweights(tag,z):
    sh=ss(1.32,1.59,z);paw=1-ss(1.04,1.20,z)
    return {"Shoulder_"+tag:sh,"Forearm_"+tag:(1-sh)*(1-paw),"FrontPaw_"+tag:(1-sh)*paw}
def bodyweights(x,y,z):
    tag="L" if x<0 else "R";side=abs(x)
    head=ss(1.83,2.06,z);ear=ss(2.60,2.83,z)*ss(.10,.23,side)
    tail=ss(.52,.72,y)*(1-ss(1.20,1.38,z))*ss(.40,.61,z)
    leg=ss(.21,.40,side)*(1-ss(.90,1.25,z))
    foot=1-ss(.20,.37,z);shin=1-ss(.48,.71,z)
    chest=ss(.96,1.44,z)
    rem=(1-head)*(1-tail);b=rem*(1-leg)
    return {"Head":head*(1-ear),"Ear_"+tag:head*ear,"Tail":(1-head)*tail,
            "Hip_"+tag:rem*leg*(1-shin),"Shin_"+tag:rem*leg*shin*(1-foot),
            "HindPaw_"+tag:rem*leg*shin*foot,"Chest":b*chest,"Pelvis":b*(1-chest)}
assign(objs["Rabbit_Torso"],bodyweights)
for tag in ("L","R"):assign(objs["FrontArm_"+tag],lambda x,y,z,tag=tag:frontweights(tag,z))
whiskers=[o for o in bpy.context.scene.objects if o.name.startswith("Whisker_")]
assert len(whiskers)==6
for o in whiskers:assign(o,lambda x,y,z:{"Head":1.0})
# Ensure output mesh contains only the intended independent limb parts.
meshes=list(objs.values())+whiskers
scene=bpy.context.scene;cam=scene.camera
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.display.shading.color_type="VERTEX"
center=Vector((0,0,1.8))
def render(name,d,clay=False):
    scene.display.shading.color_type="SINGLE" if clay else "VERTEX"
    cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
def pose(name,angle,axis=(1,0,0)):
    b=rig.pose.bones[name];a=b.bone.matrix_local.to_3x3().inverted()@Vector(axis)
    b.rotation_mode="QUATERNION";b.rotation_quaternion=Quaternion(a.normalized(),math.radians(angle))
def reset():
    for b in rig.pose.bones:b.rotation_mode="QUATERNION";b.rotation_quaternion=Quaternion((1,0,0,0))
    bpy.context.view_layer.update()
def evaluated(o):
    dg=bpy.context.evaluated_depsgraph_get();ob=o.evaluated_get(dg)
    return np.array([tuple(q.co) for q in ob.data.vertices])
def movement(before,o):return float(np.max(np.linalg.norm(evaluated(o)-before,axis=1)))
rest={o.name:evaluated(o) for o in meshes}
for name,d in {"front":(0,-6,0),"right":(6,0,0),"back":(0,6,0),"left":(-6,0,0),"three-quarter":(-4,-6,1.3)}.items():render(name,d)
render("clay-three-quarter",(-4,-6,1.3),True)
# Actual evaluated-mesh tests, not merely bone existence.
pose("Shoulder_L",-58);pose("Forearm_L",-27);bpy.context.view_layer.update()
left=movement(rest["FrontArm_L"],objs["FrontArm_L"]);right=movement(rest["FrontArm_R"],objs["FrontArm_R"])
torso=movement(rest["Rabbit_Torso"],objs["Rabbit_Torso"])
assert left>.2 and right<1e-5 and torso<1e-5,(left,right,torso)
render("pose-front-left",(-4,-6,1.0));reset()
pose("Hip_R",-25);pose("Shin_R",35);pose("HindPaw_R",-12);bpy.context.view_layer.update()
rear=movement(rest["Rabbit_Torso"],objs["Rabbit_Torso"])
assert rear>.08
assert movement(rest["FrontArm_L"],objs["FrontArm_L"])<1e-5
render("pose-hind-right",(5,-6,1.0));reset()
pose("Head",22,(0,0,1));bpy.context.view_layer.update()
moves={o.name:movement(rest[o.name],o) for o in whiskers};assert min(moves.values())>.03
render("pose-head",(-4,-6,1.3));reset()
# Save rest rig; the pose renders are validation only, not final animations.
scene.display.shading.color_type="VERTEX";active(rig)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"asset.blend"))
for o in meshes:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB",use_selection=True,export_animations=False)
raw=(out/"asset.glb").read_bytes();n,t=struct.unpack_from("<II",raw,12);j=json.loads(raw[20:20+n])
assert j.get("skins") and len(j["skins"][0]["joints"])>=18
prims=[p for m in j["meshes"] for p in m["primitives"]]
assert all("JOINTS_0" in p["attributes"] and "WEIGHTS_0" in p["attributes"] for p in prims)
tris=sum(j["accessors"][p["indices"]]["count"]//3 for p in prims)
verts=sum(j["accessors"][p["attributes"]["POSITION"]]["count"] for p in prims)
report={"schema":1,"id":"rabbit-v3-articulation","category":"creature","source":"rabbit-v3-polish-43717865946-1",
 "state":"articulation_review","cut":cut,"meshNames":[o.name for o in meshes],"triangles":tris,"exportedVertices":verts,
 "rigged":True,"bones":len(arm.bones),"frontArmsIndependent":True,"hindLegsWeighted":True,"whiskers":6,"whiskerHeadBound":True,
 "poseTests":{"leftArmDisplacement":left,"oppositeArmDisplacement":right,"torsoDisplacementDuringArm":torso,"hindLegDisplacement":rear,"whiskerDisplacements":moves},
 "artisticApproval":False,"robloxPublished":False,"runtimePackagingRequired":True,
 "limitations":["Joint caps are newly reconstructed hidden surfaces; visual review of the shoulder seam and pose clearance is required.","Prototype rig and test poses only; final animation and Roblox mesh partitioning remain pending."]}
(out/"report.json").write_text(json.dumps(report,indent=2)+"\n");print(json.dumps(report),flush=True)
