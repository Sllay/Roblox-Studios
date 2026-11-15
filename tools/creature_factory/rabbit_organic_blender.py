"""Build and render the pixel-conditioned Rabbit V2. No Roblox writes.
Master surface comes from the verified reference sheet, not primitive anatomy.
"""
import bpy,bmesh,math,sys,json,struct,zlib,hashlib
from pathlib import Path
import numpy as np
from mathutils import Vector
out=Path(sys.argv[sys.argv.index("--")+1])
data=np.load(out/"reconstruction.npz")
cal=json.loads((out/"calibration.json").read_text());maps=cal["maps"]
bpy.ops.wm.read_factory_settings(use_empty=True)
def mesh_obj(name,v,f):
    m=bpy.data.meshes.new(name);m.from_pydata(v.tolist() if hasattr(v,"tolist") else v,[],f.tolist() if hasattr(f,"tolist") else f);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o)
    for p in m.polygons:p.use_smooth=True
    return o
def active(o):
    bpy.ops.object.select_all(action="DESELECT");o.select_set(True);bpy.context.view_layer.objects.active=o
def recalc(o):
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
def topology(o):
    bm=bmesh.new();bm.from_mesh(o.data);bad=sum(not e.is_manifold for e in bm.edges);bm.free();return bad
master=mesh_obj("Rabbit_Organic_Master",data["vertices"],data["faces"]);recalc(master)
assert topology(master)==0,"Non-manifold sculpt master"
# Preserve the dense original as a distinct .blend, not a hidden runtime mesh.
bpy.ops.wm.save_as_mainfile(filepath=str(out/"sculpt-master.blend"))
body=master;body.name="Rabbit_Organic_Body"
active(body);mod=body.modifiers.new("Mobile shape-preserving reduction","DECIMATE")
mod.ratio=min(1,25000/len(body.data.polygons));mod.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=mod.name);recalc(body)
assert topology(body)==0,"Non-manifold reduced body"
def unwrap(o):
    active(o);bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.012)
    bpy.ops.object.mode_set(mode="OBJECT")
unwrap(body)
body.data.calc_loop_triangles()
P=np.array([tuple(v.co) for v in body.data.vertices],np.float32)
N=np.array([tuple(v.normal) for v in body.data.vertices],np.float32)
F=np.array([tuple(t.vertices) for t in body.data.loop_triangles],np.int32)
np.savez_compressed(out/"runtime-mesh.npz",vertices=P,faces=F)
def bilinear(img,u,v):
    u=np.clip(u,0,img.shape[1]-1.001);v=np.clip(v,0,img.shape[0]-1.001)
    x=u.astype(int);y=v.astype(int);a=(u-x)[:,None];b=(v-y)[:,None]
    return ((1-a)*(1-b)*img[y,x]+a*(1-b)*img[y,x+1]+(1-a)*b*img[y+1,x]+a*b*img[y+1,x+1])
colors={k:data["color_"+k].astype(np.float32)/255 for k in maps}
def project(p,n):
    n=n/np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-8)
    # Face-normal weighted projection from actual original reference pixels.
    # Steeper weighting preserves the eyes and muzzle rather than averaging them away.
    weights=np.column_stack([np.maximum(-n[:,1],0),np.maximum(n[:,0],0),np.maximum(-n[:,0],0),np.maximum(n[:,1],0)])**5
    weights+=.0008;weights/=weights.sum(axis=1,keepdims=True)
    c=np.zeros((len(p),3),np.float32)
    for i,k in enumerate(("front","right","left","back")):
        a=maps[k];u=a["center"]+a["sign"]*p[:,a["axis"]]/a["scale"];v=a["bottom"]-p[:,2]/a["scale"]
        c+=bilinear(colors[k],u,v)*weights[:,i,None]
    return np.clip(c,0,1)
def png_rgb(path,img):
    h,w,_=img.shape
    def chunk(t,d):return struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d)&0xffffffff)
    payload=b"".join(b"\0"+r.tobytes() for r in img)
    path.write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",w,h,8,2,0,0,0))+chunk(b"IDAT",zlib.compress(payload,6))+chunk(b"IEND",b""))
