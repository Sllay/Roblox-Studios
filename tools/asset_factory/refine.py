"""Blender candidate refinement with measured silhouette acceptance."""
import bpy, math
from mathutils import Vector
def metrics(obj):
    m=obj.data;m.calc_loop_triangles()
    return {"triangles":len(m.loop_triangles),"vertices":len(m.vertices),"area":sum(p.area for p in m.polygons)}
def candidate(source,kind):
    o=source.copy();o.data=source.data.copy();bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT");o.select_set(True);bpy.context.view_layer.objects.active=o
    if kind=="organic":
        # Taubin-style alternating Laplacian passes reduce shrinkage.
        for factor in (.45,-.47,.45,-.47):
            mod=o.modifiers.new("Surface relaxation","SMOOTH");mod.factor=factor;mod.iterations=1
            bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new("Mobile reduction","DECIMATE");mod.ratio=.25
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for p in o.data.polygons:p.use_smooth=True
    elif kind=="hard":
        mod=o.modifiers.new("Planar simplification","DECIMATE");mod.decimate_type="DISSOLVE";mod.angle_limit=.01
        bpy.ops.object.modifier_apply(modifier=mod.name)
    else:raise ValueError(kind)
    return o
def choose(source,kind,measure,min_iou=.90):
    baseline=measure(source,"baseline")
    o=candidate(source,kind);scores=measure(o,"candidate")
    accepted=min(scores.values())>=min_iou and all(scores[k]>=baseline[k]-.05 for k in baseline)
    result=o if accepted else source
    return result,{"kind":kind,"baseline":baseline,"candidate":scores,"accepted":accepted,"before":metrics(source),"after":metrics(result)}
