import bpy,sys,json,hashlib,struct
from pathlib import Path
src,png,out=map(Path,sys.argv[sys.argv.index("--")+1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src.resolve()))
obj=next(o for o in bpy.context.scene.objects if o.type=="MESH")
uv=obj.data.uv_layers.active
idx=0
h=hashlib.sha256()
for p in obj.data.polygons:
    if p.material_index==idx:
        h.update(struct.pack("<I",len(p.loop_indices)))
        for i in p.loop_indices:
            h.update(struct.pack("<Iff",obj.data.loops[i].vertex_index,*uv.data[i].uv))
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
out.write_text(json.dumps({"schema":1,"modelSha256":digest(src),"pngSha256":digest(png),"object":obj.name,"materialSlot":idx,"material":obj.material_slots[idx].material.name,"uv":uv.name,"uvSha256":h.hexdigest()}))
