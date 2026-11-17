"""Pose actual mobile skinned rabbit mesh from native reviewed .rbxmx frames.

Outputs real evaluated-mesh front/side contact frames, not bone-only diagnostics.
The native->Blender rest alignment is solved from Root, and each pose is
retargeted with a full global-space delta. No edits to master or Roblox.
Run with: blender -b --python this.py -- MODEL_BLEND NATIVE_PROOF XML_DIR OUT_DIR
"""
import bpy,json,math,sys,xml.etree.ElementTree as ET
from pathlib import Path
from mathutils import Matrix,Vector

args=sys.argv[sys.argv.index('--')+1:]
assert len(args)==4
source,proof_path,animation_dir,out=map(Path,args)
out.mkdir(parents=True,exist_ok=True)
assert source.suffix.lower()=='.glb','Use the reviewed candidate GLB only'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
arm=next((o for o in bpy.data.objects if o.type=='ARMATURE'),None)
assert arm and arm.type=='ARMATURE'
arm.name='RabbitRig'
proof=json.loads(proof_path.read_text())
joint={r['name']:r for r in proof['boneRows']}
assert len(joint)==19 and len(arm.pose.bones)==19
assert set(joint)==set(arm.pose.bones.keys())
assert len([o for o in bpy.data.objects if o.type=='MESH'])==9
# Real contact reference: feet at rest should be near this floor, not
# hovering without context as in the early V34 inspection sheets.
bpy.ops.mesh.primitive_plane_add(size=20,location=(0,0,0))
ground=bpy.context.object;ground.name='ReviewGround_ONLY'
ground_mat=bpy.data.materials.new('Ground_Review_Neutral')
ground_mat.diffuse_color=(.68,.70,.73,1)
ground.data.materials.append(ground_mat)
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE' if bpy.app.version<(4,2,0) else 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x=550;scene.render.resolution_y=550
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=True
scene.render.image_settings.color_depth='8'
scene.render.filepath=str(out/'scratch.png')
scene.render.image_settings.compression=35
scene.view_settings.view_transform='Standard'
cam=scene.camera
if cam is None:
 camera=bpy.data.cameras.new('V36_PreviewCamera')
 cam=bpy.data.objects.new('V36_PreviewCamera',camera)
 scene.collection.objects.link(cam);scene.camera=cam
cam.data.type='ORTHO';cam.data.ortho_scale=5.2
light=bpy.data.lights.new('V36_Softbox','AREA')
light.energy=1350;light.shape='DISK';light.size=7
bulb=bpy.data.objects.new('V36_Softbox',light)
scene.collection.objects.link(bulb)
bulb.location=(4,-4,6)
bulb.rotation_euler=(Vector((0,0,1.3))-bulb.location).to_track_quat('-Z','Y').to_euler()

def mat12(values):
 v=list(map(float,values))
 return Matrix(((v[3],v[4],v[5],v[0]),
                (v[6],v[7],v[8],v[1]),
                (v[9],v[10],v[11],v[2]),
                (0,0,0,1)))

rest={name:mat12(row['localFrame']) for name,row in joint.items()}
def native_global(poses):
 cache={}
 def solve(n):
  if n in cache:return cache[n]
  parent=joint[n]['parent']
  base=Matrix.Identity(4) if parent=='RootPart' else solve(parent)
  cache[n]=base@rest[n]@poses.get(n,Matrix.Identity(4))
  return cache[n]
 for n in joint:solve(n)
 return cache
native_bind=native_global({})
# Calibrated from ALL 19 actual native and Blender bind joints:
# Blender X=-Roblox X, Blender Y=Roblox Z, Blender Z=Roblox Y.
# Wrong handedness produced the previous grotesquely warped review images.
axis=Matrix(((-1,0,0,0),(0,0,1,0),(0,1,0,0),(0,0,0,1)))
base_blender=arm.data.bones['Root'].matrix_local
origin=base_blender.translation-(axis@native_bind['Root']).translation
axis.translation=origin
convert=axis
rest_error=max((convert@native_bind[name]).translation.__sub__(
    arm.data.bones[name].matrix_local.translation).length for name in joint)
