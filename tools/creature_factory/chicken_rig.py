"""S09 production rig: immutable V2 -> unique atlas -> skin -> five clips."""
import bpy, math, sys, json, struct, hashlib, io
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt
from mathutils import Vector, Euler
args=sys.argv[sys.argv.index("--")+1:]
source,out=Path(args[0]),Path(args[1]);out.mkdir(parents=True,exist_ok=True)
assert hashlib.sha256(source.read_bytes()).hexdigest()=="4c96eb027d4954e1c2fdc1b8a9a8ee4329f0e8c4c4185211a652b9e86d46d0d1"
def glb(path):
    b=path.read_bytes();n=struct.unpack_from("<I",b,12)[0];return json.loads(b[20:20+n]),b[28+n:]
def acc(j,b,i):
    a=j["accessors"][i];v=j["bufferViews"][a["bufferView"]];dt={5121:"u1",5123:"<u2",5125:"<u4",5126:"<f4"}[a["componentType"]];k={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}[a["type"]]
    off=v.get("byteOffset",0)+a.get("byteOffset",0);stride=v.get("byteStride",np.dtype(dt).itemsize*k)
    return np.ndarray((a["count"],k),dtype=dt,buffer=b,offset=off,strides=(stride,np.dtype(dt).itemsize)).copy()
def triangle_keys(j,b):
    keys=[]
    for m in j["meshes"]:
        for p in m["primitives"]:
            v=acc(j,b,p["attributes"]["POSITION"]);f=acc(j,b,p["indices"]).reshape(-1,3)
            for t in v[f]:keys.append(tuple(sorted(tuple(np.rint(q*1e5).astype(int)) for q in t)))
    return sorted(keys)
j0,b0=glb(source);original=triangle_keys(j0,b0);assert len(original)==3120
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
objs=[o for o in bpy.context.scene.objects if o.type=="MESH"];assert len(objs)==41
# Preserve source identities through join, without changing coordinates or faces.
for o in objs:
    bpy.ops.object.select_all(action="DESELECT");o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    g=o.vertex_groups.new(name="src_"+o.name);g.add(list(range(len(o.data.vertices))),1,"REPLACE")
bpy.ops.object.select_all(action="DESELECT")
for o in objs:o.select_set(True)
bpy.context.view_layer.objects.active=next(o for o in objs if o.name=="Body_Head")
bpy.ops.object.join();mesh=bpy.context.object;mesh.name="Chicken_V2";me=mesh.data
me.calc_loop_triangles();assert len(me.loop_triangles)==3120
tags=[]
for v in me.vertices:
    names=[mesh.vertex_groups[g.group].name[4:] for g in v.groups if mesh.vertex_groups[g.group].name.startswith("src_")]
    assert len(names)==1;tags.append(names[0])
# Original material values are linear glTF factors; convert to sRGB for PNG.
def srgb(x):return 12.92*x if x<=.0031308 else 1.055*x**(1/2.4)-.055
palette=[]
for m in me.materials:
    val=m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value
    palette.append(tuple(round(max(0,min(1,srgb(float(x))))*255) for x in val[:3]))
facecolors=[palette[p.material_index] for p in me.polygons]
# Real UV unwrap and pack; no palette-only overlapping UV shortcut.
while me.uv_layers:me.uv_layers.remove(me.uv_layers[0])
me.uv_layers.new(name="ChickenAtlas")
bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.003)
bpy.ops.uv.pack_islands(rotate=True,margin=.003)
bpy.ops.object.mode_set(mode="OBJECT")
me.calc_loop_triangles();uv=me.uv_layers.active.data
N=1024;tex=np.zeros((N,N,3),np.uint8);owner=np.full((N,N),-1,np.int32);overlaps=0;empty=0;checks=[]
for idx,t in enumerate(me.loop_triangles):
    q=np.array([(uv[k].uv.x*N,(1-uv[k].uv.y)*N) for k in t.loops])
    assert np.isfinite(q).all() and q.min()>=-.01 and q.max()<=N+.01
    col=facecolors[t.polygon_index]
    x0,y0=np.maximum(0,np.floor(q.min(0)).astype(int));x1,y1=np.minimum(N-1,np.ceil(q.max(0)).astype(int))
    xx,yy=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
    a,b,c=q;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1]);assert abs(den)>1e-8
    u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den;v=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den
    mask=(u>1e-6)&(v>1e-6)&(1-u-v>1e-6);ys,xs=np.where(mask);ys+=y0;xs+=x0
    if not len(xs):empty+=1
    overlaps+=int(np.count_nonzero(owner[ys,xs]>=0));owner[ys,xs]=idx;tex[ys,xs]=col
    checks.append((q.mean(0),col))
