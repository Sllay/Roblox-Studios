"""Build *candidate* mobile rabbit geometry from the immutable source Blender mesh.

Invoked by: blender -b --factory-startup --python ... -- SOURCE_BLEND V2_ALBEDO_2048 OUTDIR

Texture changes remain solely in the atlas; changes to geometry are stored in a
separate LOD candidate. Never mutate the master .blend in Git.
"""
from __future__ import annotations

import bpy
import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import numpy as np
from mathutils import Quaternion, Vector

EXPECTED_SOURCE_SHA = '25d3f62033b9cf633bf4d458517b8f01bf5c78731dbd970859d69e017e136d05'
TRIANGLE_LIMIT = 20_000
TOTAL_TARGET = 20_000
TARGETS = {'Rabbit_Torso': 13_200, 'FrontArm_L': 2_550, 'FrontArm_R': 2_550}
VIEWS = {'front': (0,-6,0),'right': (6,0,0),'left': (-6,0,0),
         'back': (0,6,0),'top': (0,0,6),'three-quarter':(-4,-6,1.3)}

args=sys.argv[sys.argv.index('--')+1:]
assert len(args) == 3, 'usage: SOURCE_BLEND V2_ALBEDO_2048 OUTDIR'
src,texture,out=Path(args[0]),Path(args[1]),Path(args[2]);out.mkdir(parents=True,exist_ok=True)
assert hashlib.sha256(src.read_bytes()).hexdigest()==EXPECTED_SOURCE_SHA, 'master version mismatch'
assert texture.is_file(), 'missing approved runtime albedo'
bpy.ops.wm.open_mainfile(filepath=str(src))
rig=bpy.data.objects['RabbitRig'];assert rig.type=='ARMATURE'
meshes=sorted((o for o in bpy.data.objects if o.type=='MESH'),key=lambda o:o.name)
assert len(meshes)==9 and sum(o.name.startswith('Whisker_') for o in meshes)==6
bones=sorted(b.name for b in rig.data.bones);assert len(bones)==19
for bone in rig.pose.bones:
    bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion((1,0,0,0));bone.location=(0,0,0);bone.scale=(1,1,1)

# Force the approved V2 color atlas onto the original mesh, replacing only paint.
image=bpy.data.images.load(str(texture),check_existing=False);image.name='Rabbit_Cartoon_V2_Runtime2048';image.pack()
mat=bpy.data.materials.new('Rabbit_Cartoon_V2_Runtime');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF')
bs.inputs['Metallic'].default_value=0
bs.inputs['Roughness'].default_value=.84
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
for o in meshes:
    assert len(o.data.uv_layers)==1 and o.data.uv_layers.active is not None, (o.name,'UV missing')
    assert o.vertex_groups, (o.name,'no deformation groups')
    o.data.materials.clear();o.data.materials.append(mat)
    for poly in o.data.polygons:poly.material_index=0
    for color in list(o.data.color_attributes):o.data.color_attributes.remove(color)

# The same fixed camera and render settings for source and LOD comparisons.
scene=bpy.context.scene
scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=True
scene.render.image_settings.color_depth='8'
scene.render.engine='BLENDER_EEVEE' if bpy.app.version < (4, 2, 0) else 'BLENDER_EEVEE_NEXT'
scene.render.filepath=str(out/'temp.png')
cam=scene.camera
if cam is None:
    camera_data=bpy.data.cameras.new('RabbitLOD_ReviewCamera')
    cam=bpy.data.objects.new('RabbitLOD_ReviewCamera',camera_data)
    scene.collection.objects.link(cam);scene.camera=cam
cam.data.type='ORTHO';cam.data.ortho_scale=5.2
center=Vector((0,0,1.8))
# Consistent neutral studio lighting for both master and LOD silhouette/color tests.
fill=bpy.data.lights.new('RabbitLOD_ReviewSoftbox','AREA')
fill.energy=1400;fill.shape='DISK';fill.size=7.0
light=bpy.data.objects.new('RabbitLOD_ReviewSoftbox',fill)
scene.collection.objects.link(light)
light.location=Vector((-3,-4,7))
light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()


def render(name,relative):
    cam.location=center+Vector(relative)
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)

for name,d in VIEWS.items():render('master-'+name,d)

before={o.name:{'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),
                'verts':len(o.data.vertices),'uv':len(o.data.uv_layers)} for o in meshes}
