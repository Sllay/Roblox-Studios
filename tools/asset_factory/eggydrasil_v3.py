"""Eggydrasil V3: reference-guided direct swept surfaces, no visual hull."""
import bpy,bmesh,math,random,sys,json
from pathlib import Path
from mathutils import Vector
out=Path(sys.argv[sys.argv.index("--")+1]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
rng=random.Random(187)
palette=[(.24,.085,.032),(.32,.13,.055),(.19,.055,.025),(.40,.19,.075)]
mats=[]
for i,c in enumerate(palette):
    m=bpy.data.materials.new("Bark_%d"%i);m.diffuse_color=(*c,1);m.use_nodes=True
    bs=m.node_tree.nodes.get("Principled BSDF");bs.inputs["Base Color"].default_value=(*c,1);bs.inputs["Roughness"].default_value=.86;mats.append(m)
objects=[];anchors=[]
def cat(p0,p1,p2,p3,t):
    return .5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
def sweep(name,points,radii,sides=12,steps=4,flute=.12,twist=.6):
    P=[Vector(p) for p in points];C=[];R=[]
    for i in range(len(P)-1):
        for j in range(steps):
            t=j/steps;C.append(cat(P[max(0,i-1)],P[i],P[i+1],P[min(len(P)-1,i+2)],t))
            R.append(radii[i]*(1-t)+radii[i+1]*t)
    C.append(P[-1]);R.append(radii[-1]);verts=[];faces=[];prev=None;phase=rng.random()*6.28
    for i,c in enumerate(C):
        tangent=(C[min(i+1,len(C)-1)]-C[max(0,i-1)]).normalized()
        if prev is None:
            ref=Vector((0,0,1)) if abs(tangent.z)<.9 else Vector((1,0,0));a=tangent.cross(ref).normalized()
        else:
            a=prev-tangent*prev.dot(tangent)
            if a.length<.001:a=tangent.cross(Vector((0,1,0)))
            a.normalize()
        prev=a.copy();b=tangent.cross(a).normalized();u=i/(len(C)-1)
        for j in range(sides):
            ang=j*math.tau/sides
            q=ang+twist*u+phase
            # Distinct deep longitudinal furrows, not independent floating ridges.
            r=R[i]*(1+flute*(.65*math.cos(5*q)+.27*math.sin(9*q+.5)+.17*math.cos(3*q+u*3))+.035*math.sin(2*q+u*8))
            verts.append(c+(a*math.cos(ang)+b*math.sin(ang))*r)
    for i in range(len(C)-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    faces.extend([tuple(reversed(range(sides))),tuple((len(C)-1)*sides+j for j in range(sides))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);objects.append(o)
    for m in mats:mesh.materials.append(m)
    for p in mesh.polygons:
        p.use_smooth=True
        if p.index<(len(C)-1)*sides:
            j=p.index%sides;u=(p.index//sides)/(len(C)-1);q=(j+.5)*math.tau/sides+twist*u+phase
            v=math.cos(5*q)
            p.material_index=2 if v<-.72 else (1 if v>.55 else 0)
    return C
# Reference silhouette: flared roots, twisting central stem, broad alternating horizontal tiers.
trunk=[(0,0,.8),(-.9,.1,4),(-1.8,.25,8),(-.6,-.3,12),(1.2,-.55,16),(1.7,.1,20),(.2,.6,24),(-.7,.4,28),(.4,.2,32),(1.5,.3,35)]
sweep("Ancient_core",trunk,[4.8,4.2,3.65,3.4,3.2,2.9,2.65,2.3,1.65,.7],32,4,.25,1.8)
# Braided buttress ribbons follow the trunk curvature and emerge as roots.
for i in range(6):
    angle=i*math.tau/6+.22
    pts=[]
    for j in range(8):
        c=Vector(trunk[j]);theta=angle+j*.26
        offset=[3.8,3.1,2.75,2.65,2.5,2.3,1.9,1.5][j]
        pts.append(c+Vector((math.cos(theta)*offset,math.sin(theta)*offset,0)))
    direction=Vector((math.cos(angle),math.sin(angle),0));side=Vector((-direction.y,direction.x,0))
    root=[direction*11+side*(1.3 if i%2 else -1.5)+Vector((0,0,.4)),direction*8+side*.8+Vector((0,0,1.1)),direction*5.6-side*.6+Vector((0,0,2.6))]
    sweep("Braided_root_%02d"%i,root+pts,[.12,.75,1.5,1.65,1.45,1.25,1.15,.95,.72,.52,.18],12,3,.20,1.4)
    start=root[1];end=start+direction*3.7+side*(2.6 if i%2 else -2.4)+Vector((0,0,-.7))
    sweep("Root_finger_%02d"%i,[start,start.lerp(end,.5)+Vector((0,0,.45)),end],[.6,.4,.065],9,4,.11,.5)
# Manually authored major branches in reference's front plane, with depth variation.
branches=[
("lower_left", [(-.4,-.6,12),(-4,-.8,15),(-8,-1.4,18),(-12,-.6,17),(-16,.1,16),(-20,-.8,19)], [2.45,2.35,1.8,1.35,.8,.13]),
("lower_right",[(.7,-.8,13),(4,-1,17),(8,-.5,19),(12,0,17.8),(16,-.7,18.5),(20,-1.5,21)],[2.35,2.15,1.65,1.2,.7,.12]),
("middle_left",[(1.4,.2,19),(-2,.5,23),(-6,.2,25),(-10,-.4,23.5),(-14,-.6,24),(-18,.4,27)],[2.1,1.95,1.55,1.1,.65,.12]),
("middle_right",[(1.2,.4,21),(5,.8,25),(9,1.1,26),(13,1,24),(17,.2,26),(20,1,29)],[2.05,1.9,1.45,1.05,.58,.10]),
("upper_left",[(.2,.3,26),(-3,.8,29),(-6,1.2,31),(-10,1.5,30),(-13,.4,32),(-15,0,35)],[1.75,1.5,1.15,.85,.45,.09]),
("upper_right",[(.1,.2,28),(4,.1,32),(7,-.6,35),(10,-.4,34),(13,.2,35),(15,.7,38)],[1.65,1.4,1.0,.7,.4,.08]),
("top_left",[(.4,.2,31),(-2,.4,35),(-5,-.3,38),(-8,-.8,38),(-10,-.5,41)],[1.4,1.15,.8,.45,.08]),
("top_right",[(1,.2,33),(4,.1,36),(5,1,39),(4.8,1.6,42)],[1.15,.87,.5,.08]),
("rear_crown",[(0,1,22),(.8,4,25),(-1,8,27),(-3,11,29),(-4,13,33)],[1.85,1.45,1.05,.6,.10]),
("rear_upper",[(0,1,28),(2,4,31),(5,7,32),(7,10,36)],[1.4,1.05,.6,.09]),
]
for k,(name,points,radii) in enumerate(branches):
    C=sweep(name,points,radii,12,4,.19,1.25)
    # Forks arise exactly on parent centerline, with outward and upward curves.
    sign=-1 if "left" in name else 1
    for j,t in enumerate((.43,.65,.82)):
        start=C[round(t*(len(C)-1))];r=(1-t)*radii[0]*.66+.12
        dx=sign*(2.4+j*.75);dy=(-1 if j%2==0 else 1)*(1.8+.7*(k%3));dz=3.6+j*.35
        if name.startswith("rear"):dx=(-1 if j%2 else 1)*3;dy=2
        end=start+Vector((dx,dy,dz));mid=start+Vector((dx*.5,dy*.3,dz*.3))
        tip=sweep(name+"_fork%d"%j,[start,mid,end+Vector((-.4*sign,0,-.4)),end],[r,r*.78,r*.32,.06],8,3,.13,.7)
        anchors.append(list(end))
        for h in range(2):
            s=tip[round((.55+h*.2)*(len(tip)-1))];e=s+Vector((sign*(1.4+h*.7),(-1 if h==0 else 1)*1.2,1.9+h*.7))
            sweep(name+"_twig%d%d"%(j,h),[s,s.lerp(e,.55)+Vector((0,0,-.25)),e],[r*.30,r*.20,.035],6,2,.09,.3);anchors.append(list(e))
# Keep intersections explicit for review; no remesh, no silhouette hull, no atlas.
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.object.join();o=bpy.context.object;o.name="Eggydrasil_V3"
mesh=o.data
bottom=min(v.co.z for v in mesh.vertices)
for v in mesh.vertices:v.co.z-=bottom
mesh.update();mesh.calc_loop_triangles()
original_tri=len(mesh.loop_triangles)
if original_tri>15000:
    mod=o.modifiers.new('Review budget','DECIMATE');mod.ratio=14500/original_tri;bpy.ops.object.modifier_apply(modifier=mod.name)
    mesh=o.data;mesh.calc_loop_triangles()
tri=len(mesh.loop_triangles);assert tri<=15000,tri
bpy.ops.export_scene.gltf(filepath=str(out/"eggydrasil-v3.glb"),export_format="GLB",use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"eggydrasil-v3.blend"))
pts=[v.co for v in mesh.vertices];lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)));center=(lo+hi)/2;size=max(hi-lo)
scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=48;scene.cycles.use_denoising=False
for layer in scene.view_layers:layer.cycles.use_denoising=False
scene.render.resolution_x=960;scene.render.resolution_y=960;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.color_mode="RGBA"
scene.world=bpy.data.worlds.new("Studio");scene.world.use_nodes=True;scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.3,.3,.3,1);scene.world.node_tree.nodes["Background"].inputs[1].default_value=.7
def aim(obj,target):obj.rotation_euler=(target-obj.location).to_track_quat("-Z","Y").to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=size*1.13;cam.data.clip_end=size*12
for d,power,col in [((3,-4,5),900,(1,.83,.65)),((-3,-1,2),420,(.78,.85,1)),((1,4,3),700,(1,.90,.75))]:
    bpy.ops.object.light_add(type="AREA",location=center+Vector(d)*size);l=bpy.context.object;l.data.energy=power*size*size;l.data.size=size*2;l.data.color=col;aim(l,center)
for name,d in [("front",(0,-1,.03)),("quarter",(1,-1,.27)),("back",(0,1,.03))]:
    cam.location=center+Vector(d).normalized()*size*3;aim(cam,center);scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
(out/"report.json").write_text(json.dumps(dict(sourceTriangles=original_tri,triangles=tri,vertices=len(mesh.vertices),dimensions=list(hi-lo),majorBranches=len(branches),foliageAnchors=len(anchors),uv=False,published=False,method="direct swept curves; intersecting components, visual candidate only"),indent=2))
(out/"foliage-anchors.json").write_text(json.dumps([[x,y,z-bottom] for x,y,z in anchors],indent=2))
