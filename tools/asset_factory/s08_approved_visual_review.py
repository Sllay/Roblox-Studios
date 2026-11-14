"""Render approved S08 assets from their exact runtime GLBs. Blender preview, not Roblox client."""
import bpy,sys,json,hashlib
from pathlib import Path
from mathutils import Vector
root=Path.cwd();out=Path(sys.argv[sys.argv.index("--")+1]).resolve();out.mkdir(parents=True,exist_ok=True)
app=root/"asset-library/approved"
assets=[("stone",app/"stone/v1/runtime/asset.glb"),("stick",app/"stick/v1/runtime/asset.glb"),("log",app/"log/v1/runtime/asset.glb"),("eggydrasil",app/"eggydrasil/v8/eggydrasil-v8-tintable.glb")]
report={}
def aim(o,p):o.rotation_euler=(p-o.location).to_track_quat("-Z","Y").to_euler()
def tint(objects,colors):
    for name,color in colors.items():
        matches=[o for o in objects if name.lower() in o.name.lower()]
        assert len(matches)==1,(name,[o.name for o in objects])
        for slot in matches[0].material_slots:
            m=slot.material;assert m and m.use_nodes
            m=m.copy();slot.material=m
            n=m.node_tree.nodes;links=m.node_tree.links
            bsdf=next(x for x in n if x.type=="BSDF_PRINCIPLED")
            base=bsdf.inputs["Base Color"];assert base.is_linked,"Expected embedded leaf albedo"
            old=base.links[0].from_socket
            mix=n.new("ShaderNodeMixRGB");mix.blend_type="MULTIPLY";mix.inputs[0].default_value=1
            mix.inputs[2].default_value=(*color,1);links.new(old,mix.inputs[1]);links.new(mix.outputs[0],base)
            assert bsdf.inputs["Alpha"].is_linked,"Expected leaf alpha"
for name,src in assets:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src.resolve()))
    objs=[o for o in bpy.context.scene.objects if o.type=="MESH"];assert objs
    points=[o.matrix_world@Vector(v) for o in objs for v in o.bound_box]
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center=(lo+hi)/2;size=max(hi-lo)
    sc=bpy.context.scene;sc.render.engine="CYCLES";sc.cycles.samples=20;sc.cycles.use_denoising=False;sc.cycles.transparent_max_bounces=32
    sc.render.resolution_x=640;sc.render.resolution_y=640;sc.render.resolution_percentage=100;sc.render.film_transparent=True;sc.render.image_settings.color_mode="RGBA"
    sc.world=bpy.data.worlds.new("Studio");sc.world.use_nodes=True;sc.world.node_tree.nodes["Background"].inputs[0].default_value=(.35,.35,.35,1);sc.world.node_tree.nodes["Background"].inputs[1].default_value=.65
    sc.view_settings.view_transform="Standard"
    bpy.ops.object.camera_add();cam=bpy.context.object;sc.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=size*1.28;cam.data.clip_end=size*20
    cam.location=center+Vector((1,-1,.42 if name=="eggydrasil" else .85)).normalized()*size*3;aim(cam,center)
    for direction,power in [((3,-4,5),500),((-3,-1,2),250),((1,4,3),350)]:
        bpy.ops.object.light_add(type="AREA",location=center+Vector(direction)*size);l=bpy.context.object;l.data.energy=power*size*size;l.data.size=size*2;aim(l,center)
    sc.render.filepath=str(out/(name+".png"));bpy.ops.render.render(write_still=True)
    if name=="eggydrasil":
        tint(objs,{"Canopy_White":(1,.3137255,.5490196),"Canopy_Gray":(.4705882,.1568627,.7843137)})
        sc.render.filepath=str(out/"eggydrasil-tint.png");bpy.ops.render.render(write_still=True)
    report[name]={"source":str(src.relative_to(root)),"sha256":hashlib.sha256(src.read_bytes()).hexdigest(),"objects":len(objs),"bounds":list(hi-lo)}
(out/"report.json").write_text(json.dumps({"assets":report,"scope":"Blender source asset render; not client render","clientRenderVerified":False},indent=2))
