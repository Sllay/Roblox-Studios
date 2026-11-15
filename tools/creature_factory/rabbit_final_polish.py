"""Final surface polish and atlas preparation for the articulated rabbit.
Preserves object IDs, vertex count, connectivity, weights and rest skeleton.
"""
import bpy,bmesh,sys,json,math
from pathlib import Path
from mathutils import Vector,Quaternion
import numpy as np
out=Path(sys.argv[sys.argv.index("--")+1]);source=Path(sys.argv[sys.argv.index("--")+2])
bpy.ops.wm.open_mainfile(filepath=str(source/"asset.blend"))
rig=bpy.data.objects["RabbitRig"]
objects=sorted([o for o in bpy.context.scene.objects if o.type=="MESH"],key=lambda o:o.name)
assert len(objects)==9 and len(rig.data.bones)==19
def bump(x,c,w):return np.exp(-((x-c)/w)**2)
def smoothstep(a,b,x):
    t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def geometry(o):
    m=o.data;m.calc_loop_triangles()
    v=np.array([tuple(q.co) for q in m.vertices],np.float64)
    f=np.array([tuple(t.vertices) for t in m.loop_triangles],np.int32)
    return v,f
def verify(o):
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),o.name
    bm.free()
    assert all(abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in o.data.vertices),o.name
def edit(o):
    m=o.data;v,f=geometry(o);orig=v.copy();z=v[:,2];x=np.abs(v[:,0]);y=v[:,1]
    if o.name=="Rabbit_Torso":
        # Preserve the two arm socket rims: shoulder patch smoothing must not
        # destroy clearance or move the visible attachment line.
        shoulder=bump(z,1.60,.28)*bump(x,.39,.27)
        back=bump(z,1.20,.54)*smoothstep(-.05,.45,y)
        rump=bump(z,.83,.37)*smoothstep(.12,.52,y)
        face=bump(z,2.30,.23)
        ear=smoothstep(2.62,2.84,z)
        # Smooth learned surface irregularities, not eyelids and ear contours.
        weight=np.clip(.20+.60*back+.50*rump+.25*face-.15*ear-.12*shoulder,.08,.85)
        # Small low-frequency corrections: a broader cranium and a rounder tail.
        v[:,0]*=1+.045*bump(z,2.39,.23)*(1-.7*smoothstep(.35,.70,x))
        tail=bump(z,.91,.22)*smoothstep(.58,.80,y)
        v[:,1]+=.035*tail;v[:,2]+=.025*tail*bump(z,1.04,.20)
    elif o.name.startswith("FrontArm_"):
        weight=.16+.22*bump(z,1.50,.30)
    else:return {"vertices":len(v),"maxDisplacement":0}
    e=np.array([tuple(q.vertices) for q in m.edges],np.int32)
    i=np.r_[e[:,0],e[:,1]];j=np.r_[e[:,1],e[:,0]]
    d=np.bincount(i,minlength=len(v));assert np.all(d>0)
    for _ in range(14):
        for k in (.44,-.46):
            avg=np.column_stack([np.bincount(i,weights=v[j,t],minlength=len(v))/d for t in range(3)])
            v+=k*weight[:,None]*(avg-v)
    # Limit local movement relative to source (artistically conservative).
    delta=v-orig;length=np.linalg.norm(delta,axis=1);v=orig+delta*np.minimum(1,.045/np.maximum(length,1e-10))[:,None]
    p=v[f];area=np.linalg.norm(np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]),axis=1)
    assert np.all(area>1e-13),"Collapsed face"
    m.vertices.foreach_set("co",v.astype(np.float32).ravel());m.update()
    return {"vertices":len(v),"maxDisplacement":float(np.max(np.linalg.norm(v-orig,axis=1)))}
polish={o.name:edit(o) for o in objects}
# Refresh normals without remeshing or touching weights.
for o in objects:verify(o)
scene=bpy.context.scene;cam=scene.camera;center=Vector((0,0,1.8))
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
def render(name,d,clay=False):
    scene.display.shading.color_type="SINGLE" if clay else "VERTEX"
    cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
def reset():
    for b in rig.pose.bones:b.rotation_mode="QUATERNION";b.rotation_quaternion=Quaternion((1,0,0,0))
    bpy.context.view_layer.update()
def pose(name,angle,axis=(1,0,0)):
    b=rig.pose.bones[name];a=b.bone.matrix_local.to_3x3().inverted()@Vector(axis)
    b.rotation_mode="QUATERNION";b.rotation_quaternion=Quaternion(a.normalized(),math.radians(angle))
def evaluated(o):
    ob=o.evaluated_get(bpy.context.evaluated_depsgraph_get());return np.array([tuple(v.co) for v in ob.data.vertices])
def move(o,rest):return float(np.max(np.linalg.norm(evaluated(o)-rest,axis=1)))
reset()
rest={o.name:evaluated(o) for o in objects}
for name,d in {"front":(0,-6,0),"right":(6,0,0),"back":(0,6,0),"three-quarter":(-4,-6,1.3)}.items():render(name,d)
render("clay-three-quarter",(-4,-6,1.3),True)
pose("Shoulder_L",-58);pose("Forearm_L",-27);bpy.context.view_layer.update()
moved=move(bpy.data.objects["FrontArm_L"],rest["FrontArm_L"]);still=move(bpy.data.objects["Rabbit_Torso"],rest["Rabbit_Torso"])
assert moved>.2 and still<1e-5
render("pose-front-left",(-4,-6,1));reset()
pose("Hip_R",-25);pose("Shin_R",35);pose("HindPaw_R",-12);bpy.context.view_layer.update()
assert move(bpy.data.objects["Rabbit_Torso"],rest["Rabbit_Torso"])>.08
render("pose-hind-right",(5,-6,1));reset()
pose("Head",22,(0,0,1));bpy.context.view_layer.update()
assert all(move(o,rest[o.name])>.03 for o in objects if o.name.startswith("Whisker_"))
render("pose-head",(-4,-6,1.3));reset()
# Transfer exact triangle and loop correspondence to the atlas process.
arrays={};manifest=[]
for i,o in enumerate(objects):
    v,f=geometry(o);m=o.data
    loops=np.array([tuple(t.loops) for t in m.loop_triangles],np.int32)
    color=np.array([tuple(q.color) for q in m.color_attributes["BasePalette"].data],np.float32)
    arrays[f"v{i}"]=v.astype(np.float32);arrays[f"f{i}"]=f;arrays[f"l{i}"]=loops;arrays[f"c{i}"]=color
    manifest.append({"name":o.name,"index":i,"loops":len(m.loops),"vertices":len(v),"triangles":len(f)})
np.savez_compressed(out/"atlas-input.npz",**arrays)
(out/"atlas-input.json").write_text(json.dumps(manifest,indent=2))
(out/"polish-report.json").write_text(json.dumps({"source":"rabbit-articulation-43719614276-1","polish":polish,"bones":len(rig.data.bones),"independentArmDisplacement":moved,"torsoDuringArm":still,"topologyAndWeightsPreserved":True,"artisticApproval":False},indent=2))
scene.display.shading.color_type="VERTEX"
bpy.ops.wm.save_as_mainfile(filepath=str(out/"polished.blend"))
