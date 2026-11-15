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
master=mesh_obj("Rabbit_Neural_Master",data["master_vertices"],data["master_faces"])
assert topo(master,True)==0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"sculpt-master.blend"))
bpy.data.objects.remove(master,do_unlink=True)
body=mesh_obj("Rabbit_Neural_Body",data["vertices"],data["faces"])
assert topo(body)==0
# Preserve the xatlas chart coordinates from the learned color bake.
uv=body.data.uv_layers.new(name="UVMap")
loops=data["loop_uv"].reshape(-1,2)
assert len(loops)==len(uv.data)
uv.data.foreach_set("uv",loops.ravel())
im=bpy.data.images.load(str(out/"neural-albedo.png"));im.pack()
mat=bpy.data.materials.new("Rabbit_Neural_Albedo");mat.use_nodes=True
nodes=mat.node_tree.nodes;bs=nodes.get("Principled BSDF");bs.inputs["Roughness"].default_value=.8
tex=nodes.new("ShaderNodeTexImage");tex.image=im;nodes.active=tex
mat.node_tree.links.new(tex.outputs["Color"],bs.inputs["Base Color"])
body.data.materials.append(mat)
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
    o["rig_binding"]="Head";return o
def hit_root(x,z):
    # Use nearby sampling only if the exact reference landmark misses the surface.
    for dx,dz in [(0,0),(0,.03),(0,-.03),(.025,0),(-.025,0),(0,.06),(0,-.06),(.05,0),(-.05,0)]:
        hit,loc,_,_=body.ray_cast(Vector((x+dx,-4,z+dz)),Vector((0,1,0)))
        if hit:return loc
    raise RuntimeError("Whisker landmark has no muzzle surface")
whiskers=[];rootloc=[]
for s,tag in [(-1,"L"),(1,"R")]:
    for i,(x,z,ex,ez,dy) in enumerate([(.11,2.02,.65,2.08,.045),(.12,1.985,.64,1.975,.065),(.13,1.935,.55,1.81,.105)]):
        loc=hit_root(s*x,z);rootloc.append(list(loc))
        pts=[]
        for j in range(13):
            t=j/12
            pts.append(Vector((loc.x+(s*ex-loc.x)*t,loc.y+.004+dy*t*t,loc.z+(ez-loc.z)*t+.025*math.sin(math.pi*t))))
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
sh=scene.display.shading;sh.color_type="TEXTURE";sh.light="STUDIO";sh.show_shadows=False;sh.show_cavity=False
try:sh.studio_light="paint.sl"
except Exception:pass
scene.world=bpy.data.worlds.new("ReviewWorld");scene.world.color=(.15,.15,.15)
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=4.15
center=Vector((0,0,1.8))
views={"front":(0,-6,0),"right":(6,0,0),"left":(-6,0,0),"back":(0,6,0),"top":(0,0,6),"bottom":(0,0,-6),"three-quarter":(-4,-6,1.3)}
def render(name,d,kind):
    sh.color_type=kind;cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
for name,d in views.items():render(name,d,"TEXTURE")
for name in ("front","right","three-quarter"):render("clay-"+name,views[name],"SINGLE")
sh.color_type="TEXTURE";bpy.ops.wm.save_as_mainfile(filepath=str(out/"asset.blend"))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(out/"asset.glb"))
objs=[o for o in bpy.context.scene.objects if o.type=="MESH"]
assert len([o for o in objs if o.name.startswith("Whisker_")])==6
assert all(o.data.uv_layers for o in objs)
for o in objs:o.data.calc_loop_triangles()
assert sum(len(o.data.loop_triangles) for o in objs)==tris
report.update({"state":"pending_silhouette_audit","exportedVertices":verts,"vertexBudget":None,"triangles":tris,
 "geometryPolicy":"unrestricted_artistic_candidate","referenceTriangleTarget":50000,
 "meshTriangles":mesh_triangles,"robloxPerMeshTriangleLimit":platform_limit,
 "robloxOversizedMeshes":oversized,"robloxGeometryReady":not bool(oversized),
 "runtimePackagingRequired":bool(oversized),
 "whiskers":6,"whiskerClosedMeshes":True,"whiskerRootPositions":rootloc,"whiskerHeadBindingPlanned":True,
 "uv":True,"roundtrip":True,"views":list(views),"clayViews":["front","right","three-quarter"],"artisticApproval":False,"robloxPublished":False})
(out/"report.json").write_text(json.dumps(report,indent=2)+"\n");print(json.dumps(report),flush=True)
