import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector
import bmesh
import numpy as np
from PIL import Image,ImageDraw
out=Path(sys.argv[sys.argv.index("--")+1]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
# Manually traced proportions from supplied sword: front silhouette, inferred depth.
# Z is length; X width; Y thickness. No source mesh.
N=512
def paint(name,base,blade=False):
    im=Image.new("RGB",(N,N),base);d=ImageDraw.Draw(im)
    if blade:
        d.rectangle((0,0,95,N),fill=(226,226,226));d.rectangle((416,0,511,N),fill=(206,206,206))
        d.polygon([(96,0),(416,0),(416,512),(96,512)],fill=(139,139,139))
        d.polygon([(96,0),(256,0),(256,512),(96,512)],fill=(174,174,174))
        for x,y in [(120,90),(290,180),(160,320),(350,410)]:
            d.line((x,y,x+38,y-19),fill=(191,191,191),width=3)
            d.line((x,y+3,x+38,y-16),fill=(111,111,111),width=2)
    else:
        d.polygon([(0,0),(512,0),(512,75),(0,160)],fill=tuple(min(255,int(c*1.23)) for c in base))
        d.polygon([(0,440),(512,370),(512,512),(0,512)],fill=tuple(int(c*.65) for c in base))
    p=out/(name+".png");im.save(p);return p
def mat(name,path):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(1,1,1,1)
    n=m.node_tree.nodes.new("ShaderNodeTexImage");n.image=bpy.data.images.load(str(path));n.image.pack();m.node_tree.nodes.active=n
    m.node_tree.links.new(n.outputs["Color"],m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"]);return m,n
blade,node=mat("BladeTint",paint("blade-neutral",(160,160,160),True))
guard,_=mat("Guard",paint("guard",(100,105,115)))
blue,_=mat("GuardTips",paint("guard-tips",(54,68,91)))
red,_=mat("RedWrap",paint("red-wrap",(143,29,24)))
tan,_=mat("Grip",paint("grip",(159,100,43)))
def mesh(name,verts,faces,material):
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
    bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges);bm.to_mesh(m);bm.free()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);m.materials.append(material)
    uv=m.uv_layers.new(name="UVMap")
    xs=[v[0] for v in verts];zs=[v[2] for v in verts]
    for p in m.polygons:
        for i in p.loop_indices:
            q=m.vertices[m.loops[i].vertex_index].co
            uv.data[i].uv=((q.x-min(xs))/max(max(xs)-min(xs),.001),(q.z-min(zs))/max(max(zs)-min(zs),.001))
    return o
def rings(name,sections,material,n=8):
    v=[];f=[]
    for z,w,t in sections:
        for i in range(n):
            a=2*math.pi*i/n;v.append((w*math.cos(a),t*math.sin(a),z))
    for j in range(len(sections)-1):
        for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    f.extend([tuple(reversed(range(n))),tuple(range((len(sections)-1)*n,len(sections)*n))])
    return mesh(name,v,f,material)
# Beveled blade cross section: edge, shoulder, center ridge, shoulder, edge.
v=[];f=[]
for z,w,t in [(.72,.14,.045),(.81,.17,.05),(.88,.12,.045),(1.00,.115,.045),(1.90,.09,.036),(2.12,.06,.025),(2.21,.002,.002)]:
    v.extend([(-w,0,z),(-w*.68,-t*.75,z),(0,-t,z),(w*.68,-t*.75,z),(w,0,z),(w*.68,t*.75,z),(0,t,z),(-w*.68,t*.75,z)])
for j in range(6):
    for i in range(8):f.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
f.extend([tuple(reversed(range(8))),tuple(range(48,56))])
objects=[mesh("Blade",v,f,blade)]
def box(name,loc,scale,material,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    b=o.modifiers.new("Bevel","BEVEL");b.width=bevel;b.segments=1;bpy.ops.object.modifier_apply(modifier=b.name);o.data.materials.append(material);return o
# Contour-driven guard traced from the original image, in original pixel coordinates.
# Original sword points right; rotate into upright X/Z coordinates.
sys.path.insert(0,str(Path(__file__).resolve().parent))
from contour_mesh import contour_geometry
def traced(name,poly,depth,material):
    v,f=contour_geometry(poly,depth,origin=(9,234),scale=.0052)
    return mesh(name,v,f,material)
objects.append(traced("GuardContour",[(114,222),(118,195),(115,193),(117,181),(133,167),(148,163),(150,174),(148,183),(149,204),(151,218),(151,250),(148,266),(149,299),(144,302),(131,297),(117,284),(115,273),(118,271),(114,243)],.18,guard))
objects.append(traced("GuardLanget",[(143,219),(160,220),(182,226),(213,234),(182,241),(160,247),(143,247)],.105,guard))
objects.append(traced("GuardTipUpper",[(117,181),(133,167),(148,163),(150,174),(148,183),(118,195)],.19,blue))
objects.append(traced("GuardTipLower",[(118,271),(115,273),(117,284),(131,297),(144,302),(148,302),(149,287)],.19,blue))
objects.append(rings("Grip",[(.19,.064,.064),(.57,.064,.064)],tan,12))
# Continuous helical wrap, not flat stripes.
v=[];f=[];steps=64
for i in range(steps+1):
    t=i/steps;a=t*math.tau*3.5;z=.22+.31*t
    for r,dz in [(.065,-.019),(.079,-.019),(.079,.019),(.065,.019)]:v.append((r*math.cos(a),r*math.sin(a),z+dz))
for j in range(steps):
    for i in range(4):f.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
f.extend([(3,2,1,0),tuple(range(steps*4,steps*4+4))]);objects.append(mesh("Wrap",v,f,red))
objects.append(rings("Pommel",[(.02,.003,.003),(.08,.075,.055),(.15,.078,.058),(.19,.055,.045)],guard))
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH";scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.display.shading.color_type="TEXTURE"
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=2.65
center=Vector((0,0,1.12))
for name,d in {"front":(0,-4,0),"back":(0,4,0),"side":(4,0,0),"quarter":(3,-4,1)}.items():
    cam.location=center+Vector(d);cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler();scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="DESELECT")
for o in objects:o.select_set(True);o.data.calc_loop_triangles()
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.export_scene.gltf(filepath=str(out/"sword.glb"),export_format="GLB",use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"sword.blend"))
report={"triangles":sum(len(o.data.loop_triangles) for o in objects),"components":len(objects),"source":"manual trace of user reference; inferred depth; repainted maps","published":False}
(out/"report.json").write_text(json.dumps(report,indent=2));print("P2_SWORD "+json.dumps(report),flush=True)