assert overlaps==0,("UV overlap pixels",overlaps)
# Dilation fills padding from nearest covered texel, preventing dark seams.
_,near=distance_transform_edt(owner<0,return_indices=True);tex=tex[near[0],near[1]]
errors=0
for q,col in checks:
    x,y=np.clip(np.floor(q).astype(int),0,N-1)
    if tuple(tex[y,x])!=col:errors+=1
assert errors==0,("atlas color sample mismatch",errors)
Image.fromarray(tex).save(out/"chicken-albedo.png")
atlas={"triangles":3120,"size":[N,N],"coveredPixels":int((owner>=0).sum()),"overlapInteriorPixels":overlaps,"emptySubpixelTriangles":empty,"colorSampleErrors":errors,"sourceMaterials":len(palette),"finalMaterials":1,"method":"Blender Smart UV + pack islands; rasterized linear-to-sRGB colors and nearest-texel padding"}
(out/"checkpoint-1-atlas.json").write_text(json.dumps(atlas,indent=2))
mat=bpy.data.materials.new("Chicken_Atlas");mat.use_nodes=True
bs=mat.node_tree.nodes.get("Principled BSDF");bs.inputs["Roughness"].default_value=.85
im=bpy.data.images.load(str(out/"chicken-albedo.png"));im.pack()
tn=mat.node_tree.nodes.new("ShaderNodeTexImage");tn.image=im;mat.node_tree.links.new(tn.outputs["Color"],bs.inputs["Base Color"]);mat.node_tree.nodes.active=tn
me.materials.clear();me.materials.append(mat)
for p in me.polygons:p.material_index=0;p.use_smooth=False
# Skeleton: +Z bone orientation gives local X as world X. All names stable.
spec=[("Root",None,(0,0,0)),("Body","Root",(0,0,.85)),("Neck","Body",(0,-.19,1.38)),("Head","Neck",(0,-.32,1.60)),("Jaw","Head",(0,-.74,1.75)),("Wing_L","Body",(-.57,-.18,1.25)),("Wing_R","Body",(.57,-.18,1.25)),("Tail","Body",(0,.4,1.0))]
for s,L in [(-1,"L"),(1,"R")]:
    spec.extend([("Hip_"+L,"Body",(s*.24,.045,.52)),("Shin_"+L,"Hip_"+L,(s*.24,.03,.34)),("Foot_"+L,"Shin_"+L,(s*.24,-.055,.075))])
arm=bpy.data.armatures.new("ChickenSkeleton");rig=bpy.data.objects.new("ChickenRig",arm);bpy.context.collection.objects.link(rig)
bpy.ops.object.select_all(action="DESELECT");rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode="EDIT")
for name,parent,pos in spec:
    bone=arm.edit_bones.new(name);bone.head=pos;bone.tail=Vector(pos)+Vector((0,0,.14));bone.use_deform=name!="Root"
    if parent:bone.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")
for g in list(mesh.vertex_groups):mesh.vertex_groups.remove(g)
groups={n:mesh.vertex_groups.new(name=n) for n,_,_ in spec if n!="Root"}
def smooth(a,b,z):
    t=max(0,min(1,(z-a)/(b-a)));return t*t*(3-2*t)
def weights(tag,z):
    if tag=="Body_Head":
        n=smooth(1.22,1.49,z);h=smooth(1.49,1.68,z);return {"Body":1-n,"Neck":n-h,"Head":h}
    if tag.startswith("Collar_"):
        n=smooth(1.14,1.49,z);return {"Body":1-n,"Neck":n}
    if tag.startswith("Wing"):return {"Wing_"+tag.split("_")[1][0]:1}
    if tag.startswith("Tail"):return {"Tail":1}
    if tag.startswith("Leg_"):
        l=tag[-1];t=1-smooth(.22,.42,z);return {"Hip_"+l:1-t,"Shin_"+l:t}
    if tag.startswith("Foot_"):return {tag:1}
    if tag=="BeakLower":return {"Jaw":1}
    return {"Head":1}
for v,tag in zip(me.vertices,tags):
    w=weights(tag,v.co.z);assert abs(sum(w.values())-1)<1e-6 and min(w.values())>=-1e-8
    for n,x in w.items():
        if x>1e-7:groups[n].add([v.index],x,"REPLACE")
assert all(abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in me.vertices)
mesh.parent=rig;mod=mesh.modifiers.new("ChickenSkin","ARMATURE");mod.object=rig
scene=bpy.context.scene;scene.render.fps=24
for p in rig.pose.bones:p.rotation_mode="QUATERNION"
def reset():
    for p in rig.pose.bones:p.rotation_quaternion=(1,0,0,0);p.location=(0,0,0);p.scale=(1,1,1)
