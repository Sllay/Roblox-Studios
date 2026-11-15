"""Independent Blender topology-aware reduction for a neural surface."""
import bpy,bmesh,sys
from pathlib import Path
import numpy as np
src,dst,target=sys.argv[sys.argv.index("--")+1:]
a=np.load(src);target=int(target)
bpy.ops.wm.read_factory_settings(use_empty=True)
m=bpy.data.meshes.new("NeuralSurface");m.from_pydata(a["vertices"].tolist(),[],a["faces"].tolist());m.update()
o=bpy.data.objects.new("NeuralSurface",m);bpy.context.collection.objects.link(o)
o.select_set(True);bpy.context.view_layer.objects.active=o
mod=o.modifiers.new("Constrained collapse","DECIMATE");mod.decimate_type="COLLAPSE"
mod.ratio=min(1.0,target/len(m.polygons));mod.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=mod.name)
m=o.data
bm=bmesh.new();bm.from_mesh(m)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.to_mesh(m);bm.free();m.update();m.calc_loop_triangles()
np.savez(dst,vertices=np.array([tuple(v.co) for v in m.vertices],dtype=np.float64),
    faces=np.array([tuple(t.vertices) for t in m.loop_triangles],dtype=np.int32))
