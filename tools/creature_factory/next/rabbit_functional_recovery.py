"""Rabbit functional recovery from the immutable articulated paint-ready V3.
No voxel rebuild, new geometry, or UV rewrite. Add actual facial controls and
evaluate independent bone motions on the mesh, not just the skeleton.
"""
import bpy, sys, json, math, hashlib, struct
from pathlib import Path
import numpy as np
from mathutils import Vector, Quaternion
from mathutils.bvhtree import BVHTree

args=sys.argv[sys.argv.index("--")+1:]
source=Path(args[0]);out=Path(args[1]);out.mkdir(parents=True,exist_ok=True)
assert hashlib.sha256(source.read_bytes()).hexdigest()=="25d3f62033b9cf633bf4d458517b8f01bf5c78731dbd970859d69e017e136d05"
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=bpy.data.objects["RabbitRig"];body=bpy.data.objects["Rabbit_Torso"]
objects=sorted([o for o in bpy.context.scene.objects if o.type=="MESH"],key=lambda x:x.name)
whiskers=[o for o in objects if o.name.startswith("Whisker_")]
assert len(objects)==9 and len(whiskers)==6 and len(rig.data.bones)==19
def coords(o):return np.array([tuple(v.co) for v in o.data.vertices],dtype=np.float64)
def reset():
    for b in rig.pose.bones:
        b.rotation_mode="QUATERNION";b.rotation_quaternion=Quaternion((1,0,0,0));b.location=(0,0,0);b.scale=(1,1,1)
    bpy.context.view_layer.update()
reset()
original={o.name:coords(o) for o in objects}
uv={o.name:np.array([tuple(q.uv) for q in o.data.uv_layers.active.data]) for o in objects}
topology={o.name:len(o.data.polygons) for o in objects}
# Each root is measured on the existing whisker geometry, never guessed from
# the concept. Whisker pivots are centered on their innermost cross section.
roots={};tips={}
for o in whiskers:
    v=original[o.name];order=np.argsort(abs(v[:,0]))
    roots[o.name]=v[order[:8]].mean(0);tips[o.name]=v[order[-8:]].mean(0)
bpy.ops.object.select_all(action="DESELECT");rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode="EDIT")
def bone(name,h,t,parent):
    b=rig.data.edit_bones.new(name);b.head=Vector(h);b.tail=Vector(t);b.parent=rig.data.edit_bones[parent];b.use_connect=False
bone("Muzzle",(0,-.65,2.075),(0,-.90,2.075),"Head")
for o in whiskers:bone(o.name+"_Control",roots[o.name],tips[o.name],"Muzzle")
bpy.ops.object.mode_set(mode="OBJECT")
# Transfer head influence only, never touch ear/limb/pelvis weights. Use a
# bounded anatomical region and expand a small patch around measured roots.
def ss(a,b,x):
    t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
v=original[body.name];x,y,z=v.T
w=ss(.52,.78,-y)*(1-ss(.32,.51,abs(x)))*ss(1.86,1.99,z)*(1-ss(2.17,2.27,z))
for root in roots.values():
    d=np.linalg.norm(v-root,axis=1);w=np.maximum(w,1-ss(.025,.115,d))
w=np.clip(w,0,1)
hg=body.vertex_groups["Head"];mg=body.vertex_groups.new(name="Muzzle")
muzzle_ids=[]
for vert,amount in zip(body.data.vertices,w):
    if amount<=1e-6:continue
    h=next((g.weight for g in vert.groups if g.group==hg.index),0)
    transfer=h*float(amount)
    if transfer<1e-7:continue
    hg.add([vert.index],h-transfer,"REPLACE");mg.add([vert.index],transfer,"REPLACE")
    muzzle_ids.append(vert.index)
for o in whiskers:
    o.vertex_groups.clear();g=o.vertex_groups.new(name=o.name+"_Control");g.add(list(range(len(o.data.vertices))),1,"REPLACE")
for o in objects:
    assert np.array_equal(coords(o),original[o.name]),o.name
    assert np.array_equal(np.array([tuple(q.uv) for q in o.data.uv_layers.active.data]),uv[o.name]),o.name
    assert len(o.data.polygons)==topology[o.name]
    assert all(abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in o.data.vertices),o.name
assert len(rig.data.bones)==26 and len(muzzle_ids)>30
def evaluated(o):
    ob=o.evaluated_get(bpy.context.evaluated_depsgraph_get());return coords(ob)
