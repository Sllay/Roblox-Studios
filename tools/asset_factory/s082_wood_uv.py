"""UV-only Eggydrasil V4 wood extension. Original indexed POSITION/NORMAL triangle
stream and three material groups remain byte-identical. Bake neutral bark in object
space; the separate alpha mask is for optional overlays, never cutout roots."""
import bpy,sys,math,json,struct,hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/"tools/asset_factory"))
from s08_runtime_repack import parse,raw,indices,encode
from s08_prop_intake import tris,sha
source=ROOT/"asset-library/approved/eggydrasil/v8/wood-v4.glb"
out=Path(sys.argv[sys.argv.index("--")+1]).resolve();out.mkdir(parents=True,exist_ok=True)
original=source.read_bytes();d,b=parse(original)
assert tris(d)==14460 and len(d["meshes"])==1 and len(d["meshes"][0]["primitives"])==3
assert all("TEXCOORD_0" not in p["attributes"] for p in d["meshes"][0]["primitives"])
bpy.ops.wm.read_factory_settings(use_empty=True)
verts=[];faces=[];groups=[];streams=[]
for pi,p in enumerate(d["meshes"][0]["primitives"]):
    a=p["attributes"];positions=raw(d,b,a["POSITION"]);normals=raw(d,b,a["NORMAL"]);idx=indices(d,b,p["indices"])
    start=len(verts);start_face=len(faces)
    for row in positions:
        x,y,z=struct.unpack("<fff",row);verts.append((x,-z,y))
    for i in range(0,len(idx),3):faces.append(tuple(start+j for j in idx[i:i+3]));groups.append(pi)
    streams.append((positions,normals,idx,start_face))
mesh=bpy.data.meshes.new("Wood_V4");mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new("Wood_V4",mesh);bpy.context.collection.objects.link(obj)
assert len(mesh.polygons)==len(faces)==14460
for f,expected in zip(mesh.polygons,faces):assert tuple(f.vertices)==expected
img=bpy.data.images.new("BarkNeutral",width=2048,height=2048,alpha=False)
for i in range(3):
    mat=bpy.data.materials.new("BarkNeutral_"+str(i));mat.use_nodes=True;mesh.materials.append(mat)
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;nodes.clear()
    uv=nodes.new("ShaderNodeTexCoord")
    vec=nodes.new("ShaderNodeVectorMath");vec.operation="MULTIPLY";vec.inputs[1].default_value=(40,40,7);links.new(uv.outputs["Generated"],vec.inputs[0])
    noise=nodes.new("ShaderNodeTexNoise");noise.inputs["Scale"].default_value=3;noise.inputs["Detail"].default_value=3;noise.inputs["Roughness"].default_value=.68;links.new(vec.outputs[0],noise.inputs["Vector"])
    grain=nodes.new("ShaderNodeTexVoronoi");grain.feature="DISTANCE_TO_EDGE";grain.inputs["Scale"].default_value=4;links.new(vec.outputs[0],grain.inputs["Vector"])
    mix=nodes.new("ShaderNodeMath");mix.operation="MULTIPLY_ADD";mix.inputs[1].default_value=.7;links.new(noise.outputs["Fac"],mix.inputs[0]);links.new(grain.outputs["Distance"],mix.inputs[2])
    ramp=nodes.new("ShaderNodeValToRGB")
    low,high=[(.29,.79),(.43,.94),(.18,.63)][i]
    ramp.color_ramp.elements[0].position=.08;ramp.color_ramp.elements[0].color=(low,low,low,1)
    ramp.color_ramp.elements[1].position=.72;ramp.color_ramp.elements[1].color=(high,high,high,1)
    links.new(mix.outputs[0],ramp.inputs[0])
    em=nodes.new("ShaderNodeEmission");links.new(ramp.outputs[0],em.inputs[0])
    output=nodes.new("ShaderNodeOutputMaterial");links.new(em.outputs[0],output.inputs["Surface"])
    target=nodes.new("ShaderNodeTexImage");target.image=img;nodes.active=target
for p,i in zip(mesh.polygons,groups):p.material_index=i
obj.select_set(True);bpy.context.view_layer.objects.active=obj
bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.006)
bpy.ops.object.mode_set(mode="OBJECT")
uv=mesh.uv_layers.active.data
assert len(uv)==14460*3
# Smart projection occasionally overlaps a few tiny faces. Detect the exact
# intersecting faces and give them padded charts in a reserved atlas strip.
# No tolerance relaxation, topology change, or face deletion.
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def polygon_area(p):return abs(sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(p,p[1:]+p[:1])))/2 if len(p)>2 else 0
def intersection(p,q):
    if cross(*q)<0:q=q[::-1]
    for a,b in zip(q,q[1:]+q[:1]):
        result=[]
        for s,e in zip(p,p[1:]+p[:1]):
            ds,de=cross(a,b,s),cross(a,b,e)
            if (ds>=0)!=(de>=0):result.append(tuple(s[i]+(e[i]-s[i])*(ds/(ds-de)) for i in range(2)))
            if de>=0:result.append(e)
        p=result
        if not p:return 0
    return polygon_area(p)
