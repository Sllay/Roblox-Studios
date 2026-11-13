"""Candidate-only base-color transfer; preserve original material properties."""
import bpy,bmesh,sys,math,json,hashlib
from pathlib import Path
src,out=map(Path,sys.argv[sys.argv.index("--")+1:])
out.mkdir(parents=True,exist_ok=False)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src.resolve()))
objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
assert objects
image=bpy.data.images.new("TransferredAtlas",width=1024,height=1024,alpha=False)
records=[]
for o in objects:
    o.data=o.data.copy();m=o.data
    old=m.uv_layers.active
    assert old
    old.name="SourceUV"
    new=m.uv_layers.new(name="BakedUV")
    m.uv_layers.active=new;new.active_render=True
    bm=bmesh.new();bm.from_mesh(m)
    for e in bm.edges:e.seam=not e.is_manifold or e.calc_face_angle(0)>math.radians(55) or len({f.material_index for f in e.link_faces})>1
    bm.to_mesh(m);bm.free()
    bpy.ops.object.select_all(action="DESELECT");o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.context.scene.tool_settings.use_uv_select_sync=True
    bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED",margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    for i,s in enumerate(o.material_slots):
        mat=s.material.copy();s.material=mat
        mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links
        bs=next(x for x in n if x.type=="BSDF_PRINCIPLED")
        output=next(x for x in n if x.type=="OUTPUT_MATERIAL")
        base=bs.inputs["Base Color"]
        # Explicit source UV for existing image textures; reject complex coordinate graphs.
        for t in [x for x in n if x.type=="TEX_IMAGE"]:
            if t.inputs["Vector"].is_linked:
                link=t.inputs["Vector"].links[0]
                if link.from_node.type!="UVMAP":raise ValueError("Unsupported source texture coordinates")
                link.from_node.uv_map="SourceUV"
            else:
                u=n.new("ShaderNodeUVMap");u.uv_map="SourceUV";l.new(u.outputs["UV"],t.inputs["Vector"])
        em=n.new("ShaderNodeEmission")
        if base.is_linked:l.new(base.links[0].from_socket,em.inputs["Color"])
        else:em.inputs["Color"].default_value=base.default_value
        l.new(em.outputs[0],output.inputs["Surface"])
        target=n.new("ShaderNodeTexImage");target.image=image;n.active=target
        records.append((mat,bs,output,em,target))
bpy.ops.object.select_all(action="DESELECT")
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT");bpy.ops.uv.select_all(action="SELECT")
bpy.ops.uv.average_islands_scale();bpy.ops.uv.pack_islands(margin=0.02)
bpy.ops.object.mode_set(mode="OBJECT")
scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=16
scene.render.bake.margin=8;scene.render.bake.use_clear=True
bpy.ops.object.bake(type="EMIT")
image.filepath_raw=str(out/"atlas.png");image.file_format="PNG";image.save();image.pack()
for mat,bs,output,em,target in records:
    n=mat.node_tree.nodes;l=mat.node_tree.links
    l.new(bs.outputs[0],output.inputs["Surface"]);n.remove(em)
    u=n.new("ShaderNodeUVMap");u.uv_map="BakedUV";l.new(u.outputs["UV"],target.inputs["Vector"])
    l.new(target.outputs["Color"],bs.inputs["Base Color"])
for o in objects:
    o.data.uv_layers.active=o.data.uv_layers["BakedUV"]
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB")
(out/"bake-report.json").write_text(json.dumps({"sourceSha256":hashlib.sha256(src.read_bytes()).hexdigest(),"scope":"base color transfer only; original geometry retained; UV audit and visual review required","atlasSha256":hashlib.sha256((out/"atlas.png").read_bytes()).hexdigest()},indent=2))