reset();rest={o.name:evaluated(o) for o in objects}
def rotate(name,angle,axis):
    b=rig.pose.bones[name];a=b.bone.matrix_local.to_3x3().inverted()@Vector(axis)
    b.rotation_mode="QUATERNION";b.rotation_quaternion=Quaternion(a.normalized(),math.radians(angle))
def displacement(o):return np.linalg.norm(evaluated(o)-rest[o.name],axis=1)
def ids(o,n,threshold=.65):
    g=o.vertex_groups.get(n)
    if g is None:return np.zeros(0,dtype=int)
    return np.asarray([v.index for v in o.data.vertices if any(x.group==g.index and x.weight>=threshold for x in v.groups)],dtype=int)
scene=bpy.context.scene;cam=scene.camera;center=Vector((0,0,1.8))
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.display.shading.color_type="TEXTURE"
def render(name,d):
    cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
# Numerical functional probes on actual deformed geometry. Static region
# excludes joints intentionally influenced by the moving chain.
probes=[]
def probe(name,ops,targets,static,view=None):
    reset()
    for b,a,ax in ops:rotate(b,a,ax)
    bpy.context.view_layer.update()
    moved={};leak={}
    for obj,group in targets:
        o=bpy.data.objects[obj];i=ids(o,group) if group else np.arange(len(o.data.vertices))
        assert len(i)>0,(name,obj,group)
        moved[obj+"/"+str(group)]={"vertices":int(len(i)),"max":float(displacement(o)[i].max())}
    for obj,group in static:
        o=bpy.data.objects[obj];i=ids(o,group,.999) if group else np.arange(len(o.data.vertices))
        assert len(i)>0,(name,obj,group)
        leak[obj+"/"+str(group)]=float(displacement(o)[i].max())
    assert min(q["max"] for q in moved.values())>.015,(name,moved)
    assert max(leak.values(),default=0)<1e-4,(name,leak)
    probes.append({"name":name,"status":"passed","movement":moved,"static_leakage":leak})
    if view:render(name,view)
    reset()
for name,d in {"rest-three-quarter":(-4,-6,1.3),"rest-front":(0,-6,0),"rest-side":(6,0,0),"rest-back":(0,6,0)}.items():render(name,d)
for tag,other in (("L","R"),("R","L")):
    probe("foreleg-"+tag,[("Shoulder_"+tag,-35,(1,0,0)),("Forearm_"+tag,-20,(1,0,0))],[("FrontArm_"+tag,None)],[("FrontArm_"+other,None),(body.name,None)],(-4,-6,1.3) if tag=="L" else None)
    probe("hindleg-"+tag,[("Hip_"+tag,-18,(1,0,0)),("Shin_"+tag,25,(1,0,0)),("HindPaw_"+tag,-10,(1,0,0))],[(body.name,"Hip_"+tag),(body.name,"HindPaw_"+tag)],[("FrontArm_L",None),("FrontArm_R",None),(body.name,"Head")],(5,-6,1.1) if tag=="R" else None)
probe("head-turn",[("Head",18,(0,0,1))],[(body.name,"Head")]+[(o.name,None) for o in whiskers],[("FrontArm_L",None),("FrontArm_R",None),(body.name,"Pelvis")],(-4,-6,1.3))
for tag,other in (("L","R"),("R","L")):
    probe("ear-"+tag,[("Ear_"+tag,20,(0,1,0))],[(body.name,"Ear_"+tag)],[(body.name,"Ear_"+other),("FrontArm_L",None),("FrontArm_R",None)],(-4,-6,1.3) if tag=="L" else None)
probe("tail-wag",[("Tail",20,(0,0,1))],[(body.name,"Tail")],[(body.name,"Head"),("FrontArm_L",None),("FrontArm_R",None)],(4,6,.9))
# Validate actual root-to-surface distances in sniff and individual whisker
# rotation. The root can be just beneath the surface in the original mesh.
def root_gaps():
    vv=evaluated(body);tree=BVHTree.FromPolygons([Vector(p) for p in vv],[tuple(p.vertices) for p in body.data.polygons],all_triangles=False)
    result={}
    for o in whiskers:
        a=rest[o.name];i=np.argsort(abs(a[:,0]))[:8];p=evaluated(o)[i].mean(0)
        hit=tree.find_nearest(Vector(p));assert hit is not None
        result[o.name]=float(hit[3])
    return result