for name in TARGETS:
    o=bpy.data.objects[name]
    # Decimation must run on bind-pose mesh coordinates before the armature.
    for m in o.modifiers:
        if m.type=='ARMATURE':m.show_viewport=False
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
    ratio=TARGETS[name]/before[name]['triangles']
    dec=o.modifiers.new('RabbitRuntimeLOD_GeometricCollapse','DECIMATE')
    dec.decimate_type='COLLAPSE'
    dec.ratio=ratio
    dec.use_collapse_triangulate=True
    # Ensure decimation runs on the bind-pose mesh BEFORE armature skinning.
    # Applying an out-of-order modifier can silently alter rig deformations.
    while list(o.modifiers).index(dec)>0:
        bpy.ops.object.modifier_move_up(modifier=dec.name)
    bpy.ops.object.modifier_apply(modifier=dec.name)
    # Defensive triangulation: some Blender versions leave n-gons.
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm,faces=bm.faces[:],quad_method='BEAUTY',ngon_method='BEAUTY')
    bm.to_mesh(o.data);bm.free();o.data.update()
    for m in o.modifiers:
        if m.type=='ARMATURE':m.show_viewport=True

# Every whisker retains the original mesh, avoiding intermittent whisker gaps.
after={o.name:{'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),
               'verts':len(o.data.vertices),'uv':len(o.data.uv_layers)} for o in meshes}
assert all(after[n]['triangles']<=TRIANGLE_LIMIT for n in after),after
assert sum(v['triangles'] for v in after.values())<=TOTAL_TARGET,after
assert all(before[n]==after[n] for n in before if n.startswith('Whisker_'))
assert sorted(b.name for b in rig.data.bones)==bones

# Deformation weights are expected to remain attached after vertex collapses.
weight_report={}
for o in meshes:
    assert len(o.data.uv_layers)==1
    assert len(o.data.vertices)>0
    group_sums=[];zero_count=0
    for v in o.data.vertices:
        sw=sum(g.weight for g in v.groups)
        group_sums.append(sw)
        if sw<.98:zero_count+=1
    weight_report[o.name]={'min':float(min(group_sums)),'max':float(max(group_sums)),
                           'incomplete':zero_count}
    assert zero_count==0,(o.name,weight_report[o.name])
    assert max(group_sums)<1.02,(o.name,weight_report[o.name])

# Ensure actual posed mesh deformation. Pose parent/child separately, reset each.
def posed_vertices(obj):
    bpy.context.view_layer.update()
    eval_obj=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return np.asarray([tuple(v.co) for v in eval_obj.to_mesh().vertices],dtype=np.float64)

def restore():
    for b in rig.pose.bones:
        b.rotation_mode='QUATERNION';b.rotation_quaternion=Quaternion((1,0,0,0))
    bpy.context.view_layer.update()

restore()
checks={}
for bone,mesh_name,angle in [('Head','Rabbit_Torso',17),('Shoulder_L','FrontArm_L',20),
                             ('Shoulder_R','FrontArm_R',20),('Hip_L','Rabbit_Torso',12),
                             ('Hip_R','Rabbit_Torso',12)]:
    target=bpy.data.objects[mesh_name]
    baseline=posed_vertices(target)
    b=rig.pose.bones[bone]
    b.rotation_quaternion=Quaternion((1,0,0),math.radians(angle))
    bpy.context.view_layer.update()
    changed=posed_vertices(target)
    assert len(changed)==len(baseline)
    distances=np.linalg.norm(changed-baseline,axis=1)
    maximum=float(distances.max())
    checks[bone]={'mesh':mesh_name,'angle_deg':angle,'max_vertex_displacement':maximum}
    assert maximum>0.01,checks[bone]
    restore()

for name,d in VIEWS.items():render('lod-'+name,d)

# Export selected mesh and armature, not scene lights or cameras.
restore();bpy.ops.object.select_all(action='DESELECT')
for o in [rig]+meshes:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'rabbit_lod_mobile.glb'),export_format='GLB',use_selection=True,
                         export_animations=False,export_colors=False,export_apply=False)
# Editable Blender snapshot, additional source generated without changing master.
bpy.ops.wm.save_as_mainfile(filepath=str(out/'rabbit_lod_mobile.blend'))
report={'schema':1,'asset':'rabbit-v3-cartoon-v2-mobile-lod0','source_master_sha256':EXPECTED_SOURCE_SHA,
        'tex_source_sha256':hashlib.sha256(texture.read_bytes()).hexdigest(),
        'triangles_original':sum(v['triangles'] for v in before.values()),
        'triangles_runtime':sum(v['triangles'] for v in after.values()),
        'per_mesh_before':before,'per_mesh_after':after,
        'bone_names':bones,'whisker_count':6,'weight_report':weight_report,
        'pose_probes':checks,'roblox_studio_import_tested':False,
        'notes':['A geometry LOD candidate; no Roblox publishing performed.',
                 'Character skin/animation, mobile client FPS and art direction require in-engine validation.']}
(out/'build_report.json').write_text(json.dumps(report,indent=2)+'\n')
print('RABBIT_MOBILE_LOD_RESULT '+json.dumps({'triangles':report['triangles_runtime'],
      'rig_bones':len(bones),'pose_checks':list(checks),'source_sha256':EXPECTED_SOURCE_SHA}),flush=True)