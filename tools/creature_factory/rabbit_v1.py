"""Rabbit V1 reference-guided candidate. Z-up, -Y forward. No Roblox writes."""
import bpy, math, sys, json, hashlib, bmesh
from pathlib import Path
from mathutils import Vector
from math import sin,cos,pi
root=Path.cwd()
job,out=map(Path,sys.argv[sys.argv.index("--")+1:])
out.mkdir(parents=True,exist_ok=True)
req=json.loads(job.read_text())
refdir=root/"asset-library/references/rabbit-v1"
manifest=json.loads((refdir/"manifest.json").read_text())
assert manifest["status"]=="approved-design-references-verified"
for ref in manifest["references"].values():
    assert hashlib.sha256((refdir/ref["path"]).read_bytes()).hexdigest()==ref["sha256"]
assert req["id"]=="rabbit-v1" and req["whiskers"]["count"]==6
bpy.ops.wm.read_factory_settings(use_empty=True)
parts=[]
def mat(name,rgb):
    m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
    p=m.node_tree.nodes.get("Principled BSDF");p.inputs["Base Color"].default_value=(*rgb,1);p.inputs["Roughness"].default_value=.77
    return m
brown=mat("Fur warm chestnut",(.46,.23,.105))
light=mat("Fur warm highlights",(.57,.31,.15))
cream=mat("Cream muzzle chest paws",(.85,.64,.39))
pink=mat("Ear interior",(.59,.235,.185))
nosemat=mat("Nose",(.56,.17,.12))
dark=mat("Eye rim",(.055,.025,.016))
iris=mat("Iris",(.24,.103,.045))
pupil=mat("Pupil",(.022,.012,.009))
glint=mat("Eye catchlight",(.98,.91,.78))
whisk=mat("Whisker ivory",(.91,.77,.54))
def add(name,v,f,mats,indices=None,smooth=True):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(v,[],f);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    for m in mats:mesh.materials.append(m)
    for p in mesh.polygons:
        p.use_smooth=smooth
        if indices:p.material_index=indices[p.index]
    parts.append(o);return o
def ell(name,c,s,m,rot=(0,0,0),seg=16,rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=c)
    o=bpy.context.object;o.name=name;o.scale=s;o.rotation_euler=rot
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    o.data.materials.append(m)
    for p in o.data.polygons:p.use_smooth=True
    parts.append(o);return o
def loft(name,rows,n=20,patch=None):
    # rows: z, x center, y center, x radius, y radius.
    v=[];f=[];mi=[]
    for z,x,y,rx,ry in rows:
        for i in range(n):
            a=2*pi*i/n;v.append((x+rx*cos(a),y+ry*sin(a),z))
    for j in range(len(rows)-1):
        for i in range(n):
            k=(i+1)%n
            f.append((j*n+i,j*n+k,(j+1)*n+k,(j+1)*n+i))
            a=2*pi*(i+.5)/n;z=(rows[j][0]+rows[j+1][0])/2
            mi.append(1 if patch and patch(z,a) else 0)
    f.append(tuple(reversed(range(n))));mi.append(0)
    f.append(tuple((len(rows)-1)*n+i for i in range(n)));mi.append(0)
    return add(name,v,f,[brown,cream],mi)
def front(a):return abs((a-1.5*pi+pi)%(2*pi)-pi)
# Unified, shaped torso; cream chest and belly are surface colors, not floating shells.
loft("Torso",[(.27,0,.10,.12,.19),(.36,0,.08,.39,.35),(.51,0,.075,.50,.43),(.76,0,.10,.56,.46),(1.01,0,.09,.53,.43),(1.25,0,.03,.43,.37),(1.48,0,-.04,.33,.29),(1.70,0,-.06,.27,.24),(1.83,0,-.06,.13,.13)],24,lambda z,a: front(a)<(.72 if z<.65 else .96 if z<1.45 else .70))
# Broad cheeks, forehead and chin form a single head.
loft("Head",[(1.64,0,-.16,.13,.14),(1.72,0,-.22,.29,.27),(1.83,0,-.25,.43,.39),(1.99,0,-.24,.50,.44),(2.17,0,-.20,.46,.41),(2.35,0,-.15,.37,.33),(2.49,0,-.12,.23,.23),(2.55,0,-.10,.08,.09)],24,lambda z,a:z<1.98 and front(a)<1.10)
# Rounded muzzle lobes, nose and mouth seam.
for s,label in [(-1,"L"),(1,"R")]:
    ell("Muzzle_"+label,(s*.125,-.665,1.90),(.215,.135,.14),cream,seg=16,rings=8)
