"""Finish the learned rabbit mesh in Blender; six explicit whiskers.
The body is learned geometry and a baked neural color atlas, not primitives.
"""
import bpy,bmesh,math,sys,json,struct
from pathlib import Path
from mathutils import Vector
import numpy as np
out=Path(sys.argv[sys.argv.index("--")+1])
data=np.load(out/"neural-mesh.npz")
report=json.loads((out/"neural-report.json").read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
def mesh_obj(name,v,f):
    m=bpy.data.meshes.new(name);m.from_pydata(v.tolist() if hasattr(v,"tolist") else v,[],f.tolist() if hasattr(f,"tolist") else f);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o)
    for p in m.polygons:p.use_smooth=True
    return o
def activate(o):
    bpy.ops.object.select_all(action="DESELECT");o.select_set(True);bpy.context.view_layer.objects.active=o
def topo(o,fix=False):
    bm=bmesh.new();bm.from_mesh(o.data)
    if fix:bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data)
    bad=sum(not e.is_manifold for e in bm.edges);bm.free();o.data.update()
    return bad
# Polish the original learned surface, not the distorted cross-section fit.
sys.path.insert(0,str(Path(__file__).resolve().parent))
from rabbit_mesh_repair import repair
from mathutils.kdtree import KDTree
v,f,loops,repair_info=repair(data["vertices"],data["faces"],data["loop_uv"])
original=v.copy()
master=mesh_obj("Rabbit_Neural_Master",v,f);assert topo(master,True)==0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"sculpt-master.blend"))
bpy.data.objects.remove(master,do_unlink=True)
z=v[:,2].astype(np.float64)
knots=np.array([0,.25,.55,.9,1.25,1.55,1.85,2.10,2.35,2.60,3.05,3.60])
yscale=np.array([.95,.91,.80,.78,.78,.82,.94,1.10,1.02,.95,.98,.98])
yshift=np.array([.02,.04,.07,-.02,.04,.16,.26,.38,.38,.46,.60,.60])
def smooth_curve(x,k,y):
    i=np.clip(np.searchsorted(k,x,side="right")-1,0,len(k)-2)
    t=np.clip((x-k[i])/(k[i+1]-k[i]),0,1)
    return y[i]+(y[i+1]-y[i])*(t*t*(3-2*t))
theta=math.radians(-7)
x=v[:,0].copy();y=v[:,1].copy()
v[:,0]=x*math.cos(theta)-y*math.sin(theta)
v[:,1]=x*math.sin(theta)+y*math.cos(theta)
v[:,1]=v[:,1]*smooth_curve(z,knots,yscale)+smooth_curve(z,knots,yshift)
def bump(x,c,w):return np.exp(-((x-c)/w)**2)
v[:,1]-=.065*bump(z,1.57,.24)*bump(v[:,1],.12,.36)
v[:,1]-=.055*bump(z,.90,.39)*np.clip((v[:,1]-.30)/.55,0,1)
# Each ear is a distinct connected region above the roots. Label on the original
# topology, not by x sign: the learned right ear crosses the sagittal plane.
edges=np.unique(np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1),axis=0)
upper=z>2.70;parent=np.arange(len(v),dtype=np.int32)
def find(i):
    while parent[i]!=i:
        parent[i]=parent[parent[i]];i=parent[i]
    return i
for a,b in edges[upper[edges].all(axis=1)]:
    a,b=find(a),find(b)
    if a!=b:parent[b]=a
labels=np.array([find(i) for i in range(len(v))]);groups=[]
for label in np.unique(labels[upper]):
    ids=np.flatnonzero(upper&(labels==label))
    if len(ids)>100:groups.append(ids)
assert len(groups)==2,"Expected two distinct learned ears"
groups.sort(key=lambda ids:float(original[ids,0].mean()))
weight=np.zeros(len(v));weight[groups[0]]=-1;weight[groups[1]]=1
fixed=upper|(z<2.50)
ii=np.r_[edges[:,0],edges[:,1]];jj=np.r_[edges[:,1],edges[:,0]]
dd=np.bincount(ii,minlength=len(v));assert np.all(dd>0)
for _ in range(180):
    avg=np.bincount(ii,weights=weight[jj],minlength=len(v))/dd
    weight[~fixed]=avg[~fixed]
# Move the ear interiors away from center and narrow the upper outer edges.
# The transition is harmonic through the root; no detached or primitive ears.
v[:,0]+=weight*(.17-.24*(weight*v[:,0]-.32))
right_ear_min=float(v[groups[1],0].min())
assert right_ear_min>.035,("right ear crosses symmetry plane",right_ear_min)
body=mesh_obj("Rabbit_Neural_Body",v,f)
# Bilateral symmetry from the more intact learned half, with a welded seam.
bm=bmesh.new();bm.from_mesh(body.data)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
    dist=.000001,plane_co=(0,0,0),plane_no=(1,0,0),clear_inner=True,clear_outer=False)
