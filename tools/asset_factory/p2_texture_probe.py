import bpy,sys,json,math
from pathlib import Path
import numpy as np
from PIL import Image
from mathutils import Vector
out=Path(sys.argv[sys.argv.index("--")+1]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out.parent/"p2-color"/"asset.glb"))
o=next(o for o in bpy.context.scene.objects if o.type=="MESH")
bpy.context.view_layer.objects.active=o;o.select_set(True)
# Triangulate for explicit per-face atlas islands.
mod=o.modifiers.new("Triangles","TRIANGULATE");bpy.ops.object.modifier_apply(modifier=mod.name)
m=o.data;uv=m.uv_layers.new(name="ProjectionAtlas")
refs={k:np.asarray(Image.open(out.parent/"p2-color"/("reference-"+k+".png")).convert("RGBA")) for k in ("front","right","top")}
# One padded tile per triangle; barycentric projection, view weights from normals.
tile=32;cols=math.ceil(math.sqrt(len(m.polygons)));size=cols*tile
atlas=np.zeros((size,size,4),dtype=np.uint8);atlas[:,:,3]=255
fallback=0;total=0
for p in m.polygons:
    ix=p.index%cols*tile;iy=p.index//cols*tile
    coords=[o.matrix_world@m.vertices[i].co for i in p.vertices]
    normal=p.normal
    weights={"front":max(0,-normal.y),"right":max(0,normal.x),"top":max(0,normal.z)}
    if sum(weights.values())<.001:weights={k:abs(v) for k,v in zip(("front","right","top"),(normal.y,normal.x,normal.z))}
    for j,li in enumerate(p.loop_indices):
        a,b=((3,3),(tile-4,3),(3,tile-4))[j];uv.data[li].uv=((ix+a+.5)/size,1-(iy+b+.5)/size)
    for y in range(tile):
        for x in range(tile):
            b=max(0,(x-3)/(tile-7));c=max(0,(y-3)/(tile-7));s=max(1,b+c);b/=s;c/=s
            q=coords[0]*(1-b-c)+coords[1]*b+coords[2]*c
            samples=[]
            for k,(u,v) in {"front":(q.x,q.z),"right":(q.y,q.z),"top":(q.x,q.y)}.items():
                im=refs[k];h,w=im.shape[:2];px=min(w-1,max(0,int((u+1)*w/2)));py=min(h-1,max(0,int((1-v)*h/2)))
                color=im[py,px]
                if color[3]>127 and weights[k]>0:samples.append((color[:3],weights[k]))
            total+=1
            if samples:rgb=sum(c*w for c,w in samples)/sum(w for c,w in samples)
            else:rgb=np.array([100,85,65]);fallback+=1
            atlas[iy+y,ix+x,:3]=rgb
Image.fromarray(atlas).save(out/"texture.png")
mat=bpy.data.materials.new("ProjectedColor");mat.use_nodes=True
nodes=mat.node_tree.nodes;tex=nodes.new("ShaderNodeTexImage");tex.image=bpy.data.images.load(str(out/"texture.png"));tex.image.pack()
mat.node_tree.links.new(tex.outputs["Color"],nodes.get("Principled BSDF").inputs["Base Color"])
o.data.materials.clear();o.data.materials.append(mat)
for p in m.polygons:p.material_index=0
bpy.ops.export_scene.gltf(filepath=str(out/"asset.glb"),export_format="GLB",use_selection=True)
scene=bpy.context.scene;scene.render.engine="BLENDER_WORKBENCH";scene.display.shading.color_type="TEXTURE";scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type="ORTHO";cam.data.ortho_scale=2.2
for k,d in {"front":(0,-4,0),"right":(4,0,0),"top":(0,0,4),"back":(0,4,0)}.items():
    cam.location=Vector(d);cam.rotation_euler=(0,0,0) if k=="top" else (-cam.location).to_track_quat("-Z","Y").to_euler();scene.render.filepath=str(out/(k+".png"));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/"asset.blend"))
report={"triangles":len(m.polygons),"atlasSize":size,"fallbackFraction":fallback/total,"uvLoops":len(uv.data),"published":False,"limitations":"normal weighted projection; no occlusion or unseen texture guarantee"}
assert fallback/total<.5
(out/"report.json").write_text(json.dumps(report,indent=2));print("P2_TEXTURE "+json.dumps(report),flush=True)
