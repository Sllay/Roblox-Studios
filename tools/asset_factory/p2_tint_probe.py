import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
import bmesh
out=Path(sys.argv[sys.argv.index("--")+1]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out.parent/"p2-handle"/"handle.glb"))
handle=next(o for o in bpy.context.scene.objects if o.type=="MESH")
points=[handle.matrix_world@v.co for v in handle.data.vertices]
zmax=max(p.z for p in points);zmin=min(p.z for p in points)
top=[p for p in points if p.z>zmax-.001]
x=sum(p.x for p in top)/len(top);y=sum(p.y for p in top)/len(top)
rx=max(abs(p.x-x) for p in top);ry=max(abs(p.y-y) for p in top)
length=zmax-zmin
assert rx>0 and ry>0 and length>0
socket={"center":[x,y,zmax-.08*length],"radiusX":rx,"radiusY":ry,"insertion":.14*length,"handleLength":length}
# Blade cross sections along X: thin cutting edge, broad cheek, thick socket, narrow poll.
# Each section is an eight-sided rounded rectangle in Y/Z.
sections=[(-.46,.003,.22),(-.40,.045,.24),(-.19,.105,.19),(0,ry/length*1.35,.125),(.17,ry/length*1.25,.105),(.21,ry/length*1.05,.075)]
verts=[];faces=[]
for dx,half_y,half_z in sections:
    for a,b in [(-.7,-1),(.7,-1),(1,-.7),(1,.7),(.7,1),(-.7,1),(-1,.7),(-1,-.7)]:
        verts.append((x+dx*length,y+a*half_y*length,socket["center"][2]+(b*half_z-max(0,dx)*.22)*length))
for j in range(len(sections)-1):
    for i in range(8):faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
faces.extend([tuple(reversed(range(8))),tuple(range((len(sections)-1)*8,len(sections)*8))])
m=bpy.data.meshes.new("AxeBlade");m.from_pydata(verts,[],faces);m.update()
bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges);bm.to_mesh(m);bm.free()
head=bpy.data.objects.new("AxeBlade",m);bpy.context.collection.objects.link(head)
mat=bpy.data.materials.new("Stone");mat.diffuse_color=(.32,.39,.36,1);mat.use_nodes=True;mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=mat.diffuse_color;m.materials.append(mat)
# Verify the solid socket region overlaps the actual upper handle, not merely bounding boxes.
from mathutils.bvhtree import BVHTree
tree=BVHTree.FromPolygons([v.co for v in m.vertices],[tuple(p.vertices) for p in m.polygons])
def inside(p):
    hit,normal,index,d=tree.ray_cast(p,Vector((1,.013,.007)))
    return hit is not None and normal.dot(Vector((1,.013,.007)))>0
samples=[p for p in points if zmax-.16*length<p.z<zmax-.03*length]
assert samples and all(inside(p) for p in samples),"socket does not overlap handle"
# UVs and shared neutral color map; wood remains a separate material.
import numpy as np
from PIL import Image
N=256
u,v=np.meshgrid(np.linspace(0,1,N),np.linspace(0,1,N))
rng=np.random.default_rng(42)
# Shape-aware painted shading: bright cutting edge, darker underside, no stripes.
edge=np.exp(-u*28)
base=.77-.22*(1-v)**2-.07*np.exp(-((u-.5)/.18)**2)*(1-v)
gray=np.clip(base+.29*edge,.42,1)
woodgrain=np.clip(.75+.13*np.sin(55*u+3*np.sin(9*v))+.05*np.sin(127*u+7*v),.4,1)
def texture(name,arr):
    path=out/(name+".png");Image.fromarray(np.uint8(np.clip(arr,0,1)*255),"RGB").save(path)
    im=bpy.data.images.load(str(path));im.pack();return im
neutral=texture("blade-neutral",np.repeat(gray[:,:,None],3,axis=2))
woodimg=texture("wood",woodgrain[:,:,None]*np.array([.56,.32,.15]))
def uvmat(obj,im,name,wood=False):
    mesh=obj.data
    uv=mesh.uv_layers.new(name="ToolUV");mesh.uv_layers.active=uv;uv.active_render=True
    for p in mesh.polygons:
        for li in p.loop_indices:
            q=obj.matrix_world@mesh.vertices[mesh.loops[li].vertex_index].co
            if wood: uv.data[li].uv=((math.atan2(q.y-y,q.x-x)/math.tau+.5)%1,(q.z-zmin)/length)
            else: uv.data[li].uv=((q.x-(x-.46*length))/(.67*length),.5+(q.z-socket["center"][2])/(.55*length))
    # Unwrap cylindrical seam per polygon.
    if wood:
        for p in mesh.polygons:
            us=[uv.data[i].uv.x for i in p.loop_indices]
            if max(us)-min(us)>.5:
                for i in p.loop_indices:
                    if uv.data[i].uv.x<.5:uv.data[i].uv.x+=1
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(1,1,1,1)
    n=m.node_tree.nodes.new("ShaderNodeTexImage");n.image=im;m.node_tree.nodes.active=n
    m.node_tree.links.new(n.outputs["Color"],m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
    mesh.materials.clear();mesh.materials.append(m);return n
node=uvmat(head,neutral,"TintableBlade");uvmat(handle,woodimg,"WoodGrain",True)
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH";scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.display.shading.color_type="TEXTURE"
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=2.2
center=Vector((x-.15,y,(zmin+zmax)/2+.05))
for name,d in {"front":(0,-4,0),"right":(4,0,0),"quarter":(3,-4,2),"rear":(-3,4,2)}.items():
    cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler();scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="DESELECT")
for o in (handle,head):o.select_set(True);o.data.calc_loop_triangles()
bpy.context.view_layer.objects.active=head
bpy.ops.export_scene.gltf(filepath=str(out/"axe.glb"),export_format="GLB",use_selection=True)
# Preview tint multiplication, without duplicating the exported base mesh or map.
for name,c in {"stone":(.55,.58,.61),"iron":(.85,.9,.95),"bronze":(.72,.43,.23),"gold":(.95,.73,.22),"diamond":(.32,.85,.96)}.items():
    node.image=texture("preview-"+name,gray[:,:,None]*np.array(c))
    cam.location=center+Vector((3,-4,2));cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
node.image=neutral
report={"socket":socket,"handleTriangles":len(handle.data.loop_triangles),"headTriangles":len(head.data.loop_triangles),"overlapSamples":sum(inside(p) for p in samples),"sampleCount":len(samples),"components":2,"published":False}
(out/"report.json").write_text(json.dumps(report,indent=2));print("P2_ASSEMBLY "+json.dumps(report),flush=True)
