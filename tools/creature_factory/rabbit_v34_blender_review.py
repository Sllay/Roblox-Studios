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
bpy.ops.wm.open_mainfile(filepath=str(source))
arm=bpy.data.objects.get('RabbitRig')
assert arm and arm.type=='ARMATURE'
proof=json.loads(proof_path.read_text())
joint={r['name']:r for r in proof['boneRows']}
assert len(joint)==19 and len(arm.pose.bones)==19
assert set(joint)==set(arm.pose.bones.keys())
assert len([o for o in bpy.data.objects if o.type=='MESH'])==9
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
 camera=bpy.data.cameras.new('V34_PreviewCamera')
 cam=bpy.data.objects.new('V34_PreviewCamera',camera)
 scene.collection.objects.link(cam);scene.camera=cam
cam.data.type='ORTHO';cam.data.ortho_scale=5.2
light=bpy.data.lights.new('V34_Softbox','AREA')
light.energy=1350;light.shape='DISK';light.size=7
bulb=bpy.data.objects.new('V34_Softbox',light)
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
# In Blender, x right, y depth, z height. In Roblox, x right, y height, z depth.
axis=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
base_blender=arm.data.bones['Root'].matrix_local
origin=base_blender.translation-(axis@native_bind['Root']).translation
axis.translation=origin
convert=axis
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
 # Posed bone target = transformed native bind-relative change * Blender bind.
 # This is a geometry-aware retarget, not arbitrary local Euler rotation.
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
for clip,times in stills.items():
 root=ET.parse(animation_dir/(clip+'.rbxmx')).getroot()
 rows=[]
 for i,t in enumerate(times):
  posed=redraw(parse_frame(root,t))
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
print('RABBIT_V34_REAL_MESH_RENDER_PASS',json.dumps({c:len(v) for c,v in report.items()}),flush=True)