# Bake original concept colors per texel, not merely per vertex. A real UV atlas.
size=2048
atlas=np.zeros((size,size,3),np.uint8);filled=np.zeros((size,size),bool)
uv=np.array([tuple(l.uv) for l in body.data.uv_layers.active.data],np.float32)*(size-1)
for tri in body.data.loop_triangles:
    q=uv[list(tri.loops)];ids=list(tri.vertices)
    lo=np.maximum(np.floor(q.min(axis=0)).astype(int),0);hi=np.minimum(np.ceil(q.max(axis=0)).astype(int),size-1)
    if np.any(hi<lo):continue
    x,y=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1))
    a,b,c=q;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
    if abs(den)<1e-8:continue
    w0=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/den
    w1=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/den
    w2=1-w0-w1;mask=(w0>=-.001)&(w1>=-.001)&(w2>=-.001)
    if not mask.any():continue
    w=np.stack([w0[mask],w1[mask],w2[mask]],axis=1)
    rgb=project(w@P[ids],w@N[ids])
    atlas[y[mask],x[mask]]=np.rint(rgb*255).astype(np.uint8);filled[y[mask],x[mask]]=True
coverage=float(filled.mean());assert coverage>.05,coverage
# Extrude chart colors into an 8-pixel gutter to prevent bilinear seams.
for _ in range(8):
    for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
        sh=np.roll(filled,(dy,dx),axis=(0,1));new=sh&~filled
        if dy==1:new[0]=False
        if dy==-1:new[-1]=False
        if dx==1:new[:,0]=False
        if dx==-1:new[:,-1]=False
        atlas[new]=np.roll(atlas,(dy,dx),axis=(0,1))[new];filled[new]=True
png_rgb(out/"concept-albedo.png",atlas[::-1])
im=bpy.data.images.load(str(out/"concept-albedo.png"));im.pack()
mat=bpy.data.materials.new("Rabbit_Reference_Albedo");mat.use_nodes=True
nodes=mat.node_tree.nodes;bs=nodes.get("Principled BSDF");bs.inputs["Roughness"].default_value=.82
tex=nodes.new("ShaderNodeTexImage");tex.image=im;nodes.active=tex
mat.node_tree.links.new(tex.outputs["Color"],bs.inputs["Base Color"])
body.data.materials.append(mat)
# Vertex colors for fast Workbench review; the exported material uses the baked atlas.
attr=body.data.color_attributes.new(name="ConceptColor",type="FLOAT_COLOR",domain="POINT")
rgb=project(P,N)
rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
attr.data.foreach_set("color",np.column_stack([rgb,np.ones(len(rgb))]).astype(np.float32).ravel())
body.data.color_attributes.active_color=attr
# Six curves traced from the front illustration, grounded by ray casting the actual surface.
# Geometry is closed, tapered and independent for reliable head weighting.
wm=bpy.data.materials.new("Whisker_Ivory");wm.diffuse_color=(.88,.73,.52,1);wm.use_nodes=True
wm.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=wm.diffuse_color
def front_world(x,zpix):
    a=maps["front"];return ((x-a["center"])*a["scale"],(a["bottom"]-zpix)*a["scale"])
def tube(name,pts):
    vs=[];fs=[];sides=8
    for i,p in enumerate(pts):
        t=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
        u=t.cross(Vector((0,0,1))).normalized();w=t.cross(u).normalized()
        r=.008-.004*i/(len(pts)-1)
        for j in range(sides):vs.append(tuple(p+r*(u*math.cos(2*math.pi*j/sides)+w*math.sin(2*math.pi*j/sides))))
    for i in range(len(pts)-1):
        for j in range(sides):
            k=(j+1)%sides;fs.append((i*sides+j,i*sides+k,(i+1)*sides+k,(i+1)*sides+j))
    fs.extend([tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+j for j in range(sides))])
    o=mesh_obj(name,vs,fs);recalc(o);assert topology(o)==0
    o.data.materials.append(wm);unwrap(o);o["rig_binding"]="Head"
    return o
