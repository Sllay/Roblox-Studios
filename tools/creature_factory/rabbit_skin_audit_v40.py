"""Audit the real Blender rabbit mesh skinning; fail on invalid vertex weights.

Usage: blender -b --python rabbit_skin_audit_v40.py -- MODEL.blend OUT.json
This tool does not mutate source assets or publish to Roblox.
"""
import bpy, json, math, sys
from collections import Counter
from pathlib import Path

args=sys.argv[sys.argv.index('--')+1:]
assert len(args)==2, 'expected MODEL.blend OUT.json'
source, destination=map(Path,args)
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=bpy.data.objects.get('RabbitRig')
assert rig and rig.type=='ARMATURE'
bones=set(rig.data.bones.keys())
assert len(bones)==19, ('unexpected bone count',len(bones))
report={'schema':1,'source':str(source),'bones':sorted(bones),'meshes':{},'errors':[],'warnings':[]}
for obj in sorted((o for o in bpy.data.objects if o.type=='MESH'),key=lambda o:o.name):
    names={g.index:g.name for g in obj.vertex_groups}
    vertex_count=len(obj.data.vertices)
    stats=Counter()
    bad=[]
    dominant=Counter()
    for vert in obj.data.vertices:
        influences=[(names.get(g.group,'<missing>'),float(g.weight)) for g in vert.groups if g.weight>1e-6]
        total=sum(weight for _,weight in influences)
        if not influences: stats['unweighted']+=1
        if len(influences)>4: stats['more_than_four']+=1
        if influences and abs(total-1)>0.005: stats['not_normalized']+=1
        if any(name not in bones for name,_ in influences): stats['invalid_bone']+=1
        if any(not math.isfinite(w) or w<0 for _,w in influences): stats['invalid_weight']+=1
        if influences: dominant[max(influences,key=lambda item:item[1])[0]]+=1
        if len(bad)<30 and (not influences or len(influences)>4 or abs(total-1)>0.005 or any(n not in bones for n,_ in influences)):
            bad.append({'vertex':vert.index,'weights':influences,'sum':round(total,6)})
    modifiers=[m for m in obj.modifiers if m.type=='ARMATURE']
    if not modifiers or any(m.object!=rig for m in modifiers):
        report['errors'].append(f'{obj.name}: missing or incorrect armature modifier')
    if stats['unweighted'] or stats['invalid_bone'] or stats['invalid_weight'] or stats['not_normalized']:
        report['errors'].append(f'{obj.name}: invalid skinning {dict(stats)}')
    if stats['more_than_four']:
        report['warnings'].append(f'{obj.name}: {stats["more_than_four"]} vertices have >4 influences')
    # Adjacent vertices with sharply different influences are candidates for
    # visible skinning seams, even when every weight sums to exactly one.
    weight_vectors=[]
    for vert in obj.data.vertices:
        weight_vectors.append({names.get(g.group,'<missing>'):float(g.weight)
                               for g in vert.groups if g.weight>1e-6})
    abrupt=[]
    for edge in obj.data.edges:
        a,b=edge.vertices
        wa,wb=weight_vectors[a],weight_vectors[b]
        delta=sum(abs(wa.get(bone,0)-wb.get(bone,0))
                  for bone in wa.keys()|wb.keys())/2
        distance=(obj.data.vertices[a].co-obj.data.vertices[b].co).length
        if delta>.65 and distance<.18:
            abrupt.append({'edge':[int(a),int(b)],'weight_delta':round(delta,4),
                           'length':round(distance,5)})
    abrupt.sort(key=lambda item:-item['weight_delta'])
    if abrupt:
        report['warnings'].append(f'{obj.name}: {len(abrupt)} abrupt weight edges; inspect deformation')
    report['meshes'][obj.name]={'vertices':vertex_count,'stats':dict(stats),'dominant_bones':dict(dominant),'bad_samples':bad,'abrupt_weight_edges':len(abrupt),'abrupt_samples':abrupt[:30]}
destination.parent.mkdir(parents=True,exist_ok=True)
destination.write_text(json.dumps(report,indent=2)+'\n')
print('RABBIT_V40_SKIN_AUDIT',json.dumps({'errors':report['errors'],'warnings':report['warnings'],'meshes':len(report['meshes'])}),flush=True)
if report['errors']: sys.exit(2)