for q in bm.verts:
    if abs(q.co.x)<.000005:q.co.x=0
bm.to_mesh(body.data);bm.free();body.data.update()
activate(body)
mir=body.modifiers.new("Anatomical symmetry","MIRROR")
mir.use_axis[0]=True;mir.use_axis[1]=False;mir.use_axis[2]=False
mir.use_mirror_merge=True;mir.merge_threshold=.00001
bpy.ops.object.modifier_apply(modifier=mir.name)
assert topo(body,True)==0,"Symmetry seam must be closed"
# Weighted Taubin relaxation: shoulders and rump; preserve ears, toes and muzzle.
m=body.data
p=np.array([tuple(q.co) for q in m.vertices],dtype=np.float64)
e=np.array([tuple(q.vertices) for q in m.edges],dtype=np.int32)
i=np.r_[e[:,0],e[:,1]];j=np.r_[e[:,1],e[:,0]]
deg=np.bincount(i,minlength=len(p)).astype(np.float64);assert np.all(deg>0)
w=.38+.42*bump(p[:,2],1.50,.40)+.18*bump(p[:,2],.84,.40)
w*=1-.40*bump(p[:,2],2.10,.24)
w*=1-.40*bump(p[:,2],3.25,.36)
w*=1-.35*bump(p[:,2],.14,.17)
start=p.copy()
for _ in range(22):
    for fac in (.46,-.48):
        avg=np.column_stack([np.bincount(i,weights=p[j,k],minlength=len(p))/deg for k in range(3)])
        p+=fac*w[:,None]*(avg-p)
p[:,2]-=p[:,2].min()
m.vertices.foreach_set("co",p.astype(np.float32).ravel());m.update()
assert topo(body,True)==0
# Provisional colors only: infer region membership from source, replace baked color
# with clean swatches. No neural texture connected to the final material.
im=bpy.data.images.load(str(out/"neural-albedo.png"))
width,height=im.size
pixels=np.empty(width*height*4,dtype=np.float32);im.pixels.foreach_get(pixels)
pixels=pixels.reshape(height,width,4)
u=np.clip((loops[:,:,0]*(width-1)).astype(int),0,width-1)
vv=np.clip((loops[:,:,1]*(height-1)).astype(int),0,height-1)
samples=pixels[vv,u,:3]
c=np.zeros((len(v),3),dtype=np.float64);n=np.zeros(len(v))
np.add.at(c,f.ravel(),samples.reshape(-1,3));np.add.at(n,f.ravel(),1);c/=np.maximum(n[:,None],1)
# Blender's float image buffer may be linear; byte PNG values are sRGB.
# Use the image's actual storage type to avoid applying gamma twice.
if im.is_float:
    c=np.where(c<=.0031308,12.92*c,1.055*np.maximum(c,0)**(1/2.4)-.055)
tree=KDTree(len(v))
for idx,co in enumerate(v):tree.insert(Vector(co),idx)
tree.balance()
ids=np.array([tree.find(Vector((abs(q[0]),q[1],q[2])))[1] for q in p])
# Use only the learned eye location as a landmark, never the source's mottled
# colors. All other regions are defined by clean, symmetric geometric masks.
def smoothstep(lo,hi,x):
    t=np.clip((x-lo)/(hi-lo),0,1);return t*t*(3-2*t)
xx=np.abs(p[:,0]);yy=p[:,1];hh=p[:,2]
def band(x,lo,hi,fade=.035):
    return smoothstep(lo-fade,lo,x)*(1-smoothstep(hi,hi+fade,x))