whiskers=[]
for s,tag in [(-1,"L"),(1,"R")]:
    for i,(rootpx,endpx,dy) in enumerate([( (116,212),(49,204),.035),((114,216),(50,218),.06),((113,222),(61,237),.10)]):
        def mirror(p):return p if s<0 else (260-p[0],p[1])
        rx,rz=front_world(*mirror(rootpx));ex,ez=front_world(*mirror(endpx))
        hit,loc,_,_=body.ray_cast(Vector((rx,-3,rz)),Vector((0,1,0)))
        assert hit,(tag,i,rx,rz)
        pts=[]
        for j in range(13):
            t=j/12
            pts.append(Vector((rx+(ex-rx)*t,loc.y-.006+dy*t*t,rz+(ez-rz)*t+.025*math.sin(math.pi*t))))
        whiskers.append(tube("Whisker_"+tag+"_"+str(i+1),pts))
parts=[body]+whiskers
def glb_counts(path):
    raw=path.read_bytes();assert raw[:4]==b"glTF"
    length,typ=struct.unpack_from("<II",raw,12);assert typ==0x4e4f534a
    j=json.loads(raw[20:20+length]);a=j["accessors"]
    prim=[p for m in j["meshes"] for p in m["primitives"]]
    return sum(a[p["attributes"]["POSITION"]]["count"] for p in prim),sum(a[p["indices"]]["count"]//3 for p in prim if "indices" in p)
active(body)
for o in parts:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB",use_selection=True)
verts,tris=glb_counts(out/"asset.glb")
assert verts<=20000,(verts,"exported vertex budget")
assert len(whiskers)==6
# Render color, clay, and all directions. Workbench texture mode displays the real atlas.
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH"
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format="PNG";scene.render.image_settings.color_mode="RGBA"
sh=scene.display.shading;sh.color_type="TEXTURE";sh.light="STUDIO";sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type="BOTH"
scene.world=bpy.data.worlds.new("ReviewWorld");scene.world.color=(.15,.15,.15)
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=4.15
center=Vector((0,0,1.8))
views={"front":(0,-6,0),"right":(6,0,0),"left":(-6,0,0),"back":(0,6,0),"top":(0,0,6),"bottom":(0,0,-6),"three-quarter":(4,-6,1.3)}
def render(name,d,kind):
    sh.color_type=kind;cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
for name,d in views.items():render(name,d,"TEXTURE")
for name in ("front","right","three-quarter"):render("clay-"+name,views[name],"SINGLE")
sh.color_type="TEXTURE";bpy.ops.wm.save_as_mainfile(filepath=str(out/"asset.blend"))
# Actual GLB roundtrip; verify count, UV, and all six named strands.
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(out/"asset.glb"))
imported=[o for o in bpy.context.scene.objects if o.type=="MESH"]
assert len([o for o in imported if o.name.startswith("Whisker_")])==6
assert all(o.data.uv_layers for o in imported)
for o in imported:o.data.calc_loop_triangles()
assert sum(len(o.data.loop_triangles) for o in imported)==tris
report={"schema":2,"id":"rabbit-v2","category":"creature","state":"pending_silhouette_audit","method":cal["method"],
 "sourceReferences":cal["source"],"masterVertices":cal["masterVertices"],"masterTriangles":cal["masterTriangles"],
 "bodyVertices":len(P),"exportedVertices":verts,"vertexBudget":20000,"triangles":tris,"whiskers":6,
 "whiskerClosedMeshes":True,"whiskerHeadBindingPlanned":True,"uv":True,"atlasSize":2048,"atlasCoverage":coverage,
 "texture":"reference-projected candidate albedo; not final hand-painted texture","views":list(views),"clayViews":["front","right","three-quarter"],
 "roundtrip":True,"rigged":False,"artisticApproval":False,"robloxPublished":False,
 "limitations":["Illustrated views are not exact camera-calibrated photographs.","Silhouettes constrain exterior, not all concavities or occluded anatomy.","Reduction is candidate topology, not final deformation retopology.","Projection may contain baked illumination and view seams."]}
(out/"report.json").write_text(json.dumps(report,indent=2)+"\n");print(json.dumps(report),flush=True)
