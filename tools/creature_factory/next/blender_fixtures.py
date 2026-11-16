"""Deterministic known-geometry fixtures. Runs inside pinned Blender."""
import sys,math,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from blender_audit import *
from mathutils import Vector
out=Path(sys.argv[sys.argv.index("--")+1]);res=int(sys.argv[sys.argv.index("--")+2])
V={"front":(0,-1,0),"back":(0,1,0),"left":(-1,0,0),"right":(1,0,0),"top":(0,0,1),"bottom":(0,0,-1),"three-quarter":(-1,-1,.8)}
def mesh(name,verts,faces):
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o)
    m.materials.append(make_material(name));return o
def sheet(name,fn,thickness):
    nx,ny=65,45;v=[(float(x),float(y),float(fn(x,y))) for y in np.linspace(-1,1,ny) for x in np.linspace(-1.5,1.5,nx)]
    n=len(v);v+= [(x,y,z-thickness) for x,y,z in v];f=[]
    for j in range(ny-1):
        for i in range(nx-1):
            a=j*nx+i;b=a+1;c=a+nx;d=c+1
            f.extend([(a,b,d),(a,d,c),(a+n,d+n,b+n),(a+n,c+n,d+n)])
    edge=list(range(nx))+[j*nx+nx-1 for j in range(1,ny)]+[ (ny-1)*nx+i for i in range(nx-2,-1,-1)]+[j*nx for j in range(ny-2,0,-1)]
    for a,b in zip(edge,edge[1:]+edge[:1]):f.extend([(b,a,a+n),(b,a+n,b+n)])
    return mesh(name,v,f)
def box(name,center,size):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center);o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(make_material(name));return o
def make(kind):
    if kind=="flat":return [sheet(kind,lambda x,y:0,.08)],{"thickness":.08,"amplitude":0,"frequency":0}
    if kind=="wavy":return [sheet(kind,lambda x,y:.22*math.sin(2*math.pi*x/1.5)*math.cos(math.pi*y/2),.08)],{"thickness":.08,"amplitude":.22,"wavelength":1.5}
    if kind in ("convex","concave"):
        # Same square top outline, same border height, opposite interior.
        sign=1 if kind=="convex" else -1
        return [sheet(kind,lambda x,y:sign*.35*(1-(x/1.5)**2)*(1-y*y),.55)],{"center_height":sign*.35,"rim_height":0,"thickness":.55}
    if kind=="asymmetric":
        return [box("body",(0,0,0),(1.6,1.2,1)),box("left_marker",(-1.05,0,.25),(.5,.4,.5)),box("right_marker",(1.25,0,-.1),(.9,.35,.3))],{"left_extent":-1.3,"right_extent":1.7}
    return [box("torso",(0,0,0),(1.2,1.2,1.2)),box("limb",(1.15,0,0),(.8,.4,.4)),box("thin_strand",(0,-.75,.3),(.08,.3,.08))],{"gap":.15,"joint":[.675,0,0],"thin_width":.08}
for kind in ("flat","wavy","convex","concave","asymmetric","articulation"):
    p=out/kind;p.mkdir()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objects,expected=make(kind);scene,cam,_,_=setup_scene(objects,res);scene.cycles.samples=4;scene.cycles.seed=0
    cam.data.ortho_scale=4.4;cam.data.clip_start=.01;cam.data.clip_end=30
    bvh=surface_bvh(objects);cameras={};metrics={}
    for name,d in V.items():
        camera_at(cam,Vector((0,0,0)),8/3,d)
        metrics[name]=geometry_buffers(p,name,cam,bvh,res,30)
        render(scene,p/("color-"+name+".png"))
        cameras[name]={"status":"known","projection":"orthographic","world_from_camera":[list(row) for row in cam.matrix_world],"ortho_scale":4.4,"confidence":1.0}
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(p/"ground-truth.glb"),export_format="GLB",use_selection=True,export_animations=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(p/"ground-truth.blend"))
    for o in objects:o.data.calc_loop_triangles()
    write_json(p/"geometry.json",{"fixture":kind,"seed":0,"parameters":expected,"cameras":cameras,"metrics":metrics,"objects":[o.name for o in objects],"vertices":sum(len(o.data.vertices) for o in objects),"triangles":sum(len(o.data.loop_triangles) for o in objects),"units":"unit","camera_convention":"Blender camera -Z forward +Y up; world Z up; top-left pixel centers"})
