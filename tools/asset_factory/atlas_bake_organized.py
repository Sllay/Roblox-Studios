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
proxies=[]
for o in objects:
    o.data=o.data.copy();m=o.data
    old=m.uv_layers.active
    assert old
    old.name="SourceUV"
    new=m.uv_layers.new(name="BakedUV")
    m.uv_layers.active=new;new.active_render=True
    # Unwrap a welded proxy, then transfer only UV corners back to the source.
    proxy=m.copy()
    bm=bmesh.new();bm.from_mesh(proxy)
    ids=bm.faces.layers.int.new("source_face")
    for f in bm.faces:f[ids]=f.index
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bm.normal_update()
    # Separate broad blade faces from the rim; keep the rim connected except one cut.
    if "blade" in o.name.lower():
        axis=min(range(3),key=lambda a:max(v.co[a] for v in bm.verts)-min(v.co[a] for v in bm.verts))
        def region(f):
            n=f.normal[axis]
            return 1 if n>0.7 else -1 if n< -0.7 else 0
        rim=[]
        for e in bm.edges:
            e.seam=not e.is_manifold or len({region(f) for f in e.link_faces})>1
            if e.is_manifold and all(region(f)==0 for f in e.link_faces) and abs((e.verts[1].co-e.verts[0].co)[axis])>1e-6:rim.append(e)
        if rim:max(rim,key=lambda e:abs((e.verts[1].co-e.verts[0].co)[axis])).seam=True
    else:
        for e in bm.edges:e.seam=not e.is_manifold or e.calc_face_angle(0)>math.radians(55)
    bm.to_mesh(proxy);bm.free()
    p=bpy.data.objects.new("UVProxy",proxy);bpy.context.collection.objects.link(p)
    p.matrix_world=o.matrix_world.copy()
    bpy.ops.object.select_all(action="DESELECT");p.select_set(True);bpy.context.view_layer.objects.active=p
    proxy.uv_layers.active=proxy.uv_layers["BakedUV"]
    bpy.context.scene.tool_settings.use_uv_select_sync=True
    bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED",margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    proxies.append((o,p))
    continue
# Pack connected proxies, never the split source topology.
bpy.ops.object.select_all(action="DESELECT")
for o,p in proxies:p.select_set(True)
bpy.context.view_layer.objects.active=proxies[0][1]
bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT");bpy.ops.uv.select_all(action="SELECT")
bpy.ops.uv.average_islands_scale();bpy.ops.uv.pack_islands(margin=0.02)
bpy.ops.object.mode_set(mode="OBJECT")
for o,p in proxies:
    m=o.data;proxy=p.data;new=m.uv_layers["BakedUV"]
    assert len(proxy.polygons)==len(m.polygons),"Proxy changed face count"
    faceids=proxy.attributes["source_face"].data
    for f in proxy.polygons:
        original=m.polygons[faceids[f.index].value]
        assert len(f.loop_indices)==len(original.loop_indices)
        for j in original.loop_indices:
            pos=m.vertices[m.loops[j].vertex_index].co
            matches=[k for k in f.loop_indices if (proxy.vertices[proxy.loops[k].vertex_index].co-pos).length<1e-6]
            assert len(matches)==1,"Ambiguous proxy corner"
            new.data[j].uv=proxy.uv_layers["BakedUV"].data[matches[0]].uv
    bpy.data.objects.remove(p,do_unlink=True)
    bpy.data.meshes.remove(proxy)
    bpy.ops.object.select_all(action="DESELECT");o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.context.scene.tool_settings.use_uv_select_sync=True
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

scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=16
scene.cycles.use_denoising=False
for layer in scene.view_layers:layer.cycles.use_denoising=False
scene.render.bake.margin=8
# Bake each mesh separately, retaining previously baked islands.
for i,o in enumerate(objects):
    bpy.ops.object.select_all(action="DESELECT");o.select_set(True);bpy.context.view_layer.objects.active=o
    scene.render.bake.use_clear=(i==0)
    bpy.ops.object.bake(type="EMIT",uv_layer="BakedUV")
# Reject empty/near-black output rather than exporting a broken atlas.
import numpy as np
pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
rgb=pixels.reshape(-1,4)[:,:3]
assert np.count_nonzero(rgb.max(axis=1)>0.05)>1024,"Bake produced empty or near-black atlas"
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