def rot(n,x=0,y=0,z=0):rig.pose.bones[n].rotation_quaternion=Euler((x,y,z),"XYZ").to_quaternion()
def body_height(h):rig.pose.bones["Body"].location.y=h
# Two-link planar IK using actual rest anchors; foot orientation cancels chain rotations.
H=np.array([.045,.52]);K=np.array([.03,.34]);A=np.array([-.055,.075])
l1=np.linalg.norm(K-H);l2=np.linalg.norm(A-K)
base1=math.atan2(*(K-H)[::-1]);base2=math.atan2(*(A-K)[::-1])
sign=np.sign(np.cross(A-H,K-H))
def leg(L,y,z,h):
    target=np.array([y,z-h]);d=target-H;length=np.linalg.norm(d)
    assert abs(l1-l2)+1e-6<length<l1+l2-1e-6,("IK unreachable",L,length)
    u=d/length;along=(l1*l1-l2*l2+length*length)/(2*length);k=H+along*u+sign*math.sqrt(max(0,l1*l1-along*along))*np.array([-u[1],u[0]])
    a1=math.atan2(*(k-H)[::-1])-base1;a2=math.atan2(*(target-k)[::-1])-base2
    rot("Hip_"+L,a1);rot("Shin_"+L,a2-a1);rot("Foot_"+L,-a2)
def pose(name,t):
    reset();p=2*math.pi*t
    if name=="Idle":
        rot("Neck",.035*math.sin(p));rot("Head",-.055*math.sin(p),0,.035*math.sin(p*.5)**2);rot("Tail",.04*math.sin(p))
    elif name in ("Walk","Run"):
        run=name=="Run";h=(-.07 if run else -.045)+(.018 if run else .01)*math.cos(2*p);body_height(h)
        for L,offset in [("L",0),("R",.5)]:
            a=(t+offset)%1;stance=.58;stride=.16 if run else .115;lift=.135 if run else .07
            if a<stance:y=-.055-stride+2*stride*a/stance;z=.075
            else:b=(a-stance)/(1-stance);y=-.055+stride-2*stride*b;z=.075+lift*math.sin(math.pi*b)
            leg(L,y,z,h)
        rot("Neck",.10*math.sin(2*p));rot("Head",-.07*math.sin(2*p));rot("Tail",.07*math.sin(p))
        rot("Wing_L",0,0,-(.17 if run else .06)*math.sin(p));rot("Wing_R",0,0,(.17 if run else .06)*math.sin(p))
    elif name=="Peck":
        bend=math.sin(math.pi*t)**4;body_height(-.12*bend)
        # Keep feet planted while the torso lowers; neck and head reach forward.
        for L in ("L","R"):
            if bend>1e-4:leg(L,-.055,.075,-.12*bend)
        rot("Neck",1.0*bend);rot("Head",.75*bend);rot("Jaw",-.16*bend);rot("Tail",-.14*bend)
    elif name=="Flap":
        a=math.sin(math.pi*t)**2;f=a*(.85+.32*math.sin(6*math.pi*t))
        rot("Wing_L",0,0,-f);rot("Wing_R",0,0,f);rot("Neck",-.08*a);rot("Tail",.13*a)
    bpy.context.view_layer.update()
# Five clips with identical start/end pose. Check foot world anchors during gait.
dur={"Idle":48,"Walk":24,"Run":18,"Peck":30,"Flap":30};actions={};footerr=0.;maxjaw=0.
for name,frames in dur.items():
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data_create();rig.animation_data.action=action
    start=None
    for frame in range(frames+1):
        scene.frame_set(frame);t=frame/frames;pose(name,t)
        current=np.array([tuple(p.rotation_quaternion)+tuple(p.location) for p in rig.pose.bones])
        if frame==0:start=current
        if frame==frames:assert np.max(np.abs(start-current))<1e-5,(name,"loop")
        if name in ("Walk","Run"):
            for L,offset in [("L",0),("R",.5)]:
                if (t+offset)%1<.58:
                    z=rig.pose.bones["Foot_"+L].head.z;footerr=max(footerr,abs(z-.075))
        for p in rig.pose.bones:
            p.keyframe_insert("rotation_quaternion",frame=frame,group=p.name)
        rig.pose.bones["Body"].keyframe_insert("location",frame=frame,group="Body")
    for f in action.fcurves:
        for k in f.keyframe_points:k.interpolation="LINEAR"
    actions[name]=action;rig.animation_data.action=None
assert footerr<.001,("stance foot anchor error",footerr)
for name,action in actions.items():
    tr=rig.animation_data.nla_tracks.new();tr.name=name;strip=tr.strips.new(name,0,action);strip.name=name