def f32(x):return struct.unpack("<f",struct.pack("<f",x))[0]
def audit_uv():
    items=[]
    for f in mesh.polygons:
        pts=[(f32(uv[j].uv.x),f32(1-f32(1-uv[j].uv.y))) for j in f.loop_indices]
        items.append((f.index,pts,min(p[0] for p in pts),max(p[0] for p in pts),min(p[1] for p in pts),max(p[1] for p in pts)))
    items.sort(key=lambda a:a[2]);bad=set();pairs=0
    for i,(idx,p,x0,x1,y0,y1) in enumerate(items):
        for j in range(i+1,len(items)):
            k,q,a,b,c,d=items[j]
            if a>=x1:break
            if c>=y1 or d<=y0:continue
            if intersection(p,q)>1e-10:bad.update((idx,k));pairs+=1
    return bad,pairs
# Reserve rightmost 16% and leave a full bake margin around both regions.
for u in uv:u.uv=(.004+.824*u.uv.x,.004+.824*u.uv.y)
bad,pairs=audit_uv()
print("S082_UV_REPAIR",len(bad),pairs,flush=True)
assert len(bad)<=180,"Unexpected UV chart repair budget"
for n,idx in enumerate(sorted(bad)):
    f=mesh.polygons[idx];loops=list(f.loop_indices);pts=[uv[j].uv.copy() for j in loops]
    lo=(min(p.x for p in pts),min(p.y for p in pts));hi=(max(p.x for p in pts),max(p.y for p in pts))
    span=max(hi[0]-lo[0],hi[1]-lo[1]);assert span>1e-10
    # 6 columns * 40 rows, each 0.026 x 0.024, with 5 px gutters.
    cx=.842+(n%6)*.026;cy=.006+(n//6)*.024
    for j,p in zip(loops,pts):uv[j].uv=(cx+.003+(p.x-lo[0])*.018/span,cy+.003+(p.y-lo[1])*.018/span)
remaining,remaining_pairs=audit_uv()
assert not remaining,(len(remaining),remaining_pairs)
# Rasterize the procedural wood grain in object space into the approved UV
# charts. This avoids the distro Cycles bake path that returned a flat PNG.
# Positions and normals are untouched; only texels are authored.
import numpy as np
from PIL import Image
N=2048
pixels=np.full((N,N),127,dtype=np.uint8)
covered=np.zeros((N,N),dtype=bool)
def grain(points,material):
    x,y,z=points[...,0],points[...,1],points[...,2]
    # Long, irregular fibers; low-frequency warping and finer ridges.
    w=.75*np.sin(.31*z+.43*y)+.48*np.sin(.19*z-.57*x)
    g1=np.sin(3.4*x+2.1*y+w)
    g2=np.sin(7.2*x-5.1*y+.42*z+1.5*np.sin(.2*z+.7*x))
    g3=np.sin(13.7*x+9.3*y+.77*z+.8*np.sin(.29*z))
    ridge=np.maximum(0,np.sin(4.1*x-2.6*y+.21*z+w))**9
    variation=24*g1+14*g2+7*g3-30*ridge+8*np.sin(.75*x+.66*y+.13*z)
    return np.clip([172,194,143][material]+variation,68,241).astype(np.uint8)
for f in mesh.polygons:
    loops=list(f.loop_indices)
    tex=np.array([(uv[k].uv.x*N,(1-uv[k].uv.y)*N) for k in loops],dtype=np.float64)
    pos=np.array([tuple(mesh.vertices[k].co) for k in f.vertices],dtype=np.float64)
    x0=max(0,int(np.floor(tex[:,0].min())));x1=min(N-1,int(np.ceil(tex[:,0].max())))
    y0=max(0,int(np.floor(tex[:,1].min())));y1=min(N-1,int(np.ceil(tex[:,1].max())))
    yy,xx=np.mgrid[y0:y1+1,x0:x1+1];xx=xx+.5;yy=yy+.5
    a,b,c=tex;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
    assert abs(den)>1e-12
    u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den
    v=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den
    w=1-u-v
    inside=(u>=-1e-8)&(v>=-1e-8)&(w>=-1e-8)
    if inside.any():
        xyz=u[inside,None]*pos[0]+v[inside,None]*pos[1]+w[inside,None]*pos[2]
        sub=pixels[y0:y1+1,x0:x1+1];sub[inside]=grain(xyz,f.material_index)
        covered[y0:y1+1,x0:x1+1][inside]=True
    else:
        cxy=tex.mean(axis=0);ix=min(N-1,max(0,int(cxy[0])));iy=min(N-1,max(0,int(cxy[1])))
        if not covered[iy,ix]:
            pixels[iy,ix]=grain(pos.mean(axis=0),f.material_index);covered[iy,ix]=True
painted=int(covered.sum());min_value=int(pixels[covered].min());max_value=int(pixels[covered].max())
assert painted>100000 and max_value-min_value>80,(painted,min_value,max_value)
# Six-pixel nearest-neighbor gutter extension for bilinear/mipmap sampling.
# Never overwrite texels from a different occupied island.
for _ in range(6):
    old=covered.copy()
    for dy,dx in ((0,1),(0,-1),(1,0),(-1,0)):
        sy=slice(max(0,-dy),min(N,N-dy));sx=slice(max(0,-dx),min(N,N-dx))
        ty=slice(max(0,dy),min(N,N+dy));tx=slice(max(0,dx),min(N,N+dx))
        take=old[sy,sx]&~covered[ty,tx]
        pixels[ty,tx][take]=pixels[sy,sx][take];covered[ty,tx][take]=True
Image.fromarray(pixels,"L").convert("RGB").save(out/"bark-neutral.png")
png=(out/"bark-neutral.png").read_bytes()
print("S082_BARK_PIXELS",painted,min_value,max_value,flush=True)
# Add per-corner UV to the exact source streams, retaining primitive order.
buf=bytearray();views=[];access=[]
def view(data,target=None):
    buf.extend(b"\0"*(-len(buf)%4));i=len(views);r={"buffer":0,"byteOffset":len(buf),"byteLength":len(data)}
    if target:r["target"]=target
    views.append(r);buf.extend(data);return i
def acc(data,kind,n,comp,target,minmax=None):
    a={"bufferView":view(data,target),"componentType":comp,"count":n,"type":kind}
    if minmax:a.update(min=minmax[0],max=minmax[1])
    access.append(a);return len(access)-1
primitives=[];source_hash=hashlib.sha256();target_hash=hashlib.sha256()
for pi,(positions,normals,idx,start_face) in enumerate(streams):
    rows=[[],[],[]];remap={};new_idx=[]
    for j,i in enumerate(idx):
        f=mesh.polygons[start_face+j//3];loop=f.loop_indices[j%3];u,v=uv[loop].uv
        assert -1e-6<=u<=1.000001 and -1e-6<=v<=1.000001
        # Blender UV origin is bottom-left; GLTF texture origin is top-left.
        uvbytes=struct.pack("<ff",u,1-v)
        key=(i,uvbytes)
        if key not in remap:
            remap[key]=len(rows[0]);rows[0].append(positions[i]);rows[1].append(normals[i]);rows[2].append(uvbytes)
        new_idx.append(remap[key]);source_hash.update(positions[i]);source_hash.update(normals[i])
    xyz=[struct.unpack("<fff",x) for x in rows[0]]
    pos=acc(b"".join(rows[0]),"VEC3",len(xyz),5126,34962,([min(x[k] for x in xyz) for k in range(3)],[max(x[k] for x in xyz) for k in range(3)]))
    normal=acc(b"".join(rows[1]),"VEC3",len(xyz),5126,34962)
    tex=acc(b"".join(rows[2]),"VEC2",len(xyz),5126,34962)
    ind=acc(b"".join(struct.pack("<I",i) for i in new_idx),"SCALAR",len(new_idx),5125,34963)
    primitives.append({"attributes":{"POSITION":pos,"NORMAL":normal,"TEXCOORD_0":tex},"indices":ind,"material":pi,"mode":4})
    for i in new_idx:target_hash.update(rows[0][i]);target_hash.update(rows[1][i])
assert source_hash.digest()==target_hash.digest()
im=view(png)
doc={"asset":{"version":"2.0","generator":"Black Islands S08.2 UV-only wood"},"scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"name":"Wood_V4","mesh":0}],"meshes":[{"name":"Wood_V4","primitives":primitives}],"materials":[{"name":"Bark_"+str(i),"doubleSided":True,"pbrMetallicRoughness":{"baseColorTexture":{"index":0},"metallicFactor":0,"roughnessFactor":.86}} for i in range(3)],"textures":[{"source":0,"sampler":0}],"samplers":[{"wrapS":33071,"wrapT":33071}],"images":[{"bufferView":im,"mimeType":"image/png","name":"BarkNeutral"}],"accessors":access,"bufferViews":views}
result=encode(doc,buf);dd,bb=parse(result);assert tris(dd)==14460
# Independent readback of exported indexed positions/normals.
h=hashlib.sha256()
for p in dd["meshes"][0]["primitives"]:
    a=p["attributes"];pos=raw(dd,bb,a["POSITION"]);norm=raw(dd,bb,a["NORMAL"])
    for i in indices(dd,bb,p["indices"]):h.update(pos[i]);h.update(norm[i])
assert h.digest()==source_hash.digest()
(out/"wood-v4-uv.glb").write_bytes(result)
(out/"manifest.json").write_text(json.dumps({"sourceSha256":sha(original),"geometryStreamSha256":h.hexdigest(),"triangles":14460,"materialGroups":3,"geometryUnchanged":True,"uv":"TEXCOORD_0","glbSha256":sha(result),"atlasSha256":sha(png),"repairedUVFaces":len(bad),"textureCoveredPixels":painted,"textureRange":[min_value,max_value],"texturePolicy":"neutral bark plus separate RGBA tint-mask colormap; no transparency of wood"},indent=2))