chest=band(hh,.45,1.86,.09)*(1-smoothstep(.23,.35,xx))*(1-smoothstep(-.28,-.14,yy))
muzzle=band(hh,1.94,2.20,.045)*(1-smoothstep(.29,.40,xx))*(1-smoothstep(-.53,-.42,yy))
feet=(1-smoothstep(.19,.29,hh))*(1-smoothstep(-.22,-.08,yy))
tail=band(hh,.62,1.23,.08)*smoothstep(.57,.70,yy)
cream=np.maximum.reduce([chest,muzzle,feet,tail])
# Ear paint is intentionally minimal: inner front surface, no photographic bake.
ear_center=.42+.14*np.clip((hh-2.72)/.75,0,1)
ear=band(hh,2.78,3.52,.055)*(1-smoothstep(.11,.21,np.abs(xx-ear_center)))
ear*=1-smoothstep(.02,.14,yy)
# Detect a single eye landmark from the original source; paint a filled clean eye.
red=c[:,0]
eye_ids=np.flatnonzero((original[:,2]>2.18)&(original[:,2]<2.50)&(original[:,0]>.13)&(original[:,1]<-.48)&(red<.38))
if len(eye_ids)>15:ec=np.median(v[eye_ids],axis=0)
else:ec=np.array([.29,-.43,2.32])
eye_dist=((xx-abs(ec[0]))/.115)**2+((hh-ec[2])/.145)**2
eye=(1-smoothstep(.78,1.05,eye_dist))*(1-smoothstep(ec[1]+.10,ec[1]+.20,yy))
rim=(1-smoothstep(1.1,1.55,eye_dist))*(1-smoothstep(ec[1]+.10,ec[1]+.20,yy))
nose_dist=(xx/.085)**2+((hh-2.14)/.065)**2
nose=(1-smoothstep(.75,1.05,nose_dist))*(1-smoothstep(-.56,-.45,yy))
def mix(a,b,w):return a*(1-w[:,None])+np.asarray(b)*w[:,None]
rgb=np.tile([.66,.39,.20],(len(p),1))
rgb=mix(rgb,[.93,.78,.55],cream);rgb=mix(rgb,[.82,.42,.37],ear)
rgb=mix(rgb,[.87,.69,.44],rim);rgb=mix(rgb,[.12,.055,.035],eye);rgb=mix(rgb,[.82,.40,.35],nose)
lin=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
attr=m.color_attributes.new(name="BasePalette",type="FLOAT_COLOR",domain="POINT")
attr.data.foreach_set("color",np.column_stack([lin,np.ones(len(p))]).astype(np.float32).ravel())
m.color_attributes.active_color=attr
mat=bpy.data.materials.new("Rabbit_Clean_BasePalette");mat.use_nodes=True
bs=mat.node_tree.nodes.get("Principled BSDF");bs.inputs["Roughness"].default_value=.83
vc=mat.node_tree.nodes.new("ShaderNodeVertexColor");vc.layer_name="BasePalette"
mat.node_tree.links.new(vc.outputs["Color"],bs.inputs["Base Color"])
body.data.materials.append(mat)
# New UV layout for later artistic painting.
activate(body);bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.012)
bpy.ops.object.mode_set(mode="OBJECT")
body.data.calc_loop_triangles()
np.savez_compressed(out/"runtime-mesh.npz",vertices=np.array([tuple(q.co) for q in body.data.vertices],np.float32),
    faces=np.array([tuple(t.vertices) for t in body.data.loop_triangles],np.int32))
report["polish"]={"source":"unfitted neural checkpoint","symmetry":"positive X half mirrored and welded",
    "profile":"bounded smooth anatomical deformation","shoulder":"localized relaxation and weighted Taubin smoothing",
    "palette":"geometric clean swatches, no baked illumination","freshUV":True,
    "earMinimumXBeforeMirror":right_ear_min,"eyeLandmark":list(map(float,ec)),
    "microscopicRepair":repair_info,"maxSmoothingDisplacement":float(np.max(np.linalg.norm(p-start,axis=1))),
    "bodyVertices":len(body.data.vertices),"bodyTriangles":len(body.data.loop_triangles)}
# Ground the six whisker roots directly on the learned muzzle surface.
wm=bpy.data.materials.new("Whisker_Ivory");wm.diffuse_color=(.83,.69,.49,1);wm.use_nodes=True
wm.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=wm.diffuse_color
def tube(name,pts):
    v=[];f=[];n=8
    for i,p in enumerate(pts):
        t=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()
        a=t.cross(Vector((0,0,1))).normalized();b=t.cross(a).normalized();r=.008-.004*i/(len(pts)-1)
        for j in range(n):v.append(tuple(p+r*(a*math.cos(j*2*math.pi/n)+b*math.sin(j*2*math.pi/n))))
    for i in range(len(pts)-1):
        for j in range(n):
            k=(j+1)%n;f.append((i*n+j,i*n+k,(i+1)*n+k,(i+1)*n+j))
    f.extend([tuple(reversed(range(n))),tuple((len(pts)-1)*n+j for j in range(n))])
    o=mesh_obj(name,v,f);assert topo(o,True)==0;o.data.materials.append(wm)
    activate(o);bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT");bpy.ops.uv.smart_project(island_margin=.01);bpy.ops.object.mode_set(mode="OBJECT")
    ca=o.data.color_attributes.new(name="BasePalette",type="FLOAT_COLOR",domain="POINT");ca.data.foreach_set("color",np.tile(np.array([.83,.69,.49,1],np.float32),len(o.data.vertices)));o.data.color_attributes.active_color=ca
    o["rig_binding"]="Head";return o
