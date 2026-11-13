"""Independent alpha-card canopy over the immutable approved V4 wood candidate."""
import bpy,math,random,sys,json,hashlib,shutil
from pathlib import Path
from mathutils import Vector
src,out=map(Path,sys.argv[sys.argv.index("--")+1:]);out.mkdir(parents=True,exist_ok=True)
wood=src/"eggydrasil-v4.glb";anchorfile=src/"foliage-anchors.json"
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(wood)=="25053a955043c5cdf3e009d225039b0fdeeed459b3b7684ff8bbd16be9247c2d"
assert digest(anchorfile)=="58fee8fedcd124c1888140b53f6a20cce5a38cce6650ff1de03f6780f5edb0c3"
anchors=[Vector(p) for p in json.loads(anchorfile.read_text())];assert len(anchors)==90
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(wood.resolve()))
wood_objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
assert wood_objects
def triangles(objects):
    for o in objects:o.data.calc_loop_triangles()
    return sum(len(o.data.loop_triangles) for o in objects)
assert triangles(wood_objects)==14460
shutil.copyfile(wood,out/"wood-v4-unchanged.glb")
# Four atlas cells; each mesh is a quad card, not a separate scene object.
atlas=bpy.data.images.load(str((out/"leaves-atlas.png").resolve()));atlas.pack()
mat=bpy.data.materials.new("Eggydrasil_Leaves_Alpha");mat.use_nodes=True
mat.blend_method="CLIP";mat.shadow_method="CLIP";mat.alpha_threshold=.42;mat.use_backface_culling=False
bs=mat.node_tree.nodes.get("Principled BSDF");bs.inputs["Roughness"].default_value=.85
tex=mat.node_tree.nodes.new("ShaderNodeTexImage");tex.image=atlas;tex.interpolation="Linear"
mat.node_tree.links.new(tex.outputs["Color"],bs.inputs["Base Color"]);mat.node_tree.links.new(tex.outputs["Alpha"],bs.inputs["Alpha"])
rng=random.Random(541);cards=[]
# Small, asymmetric, layered sprays at real fork/twig endpoints. Stem aligns to anchor region.
for i,p in enumerate(anchors):
    radial=Vector((p.x,p.y,0))
    if radial.length<.01:radial=Vector((1,0,0))
    radial.normalize()
    for j in range(24):
        yaw=math.tau*((j*0.61803398875+i*.071)%1)+rng.uniform(-.16,.16)
        direction=Vector((math.cos(yaw),math.sin(yaw),0))
        # Spread across all azimuths, from almost horizontal to more upright.
        rise=rng.uniform(.24,.92);up=(direction*math.sqrt(1-rise*rise)+Vector((0,0,rise))).normalized()
        side=Vector((-math.sin(yaw),math.cos(yaw),0))
        # Tilt the card around its long axis to break visible plane alignment.
        roll=rng.uniform(-.75,.75);side=(side*math.cos(roll)+up.cross(side)*math.sin(roll)).normalized()
        radius=rng.uniform(.12,1.45);root=p+direction*radius+radial*rng.uniform(-.7,.8)+Vector((0,0,rng.uniform(-.8,.65)))
        length=rng.uniform(2.3,4.1);width=length*rng.uniform(.78,1.12)
        center=root+up*(length*.35)
        corners=[center-side*width/2-up*length/2,center+side*width/2-up*length/2,center+side*width/2+up*length/2,center-side*width/2+up*length/2]
        cell=rng.randrange(4);u=(cell%2)*.5;v=(1-cell//2)*.5;g=2/1024
        uv=[(u+g,v+g),(u+.5-g,v+g),(u+.5-g,v+.5-g),(u+g,v+.5-g)]
        cards.append((corners,uv))
def mesh_for(name,subset):
    verts=[];faces=[];uvs=[]
    for corners,uv in subset:
        k=len(verts);verts.extend(corners);faces.extend([(k,k+1,k+2),(k,k+2,k+3)]);uvs.extend([uv[0],uv[1],uv[2],uv[0],uv[2],uv[3]])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();mesh.materials.append(mat)
    layer=mesh.uv_layers.new(name="LeafAtlas")
    for loop,uv in zip(layer.data,uvs):loop.uv=uv
    ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob)
    assert triangles([ob])==2*len(subset)
    return ob
def export(path,objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True)
for stride in (4,2,1):
    o=mesh_for("Canopy_LOD%d"%{1:0,2:1,4:2}[stride],cards[::stride])
    export(out/("canopy-lod%d.glb"%{1:0,2:1,4:2}[stride]),[o])
    if stride!=1:bpy.data.objects.remove(o,do_unlink=True)
    else:canopy=o
export(out/"eggydrasil-v5-preview.glb",wood_objects+[canopy])
assert triangles(wood_objects)==14460 and digest(out/"wood-v4-unchanged.glb")==digest(wood)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"eggydrasil-v5-preview.blend"))
points=[o.matrix_world@v.co for o in wood_objects+[canopy] for v in o.data.vertices]
lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(lo+hi)/2;size=max(hi-lo)
scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=32;scene.cycles.use_denoising=False
for layer in scene.view_layers:layer.cycles.use_denoising=False
scene.render.resolution_x=960;scene.render.resolution_y=960;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.color_mode="RGBA"
scene.world=bpy.data.worlds.new("Studio");scene.world.use_nodes=True;scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.3,.3,.3,1);scene.world.node_tree.nodes["Background"].inputs[1].default_value=.7
def aim(o):o.rotation_euler=(center-o.location).to_track_quat("-Z","Y").to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=size*1.16;cam.data.clip_end=size*12
for d,power,col in [((3,-4,5),900,(1,.86,.72)),((-3,-1,2),480,(.84,.91,1)),((1,4,3),750,(1,.94,.82))]:
    bpy.ops.object.light_add(type="AREA",location=center+Vector(d)*size);l=bpy.context.object;l.data.energy=power*size*size;l.data.size=size*2;l.data.color=col;aim(l)
for name,d in [("quarter",(1,-1,.27)),("front",(0,-1,.03)),("side",(1,0,.03)),("top",(0,0,1))]:
    cam.location=center+Vector(d).normalized()*size*3;aim(cam)
    if name=="top":cam.rotation_euler=(0,0,0)
    scene.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
(out/"report.json").write_text(json.dumps(dict(woodSha256=digest(wood),woodTriangles=14460,cards=len(cards),foliageTriangles=2*len(cards),totalTriangles=14460+2*len(cards),anchors=len(anchors),lodCards=[len(cards),len(cards[::2]),len(cards[::4])],atlas="original 1024 RGBA",alphaMode="MASK",published=False,mobileValidated=False),indent=2))