ell("Nose",(0,-.795,1.985),(.092,.036,.053),nosemat,seg=12,rings=8)
# Ears are sculpted leaf-shaped closed surfaces. Pink interiors follow the same curved profile.
for s,label in [(-1,"L"),(1,"R")]:
    rows=[(2.34,s*.23,-.09,.09,.075),(2.52,s*.29,-.075,.145,.095),(2.75,s*.36,-.045,.175,.105),(3.02,s*.43,-.02,.18,.105),(3.27,s*.47,.015,.14,.08),(3.45,s*.46,.045,.075,.05),(3.52,s*.44,.06,.012,.012)]
    ear=loft("Ear_"+label,rows,16)
    # color continuous inner surface, with a brown perimeter (no coplanar overlay).
    ear.data.materials.append(pink)
    for p in ear.data.polygons:
        if p.index>=96:continue
        j,i=divmod(p.index,16)
        a=2*pi*(i+.5)/16
        if 1<=j<=4 and front(a)<.95:p.material_index=2
    # Eyes: angled toward both sides, dark outline and glossy iris/pupil.
    angle=s*.49
    rot=(0,0,angle)
    ell("EyePatch_"+label,(s*.305,-.490,2.19),(.185,.075,.205),cream,rot,16,10)
    ell("EyeRim_"+label,(s*.329,-.548,2.192),(.143,.060,.163),dark,rot,16,10)
    ell("Iris_"+label,(s*.345,-.588,2.192),(.116,.043,.137),iris,rot,16,10)
    ell("Pupil_"+label,(s*.356,-.620,2.192),(.079,.029,.107),pupil,rot,12,8)
    ell("Catchlight_"+label,(s*.347,-.646,2.245),(.026,.012,.028),glint,rot,8,6)
    # Strong hindquarters and long hind feet; forelegs are short and bent.
    ell("Haunch_"+label,(s*.36,.12,.64),(.30,.38,.46),brown,(.07,s*.10,0),16,10)
    ell("HindFoot_"+label,(s*.30,-.18,.15),(.235,.40,.15),brown,seg=16,rings=10)
    ell("HindToe_"+label,(s*.30,-.425,.135),(.225,.185,.132),cream,seg=16,rings=8)
    ell("UpperArm_"+label,(s*.32,-.18,1.33),(.14,.18,.30),brown,(-.38,s*.18,0),16,10)
    ell("Forearm_"+label,(s*.29,-.41,1.08),(.13,.235,.125),brown,(.42,0,s*.32),16,10)
    ell("ForePaw_"+label,(s*.22,-.53,.96),(.13,.15,.17),cream,(.08,0,s*.12),16,8)
ell("Tail",(0,.49,.70),(.25,.25,.29),cream,(-.2,0,0),16,10)
# Exactly six swept capped tubes, 3/side; no alpha planes, no loose edge strokes.
def tube(name,points,radii,m,sides=8):
    v=[];f=[]
    for i,p in enumerate(points):
        p=Vector(p);t=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
        a=t.cross(Vector((0,0,1))).normalized();b=t.cross(a).normalized()
        for j in range(sides):
            q=p+radii[i]*(a*cos(2*pi*j/sides)+b*sin(2*pi*j/sides));v.append(tuple(q))
    for i in range(len(points)-1):
        for j in range(sides):
            k=(j+1)%sides;f.append((i*sides+j,i*sides+k,(i+1)*sides+k,(i+1)*sides+j))
    f.append(tuple(reversed(range(sides))))
    f.append(tuple((len(points)-1)*sides+j for j in range(sides)))
    return add(name,v,f,[m])
for s,label in [(-1,"L"),(1,"R")]:
    for i,dz in enumerate((.10,.015,-.12)):
        pts=[]
        for j in range(9):
            t=j/8
            pts.append((s*(.205+.53*t),-.755+.035*t+.09*t*t,1.927-i*.035+dz*t-.025*t*t))
        o=tube("Whisker_"+label+"_"+str(i+1),pts,[.009-.005*j/8 for j in range(9)],whisk)
        o["rig_binding"]="Head";o["strand_index"]=i+1
        bm=bmesh.new();bm.from_mesh(o.data);assert all(e.is_manifold for e in bm.edges);bm.free()
# Make UVs and confirm every part is within budget; normals recalculated for closed meshes.
for o in parts:
    bpy.ops.object.select_all(action="DESELECT");o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT");bpy.ops.mesh.normals_make_consistent(inside=False)
    if not o.data.uv_layers:bpy.ops.uv.smart_project()
    bpy.ops.object.mode_set(mode="OBJECT");o.data.calc_loop_triangles()
tri=sum(len(o.data.loop_triangles) for o in parts)
assert 0<tri<=req["triangle_budget"],tri
assert all(o.data.uv_layers for o in parts)
assert len([o for o in parts if o.name.startswith("Whisker_")])==6
pts=[o.matrix_world@v.co for o in parts for v in o.data.vertices]
lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
assert abs(lo[2])<.02 and 3.4<hi[2]<3.7
bpy.ops.object.select_all(action="DESELECT")
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB",use_selection=True)
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH"
scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100;scene.render.film_transparent=True
scene.render.image_settings.file_format="PNG";scene.render.image_settings.color_mode="RGBA"
sh=scene.display.shading;sh.color_type="MATERIAL";sh.light="STUDIO";sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type="BOTH"
scene.world=bpy.data.worlds.new("ReviewWorld");scene.world.color=(.15,.15,.15)
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=4.1
center=Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,(lo[2]+hi[2])/2))
views={"front":(0,-6,0),"back":(0,6,0),"left":(-6,0,0),"right":(6,0,0),"top":(0,0,6),"bottom":(0,0,-6),"three-quarter":(4,-6,1.5)}
for name,d in views.items():
    cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"asset.blend"))
names={o.name for o in parts}
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(out/"asset.glb"))
imported=[o for o in bpy.context.scene.objects if o.type=="MESH"]
for o in imported:o.data.calc_loop_triangles()
assert len(imported)==len(names) and sum(len(o.data.loop_triangles) for o in imported)==tri
assert all(o.data.uv_layers for o in imported)
assert len([o for o in imported if o.name.startswith("Whisker_")])==6
report={"schema":1,"id":"rabbit-v1","state":"review_ready","mode":"authored_reference_guided","triangles":tri,"triangleBudget":req["triangle_budget"],"meshObjects":len(imported),"bounds":{"min":lo,"max":hi},"whiskers":6,"whiskerClosedMeshes":True,"whiskerHeadBindingPlanned":True,"uv":True,"views":list(views),"roundtrip":True,"rigged":False,"texturedAtlas":False,"robloxPublished":False,"artisticApproval":False,"referenceHashes":{k:v["sha256"] for k,v in manifest["references"].items()}}
(out/"report.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps(report))
