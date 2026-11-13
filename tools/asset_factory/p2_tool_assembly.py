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
sections=[(-.43,.025,.22),(-.36,.065,.24),(-.19,.105,.19),(0,ry*1.35,.125),(.13,ry*1.25,.105)]
verts=[];faces=[]
for dx,half_y,half_z in sections:
    for a,b in [(-.7,-1),(.7,-1),(1,-.7),(1,.7),(.7,1),(-.7,1),(-1,.7),(-1,-.7)]:
        verts.append((x+dx*length,y+a*half_y*length,socket["center"][2]+b*half_z*length))
for j in range(len(sections)-1):
    for i in range(8):faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
faces.extend([tuple(reversed(range(8))),tuple(range(32,40))])
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
samples=[p for p in points if zmax-.12*length<p.z<zmax-.03*length]
assert samples and any(inside(p) for p in samples),"socket does not overlap handle"
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH";scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.display.shading.color_type="MATERIAL"
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=2.2
center=Vector((x-.15,y,(zmin+zmax)/2+.05))
for name,d in {"front":(0,-4,0),"right":(4,0,0),"quarter":(3,-4,2),"rear":(-3,4,2)}.items():
    cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler();scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="DESELECT")
for o in (handle,head):o.select_set(True);o.data.calc_loop_triangles()
bpy.context.view_layer.objects.active=head
bpy.ops.export_scene.gltf(filepath=str(out/"axe.glb"),export_format="GLB",use_selection=True)
report={"socket":socket,"handleTriangles":len(handle.data.loop_triangles),"headTriangles":len(head.data.loop_triangles),"overlapSamples":sum(inside(p) for p in samples),"sampleCount":len(samples),"components":2,"published":False}
(out/"report.json").write_text(json.dumps(report,indent=2));print("P2_ASSEMBLY "+json.dumps(report),flush=True)