assert rest_error<.001,('Native to Blender rest alignment invalid',rest_error)
print('RABBIT_V36_BIND_ALIGNMENT_PASS',rest_error,flush=True)
native_bind_inv={name:transform.inverted() for name,transform in native_bind.items()}

def parse_frame(root,num):
 keys=root.findall('.//Item[@class="Keyframe"]')
 key=keys[int(round(num*(len(keys)-1)))]
 poses={}
 for p in key.findall('.//Item[@class="Pose"]'):
  props=p.find('Properties')
  name=props.find('string[@name="Name"]').text
  coord=props.find('CoordinateFrame[@name="CFrame"]')
  v=[float(coord.find(key).text) for key in ('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22')]
  poses[name]=mat12(v)
 assert len(poses)==20 and 'RootPart' in poses
 poses.pop('RootPart')
 return poses

def redraw(poses):
 animated=native_global(poses)
 # Reset inherited channel matrices between independent poses. Blender's pose
 # matrix setter uses the CURRENT evaluated parent state. Without updating the
 # dependency graph after EACH parent, children silently inherit stale
 # transforms from the previous rendered keyframe; even Idle used to distort.
 for bone in arm.pose.bones:
  bone.matrix_basis.identity()
 bpy.context.view_layer.update()
 for name in sorted(joint,key=lambda n:ancestry(n)):
  d=animated[name]@native_bind_inv[name]
  goal=convert@d@convert.inverted()@arm.data.bones[name].matrix_local
  arm.pose.bones[name].matrix=goal
  bpy.context.view_layer.update()
 return animated

def ancestry(n):
 depth=0
 while joint[n]['parent']!='RootPart':
  depth+=1;n=joint[n]['parent']
 return depth
views={'side':Vector((6,0,1.2)), 'three-quarter':Vector((-4,-6,1.7))}
center=Vector((0,0,1.35))
stills={
 'idle':[0,.26,.5],
 'walk':[0,.13,.31,.48,.69,.85],
 'run':[0,.14,.31,.49,.69,.85],
 'scratchear':[0,.17,.33,.43,.54,.64,.74,1.]
}
report={}
idle_mesh=None
for clip,times in stills.items():
 root=ET.parse(animation_dir/(clip+'.rbxmx')).getroot()
 rows=[]
 for i,t in enumerate(times):
  posed=redraw(parse_frame(root,t))
  if clip=='idle':
   # For a subtle breathing idle, the skinned torso MUST remain nearly still.
   torso=bpy.data.objects['Rabbit_Torso']
   depsgraph=bpy.context.evaluated_depsgraph_get()
   evaluated=torso.evaluated_get(depsgraph)
   mesh=evaluated.to_mesh()
   points=[tuple(v.co) for v in mesh.vertices]
   evaluated.to_mesh_clear()
   if idle_mesh is None:
    idle_mesh=points
   else:
    assert len(points)==len(idle_mesh)
    displacement=max((Vector(a)-Vector(b)).length for a,b in zip(points,idle_mesh))
    print('RABBIT_V36_IDLE_MESH_MAX_DISPLACEMENT',round(displacement,5),flush=True)
    assert displacement<.2,('Breathing idle must not fold/skew the torso',displacement)
  for view,relative in views.items():
   cam.location=center+relative
   cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
   target=out/(clip+'-'+view+'-'+str(i).zfill(2)+'.png')
   scene.render.filepath=str(target)
   bpy.ops.render.render(write_still=True)
  row={'phase':t,'head':list(posed['Head'].translation),
       'forepaw':list(posed['FrontPaw_L'].translation),
       'hindpaw':list(posed['HindPaw_L'].translation),
       'left_ear':list(posed['Ear_L'].translation)}
  rows.append(row)
 report[clip]=rows
(out/'native-to-blender-posed-report.json').write_text(json.dumps(
 {'schema':1,'model':str(source),'source':'real_skinned_blender_mesh','rendered_views':list(views),
 'snapshots':report},indent=2)+'\n')
print('RABBIT_V36_REAL_MESH_RENDER_PASS',json.dumps({c:len(v) for c,v in report.items()}),flush=True)
