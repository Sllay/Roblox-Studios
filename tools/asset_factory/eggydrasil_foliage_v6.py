"""Independent alpha-card canopy over the immutable approved V4 wood candidate."""
import bpy,math,random,sys,json,hashlib,shutil,bisect
from pathlib import Path
from mathutils import Vector
src,out=map(Path,sys.argv[sys.argv.index("--")+1:]);out.mkdir(parents=True,exist_ok=True)
wood=src/"eggydrasil-v4.glb";anchorfile=src/"foliage-anchors.json"
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(wood)=="25053a955043c5cdf3e009d225039b0fdeeed459b3b7684ff8bbd16be9247c2d"
assert digest(anchorfile)=="58fee8fedcd124c1888140b53f6a20cce5a38cce6650ff1de03f6780f5edb0c3"
anchors=[Vector(p) for p in json.loads(anchorfile.read_text())];assert len(anchors)==90
sys.path.insert(0,str(Path(__file__).resolve().parent))
from eggydrasil_branch_paths import calibrated_paths
paths=calibrated_paths(anchors)
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
rng=random.Random(606);cards=[];distribution={};coverage={};placement=[]
# Sample actual arc lengths, not just endpoints. Each major branch gets coverage
# in its inner, middle and outer region; upper foliage follows the same branches.
def sample(path,t):
    P=path["points"];R=path["radii"];lengths=[0.]
    for a,b in zip(P,P[1:]):lengths.append(lengths[-1]+(b-a).length)
    d=t*lengths[-1];i=min(len(P)-2,max(0,bisect.bisect_right(lengths,d)-1))
    f=(d-lengths[i])/max(1e-8,lengths[i+1]-lengths[i])
    return P[i].lerp(P[i+1],f),(P[i+1]-P[i]).normalized(),R[i]*(1-f)+R[i+1]*f
def allocate(group,count):
    # Guarantee every curve gets cards; weight remaining cards by arc length.
    lengths=[sum((b-a).length for a,b in zip(p["points"],p["points"][1:])) for p in group]
    q=[max(1,int(count*l/sum(lengths))) for l in lengths]
    while sum(q)<count:q[max(range(len(q)),key=lambda i:count*lengths[i]/sum(lengths)-q[i])]+=1
    while sum(q)>count:q[max((i for i in range(len(q)) if q[i]>1),key=lambda i:q[i]-count*lengths[i]/sum(lengths))]-=1
    return q
groups=[("major",1120,[p for p in paths if p["kind"]=="major"],.18,.98),
        ("fork",1000,[p for p in paths if p["kind"]=="fork"],.08,.98),
        ("twig",480,[p for p in paths if p["kind"]=="twig"],.05,.98),
        ("upper",600,[p for p in paths if max(v.z for v in p["points"])>37],.24,.98)]
for zone,count,group,lo_t,hi_t in groups:
    distribution[zone]=0
    for path,n in zip(group,allocate(group,count)):
        for j in range(n):
            t=lo_t+(hi_t-lo_t)*(j+rng.uniform(.10,.90))/n
            p,tangent,r=sample(path,t)
            # Offset around branch circumference; prioritize upper and lateral sides.
            axis=tangent.cross(Vector((0,0,1)))
            if axis.length<.01:axis=tangent.cross(Vector((1,0,0)))
            axis.normalize();other=tangent.cross(axis).normalized()
            theta=rng.uniform(0,math.tau);normal=axis*math.cos(theta)+other*math.sin(theta)
            if normal.z<-.45 and rng.random()<.75:normal=-normal
            center=p+normal*(r*rng.uniform(.70,1.02)+rng.uniform(.35,1.25))
            if zone=="upper":
                center+=Vector((rng.uniform(-.75,.75),rng.uniform(-.75,.75),rng.uniform(.75,2.1)))
            # Widely varied tilt; top-facing cards fill crown while steep cards add volume.
            yaw=rng.uniform(0,math.tau);tilt=rng.uniform(.20,1.32)
            if zone=="upper":tilt=rng.uniform(.05,.83)
            side=Vector((math.cos(yaw),math.sin(yaw),0))
            up=Vector((-math.sin(yaw)*math.cos(tilt),math.cos(yaw)*math.cos(tilt),math.sin(tilt)))
            spin=rng.uniform(0,math.tau);u=side*math.cos(spin)+up*math.sin(spin);v=-side*math.sin(spin)+up*math.cos(spin)
            size=rng.uniform(3.0,4.6) if zone!="twig" else rng.uniform(2.5,3.8)
            width=size*rng.uniform(.82,1.13)
            corners=[center-u*width/2-v*size/2,center+u*width/2-v*size/2,center+u*width/2+v*size/2,center-u*width/2+v*size/2]
            cell=rng.randrange(4);x=(cell%2)*.5;y=(1-cell//2)*.5;g=2/1024
            uv=[(x+g,y+g),(x+.5-g,y+g),(x+.5-g,y+.5-g),(x+g,y+.5-g)]
            cards.append((corners,uv));distribution[zone]+=1
            coverage.setdefault(path["name"],set()).add(min(2,int(t*3)))
            placement.append(dict(zone=zone,branch=path["name"],t=round(t,4),center=list(center)))
assert len(cards)==3200 and distribution=={"major":1120,"fork":1000,"twig":480,"upper":600}
assert all(coverage[p["name"]]=={0,1,2} for p in paths if p["kind"]=="major")
# Interleave zones so reduced LODs retain distribution, instead of truncating the crown.
order=list(range(len(cards)));rng.shuffle(order);cards=[cards[i] for i in order]
(out/"placement.json").write_text(json.dumps(dict(zones=distribution,curveCount=len(paths),coverage={k:sorted(v) for k,v in coverage.items()},cards=placement),indent=2))
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
export(out/"eggydrasil-v6-preview.glb",wood_objects+[canopy])
assert triangles(wood_objects)==14460 and digest(out/"wood-v4-unchanged.glb")==digest(wood)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"eggydrasil-v6-preview.blend"))
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
(out/"report.json").write_text(json.dumps(dict(woodSha256=digest(wood),woodTriangles=14460,cards=len(cards),foliageTriangles=2*len(cards),totalTriangles=14460+2*len(cards),anchors=len(anchors),lodCards=[len(cards),len(cards[::2]),len(cards[::4])],atlas="disconnected original 1024 RGBA",distribution=distribution,branchCurves=len(paths),majorCoverage={p['name']:sorted(coverage[p['name']]) for p in paths if p['kind']=='major'},alphaMode="MASK",published=False,mobileValidated=False),indent=2))