def hit_root(x,z):
    # Use nearby sampling only if the exact reference landmark misses the surface.
    for dx,dz in [(0,0),(0,.03),(0,-.03),(.025,0),(-.025,0),(0,.06),(0,-.06),(.05,0),(-.05,0)]:
        hit,loc,_,_=body.ray_cast(Vector((x+dx,-4,z+dz)),Vector((0,1,0)))
        if hit:return loc
    raise RuntimeError("Whisker landmark has no muzzle surface")
whiskers=[];rootloc=[]
for s,tag in [(-1,"L"),(1,"R")]:
    for i,(x,z,ex,ez,dy) in enumerate([(.17,2.12,.68,2.16,.040),(.19,2.08,.66,2.06,.055),(.21,2.04,.58,1.91,.075)]):
        loc=hit_root(s*x,z);rootloc.append(list(loc))
        pts=[]
        for j in range(13):
            t=j/12
            xx=loc.x+(s*ex-loc.x)*t;zz=loc.z+(ez-loc.z)*t+.016*math.sin(math.pi*t)
            yy=loc.y+.008+dy*t*t
            if j>0:
                hit,surf,_,_=body.ray_cast(Vector((xx,-4,zz)),Vector((0,1,0)))
                if hit:yy=min(yy,surf.y-.013)
            pts.append(Vector((xx,yy,zz)))
        whiskers.append(tube("Whisker_"+tag+"_"+str(i+1),pts))
parts=[body]+whiskers
def glb_counts(path):
    raw=path.read_bytes();assert raw[:4]==b"glTF";n,t=struct.unpack_from("<II",raw,12);assert t==0x4e4f534a
    j=json.loads(raw[20:20+n]);a=j["accessors"];p=[p for m in j["meshes"] for p in m["primitives"]]
    return sum(a[x["attributes"]["POSITION"]]["count"] for x in p),sum(a[x["indices"]]["count"]//3 for x in p if "indices" in x)
activate(body)
for o in parts:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB",use_selection=True)
verts,tris=glb_counts(out/"asset.glb")
# Review asset has no project vertex/triangle ceiling. Platform compliance is
# measured and reported independently, never hidden by automatic decimation.
mesh_triangles={}
for o in parts:
    o.data.calc_loop_triangles()
    mesh_triangles[o.name]=len(o.data.loop_triangles)
platform_limit=20000
oversized={name:n for name,n in mesh_triangles.items() if n>platform_limit}
print("full resolution review",verts,tris,"Roblox oversized meshes",oversized,flush=True)
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH"
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format="PNG";scene.render.image_settings.color_mode="RGBA"
sh=scene.display.shading;sh.color_type="VERTEX";sh.light="STUDIO";sh.show_shadows=False;sh.show_cavity=False
try:sh.studio_light="paint.sl"
except Exception:pass
scene.world=bpy.data.worlds.new("ReviewWorld");scene.world.color=(.15,.15,.15)
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=4.15
center=Vector((0,0,1.8))
views={"front":(0,-6,0),"right":(6,0,0),"left":(-6,0,0),"back":(0,6,0),"top":(0,0,6),"bottom":(0,0,-6),"three-quarter":(-4,-6,1.3)}
def render(name,d,kind):
    sh.color_type=kind;cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
for name,d in views.items():render(name,d,"VERTEX")
for name in ("front","right","three-quarter"):render("clay-"+name,views[name],"SINGLE")
sh.color_type="VERTEX";bpy.ops.wm.save_as_mainfile(filepath=str(out/"asset.blend"))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(out/"asset.glb"))
objs=[o for o in bpy.context.scene.objects if o.type=="MESH"]
assert len([o for o in objs if o.name.startswith("Whisker_")])==6
assert all(o.data.uv_layers for o in objs)
for o in objs:o.data.calc_loop_triangles()
assert sum(len(o.data.loop_triangles) for o in objs)==tris
report.update({"id":"rabbit-v3-polish","state":"pending_silhouette_audit","atlasSize":None,"atlasCoverage":None,"texture":"provisional vertex colors; future painting pending","exportedVertices":verts,"vertexBudget":None,"triangles":tris,
 "geometryPolicy":"unrestricted_artistic_candidate","referenceTriangleTarget":50000,
 "meshTriangles":mesh_triangles,"robloxPerMeshTriangleLimit":platform_limit,
 "robloxOversizedMeshes":oversized,"robloxGeometryReady":not bool(oversized),
 "runtimePackagingRequired":bool(oversized),
 "whiskers":6,"whiskerClosedMeshes":True,"whiskerRootPositions":rootloc,"whiskerHeadBindingPlanned":True,
 "uv":True,"roundtrip":True,"views":list(views),"clayViews":["front","right","three-quarter"],"artisticApproval":False,"robloxPublished":False})
(out/"report.json").write_text(json.dumps(report,indent=2)+"\n");print(json.dumps(report),flush=True)
