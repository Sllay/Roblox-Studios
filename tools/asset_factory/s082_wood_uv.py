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
scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=8
scene.render.bake.margin=6;scene.render.bake.use_clear=True
bpy.ops.object.bake(type="EMIT")
img.filepath_raw=str(out/"bark-neutral.png");img.file_format="PNG";img.save()
png=(out/"bark-neutral.png").read_bytes()
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
(out/"manifest.json").write_text(json.dumps({"sourceSha256":sha(original),"geometryStreamSha256":h.hexdigest(),"triangles":14460,"materialGroups":3,"geometryUnchanged":True,"uv":"TEXCOORD_0","glbSha256":sha(result),"atlasSha256":sha(png),"texturePolicy":"opaque neutral bark; tint applied by MeshPart.Color; separate optional alpha overlay"},indent=2))