reset();scene.frame_set(0);bpy.context.view_layer.update()
# Mesh must not move in rest pose; comparison uses exact original triangles after export.
bpy.ops.object.select_all(action="DESELECT");rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
path=out/"chicken-v2-rig.glb"
bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,export_animations=True,export_animation_mode="NLA_TRACKS",export_force_sampling=True,export_frame_range=False,export_skins=True)
j,b=glb(path)
assert len(j["meshes"])==1 and len(j["meshes"][0]["primitives"])==1 and len(j["materials"])==1
assert triangle_keys(j,b)==original, "rest geometry changed"
p=j["meshes"][0]["primitives"][0];w=acc(j,b,p["attributes"]["WEIGHTS_0"]);ids=acc(j,b,p["attributes"]["JOINTS_0"])
assert np.max(np.abs(w.sum(1)-1))<1e-5 and np.min(w)>=0 and len(j["skins"])==1
names=[a["name"] for a in j.get("animations",[])];assert set(names)==set(dur) and len(names)==5,names
for a in j["animations"]:
    assert a["channels"] and all(c["target"]["node"] in j["skins"][0]["joints"] for c in a["channels"])
    for s in a["samplers"]:
        t=acc(j,b,s["input"]).ravel();assert len(t)>1 and np.all(np.diff(t)>0)
report={"sourceSha256":hashlib.sha256(source.read_bytes()).hexdigest(),"glbSha256":hashlib.sha256(path.read_bytes()).hexdigest(),"triangles":3120,"renderMeshes":1,"renderPrimitives":1,"materials":1,"verticesExported":int(len(w)),"bones":len(j["skins"][0]["joints"]),"weightMaxError":float(np.max(np.abs(w.sum(1)-1))),"stanceAnchorMaxError":footerr,"clips":names,"clipFrames":dur,"fps":24,"restTriangleParity":True,"atlas":atlas,"robloxImported":False}
(out/"checkpoint-2-rig.json").write_text(json.dumps({k:v for k,v in report.items() if k!="atlas"},indent=2))
# Independent Blender import of the exported asset verifies actual decoded skin/actions.
bpy.ops.wm.save_as_mainfile(filepath=str(out/"chicken-v2-rig.blend"))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(path))
rig=next(o for o in bpy.context.scene.objects if o.type=="ARMATURE");mesh=next(o for o in bpy.context.scene.objects if o.type=="MESH")
assert len(rig.data.bones)==report["bones"] and any(m.type=="ARMATURE" for m in mesh.modifiers)
imported=list(bpy.data.actions);assert len(imported)==5,[a.name for a in imported]
scene=bpy.context.scene;scene.render.fps=24;scene.render.engine="BLENDER_EEVEE";scene.render.resolution_x=480;scene.render.resolution_y=480;scene.render.resolution_percentage=100;scene.render.film_transparent=True
scene.world=bpy.data.worlds.new("StudioWorld");scene.world.use_nodes=True;scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.7,.7,.7,1);scene.world.node_tree.nodes["Background"].inputs[1].default_value=.45
def light(name,loc,power,size):
    d=bpy.data.lights.new(name,"AREA");d.energy=power;d.shape="DISK";d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.2))-o.location).to_track_quat("-Z","Y").to_euler()
light("Key",(3,-4,5),550,4);light("Fill",(-3,-2,3),350,4);light("Rim",(1,3,4),400,3)
camd=bpy.data.cameras.new("Review");cam=bpy.data.objects.new("Review",camd);scene.collection.objects.link(cam);scene.camera=cam;camd.type="ORTHO";camd.ortho_scale=3.6
cam.location=(4,-6,3);cam.rotation_euler=(Vector((0,0,1.25))-cam.location).to_track_quat("-Z","Y").to_euler()
if rig.animation_data:
    for track in rig.animation_data.nla_tracks:track.mute=True
for name,frame in [("Idle",0),("Walk",6),("Run",5),("Peck",15),("Flap",12)]:
    matches=[a for a in imported if a.name==name or a.name.startswith(name+" " ) or a.name.startswith(name+"_")];assert len(matches)==1,(name,[a.name for a in imported])
    rig.animation_data.action=matches[0];scene.frame_set(frame);bpy.context.view_layer.update()
    scene.render.filepath=str(out/(name.lower()+".png"));bpy.ops.render.render(write_still=True)
report["independentBlenderReimport"]=True;report["renderedPoses"]=["Idle","Walk","Run","Peck","Flap"]
(out/"report.json").write_text(json.dumps(report,indent=2));print(json.dumps(report))