reset();initial_gaps=root_gaps()
def sniff():
    rotate("Muzzle",5,(1,0,0));rig.pose.bones["Muzzle"].location.y=.035
    for o in whiskers:rotate(o.name+"_Control",8 if "_L_" in o.name else -8,(0,0,1))
    bpy.context.view_layer.update()
sniff();sniff_move=float(displacement(body)[muzzle_ids].max());sniff_gaps=root_gaps()
assert sniff_move>.015 and max(displacement(bpy.data.objects["FrontArm_L"]).max(),displacement(bpy.data.objects["FrontArm_R"]).max())<1e-5
assert max(abs(sniff_gaps[k]-initial_gaps[k]) for k in initial_gaps)<.055,(initial_gaps,sniff_gaps)
render("sniff",(-4,-6,1.3));reset()
for o in whiskers:
    rotate(o.name+"_Control",12,(0,0,1));bpy.context.view_layer.update()
    moved=float(displacement(o).max());others=max(float(displacement(q).max()) for q in whiskers if q!=o)
    assert moved>.015 and others<1e-5 and float(displacement(body).max())<1e-5
    probes.append({"name":o.name+"_independent","status":"passed","tip_displacement":moved,"other_whisker_leakage":others});reset()
# Build a review-only looping sniff action. Keyframes are actual bone
# transforms, export with animation, reset to rest afterward.
scene.frame_start=1;scene.frame_end=48;scene.render.fps=24
animated=["Muzzle"]+[o.name+"_Control" for o in whiskers]
for frame,amount in ((1,0),(7,1),(13,0),(19,.8),(25,0),(48,0)):
    scene.frame_set(frame);reset()
    rotate("Muzzle",5*amount,(1,0,0));rig.pose.bones["Muzzle"].location.y=.035*amount
    for o in whiskers:rotate(o.name+"_Control",(8 if "_L_" in o.name else -8)*amount,(0,0,1))
    for n in animated:
        b=rig.pose.bones[n];b.keyframe_insert(data_path="rotation_quaternion",frame=frame,group=n);b.keyframe_insert(data_path="location",frame=frame,group=n)
assert rig.animation_data and rig.animation_data.action
rig.animation_data.action.name="Rabbit_Sniff_Review"
scene.frame_set(1);bpy.context.view_layer.update()
# Independent rest pose checks and immutable source/UV after animation setup.
for o in objects:
    assert np.array_equal(coords(o),original[o.name])
    assert np.array_equal(np.array([tuple(q.uv) for q in o.data.uv_layers.active.data]),uv[o.name])
bpy.ops.object.select_all(action="DESELECT");rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(out/"rabbit-functional.blend"))
for o in objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(out/"rabbit-functional.glb"),export_format="GLB",use_selection=True,export_animations=True)
raw=(out/"rabbit-functional.glb").read_bytes();n=struct.unpack_from("<I",raw,12)[0];j=json.loads(raw[20:20+n])
pr=[p for m in j["meshes"] for p in m["primitives"]]
assert j.get("skins") and len(j["skins"][0]["joints"])==26
assert j.get("animations") and all({"JOINTS_0","WEIGHTS_0","TEXCOORD_0"}<=set(p["attributes"]) for p in pr)
tri=sum(j["accessors"][p["indices"]]["count"]//3 for p in pr);assert tri==60968
report={"schema":1,"status":"functional_recovery_candidate","source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"triangles":tri,"bones":26,"mesh_objects":9,"muzzle_weighted_vertices":len(muzzle_ids),"whiskers":6,"rest_geometry_unchanged":True,"uv_unchanged":True,"probes":probes,"sniff":{"muzzle_displacement":sniff_move,"root_gaps_rest":initial_gaps,"root_gaps_sniff":sniff_gaps,"animation":j["animations"][0].get("name","sniff")},"artistic_approval":False,"publication_allowed":False,"limitations":["Existing hand-guided V3 geometry; not a new generic reconstruction.","Rear limbs, tail, head and ears deform through skin weights on shared body; forearms are separate meshes.","No complete self-intersection or Roblox runtime test; visual approval and mesh partitioning remain required."]}
(out/"report.json").write_text(json.dumps(report,indent=2)+"\n");print(json.dumps(report),flush=True)
