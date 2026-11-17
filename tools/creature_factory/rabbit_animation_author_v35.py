"""Rabbit V35 MOTION REVIEW ONLY. Real native 19-bone FK + constrained paw IK.

Never upload or write a Place from this module. Original skinned mesh unchanged.
"""
from __future__ import annotations
import argparse,hashlib,json,math,sys
from pathlib import Path
import numpy as np
from scipy.optimize import least_squares
import rabbit_animation_author as legacy

# Phase, torso forward pitch, head counterpitch, root hop, forepaw Y/Z, hindpaw Y/Z.
# Paw trajectories use imported joint lengths and hard reachability gates.
BLOCKS={
 'Walk':[
  (0,-1.25,1.16,0,.21,-1.04,.21,.45),
  (.08,-1.36,1.26,-.10,.20,-1.00,.18,.49),
  (.19,-1.12,1.02,.12,.27,-1.10,.32,.70),
  (.40,-.97,.90,.60,.36,-1.45,.50,.78),
  (.58,-1.01,.91,.48,.38,-1.48,.39,.72),
  (.72,-1.25,1.12,.18,.07,-1.36,.30,.48),
  (.84,-1.33,1.21,0,.22,-1.08,.24,.48),
  (1,-1.25,1.16,0,.21,-1.04,.21,.45)],
 'Run':[
  (0,-1.31,1.20,0,.22,-1.04,.20,.52),
  (.09,-1.40,1.26,-.12,.20,-1.00,.13,.62),
  (.19,-1.06,.94,.24,.36,-1.20,.34,.72),
  (.39,-.82,.77,1.08,.48,-1.55,.48,.92),
  (.54,-1.00,.92,1.20,.46,-1.67,.54,.75),
  (.68,-1.08,.96,.75,.20,-1.65,.35,.72),
  (.79,-1.31,1.14,.18,.06,-1.40,.55,.42),
  (.88,-1.35,1.20,0,.22,-1.10,.22,.52),
  (1,-1.31,1.20,0,.22,-1.04,.20,.52)]
}
CLIPS={'Idle':(3,48,True,0),'Walk':(.91,48,True,1),
       'Run':(.64,48,True,1),'ScratchEar':(2.35,72,False,2)}

JOINTS={'Root','Pelvis','Chest','Head','Ear_L','Ear_R','Shoulder_L','Shoulder_R',
        'Forearm_L','Forearm_R','FrontPaw_L','FrontPaw_R','Hip_L','Hip_R',
        'Shin_L','Shin_R','HindPaw_L','HindPaw_R','Tail'}
RIG_RECEIPT=Path(__file__).resolve().parents[2]/'asset-library/roblox-receipts/s0910-rabbit/rabbit-native-proof.json'

def rotation(v):
 x,y,z=v;cx,sx=np.cos(x),np.sin(x);cy,sy=np.cos(y),np.sin(y);cz,sz=np.cos(z),np.sin(z)
 return np.array([[cz*cy,cz*sy*sx-sz*cx,cz*sy*cx+sz*sx],
                  [sz*cy,sz*sy*sx+cz*cx,sz*sy*cx-cz*sx],
                  [-sy,cy*sx,cy*cx]])
def matrix(r=None,p=None):
 a=np.eye(4);a[:3,:3]=np.eye(3) if r is None else r
 if p is not None:a[:3,3]=p
 return a
class NativeRig:
 def __init__(self,path=RIG_RECEIPT):
  proof=json.loads(Path(path).read_text())
  assert str(proof['assetId'])=='87498816533548' and proof['poseRoundtrip']
  self.bones={row['name']:(row['parent'],matrix(np.array(row['localFrame'][3:]).reshape(3,3),row['localFrame'][:3]))
              for row in proof['boneRows']}
  assert set(self.bones)==JOINTS
 def evaluate(self,values):
  cache={};local={}
  def visit(n):
   if n in cache:return cache[n]
   parent,rest=self.bones[n]
   prior=np.eye(4) if parent=='RootPart' else visit(parent)
   pose=prior@rest
   if n=='Root':
    delta=matrix(p=[0,float(values.get('RootYOffset',0)),0])
   else:
    world=rotation(values.get(n,[0,0,0]))
    delta=matrix(pose[:3,:3].T@world@pose[:3,:3])
   local[n]=delta;cache[n]=pose@delta
   return cache[n]
  for n in self.bones:visit(n)
  return cache,local
 def ik(self,base,kind,side,target):
  if kind=='fore': a,b,c=('Shoulder_'+side,'Forearm_'+side,'FrontPaw_'+side)
  else:a,b,c=('Hip_'+side,'Shin_'+side,'HindPaw_'+side)
  target=np.asarray(target,dtype=float)
  def pose(q):
   out=dict(base);out[a]=[q[0],q[1],q[2]];out[b]=[q[3],0,q[4]]
   return out
  def loss(q):
   fk,_=self.evaluate(pose(q))
   return np.r_[3*(fk[c][:3,3]-target),.035*np.asarray(q)]
  result=least_squares(loss,[0]*5,bounds=([-2,-1,-1.3,-2,-1],[2,1,1.3,2,1]),max_nfev=100)
  value=pose(result.x);fk,_=self.evaluate(value)
  return value,float(np.linalg.norm(fk[c][:3,3]-target))
def blocks(rig,clip):
 # Explicit rabbit gait: both hind legs push, both front feet brace first;
 # hind paws land as the hips pass over the foreleg contact patch.
 keys=[];report=[]
 for t,ch,hd,y,fy,fz,hy,hz in BLOCKS[clip]:
  v={'Pelvis':[.78*ch,0,0],'Chest':[.22*ch,0,0],
     'Head':[hd,0,0],'RootYOffset':y}
  errors=[]
  for kind,py,pz,width in (('fore',fy,fz,.36),('hind',hy,hz,.45)):
   for side,sign in (('L',1),('R',-1)):
    result,e=rig.ik(v,kind,side,[width*sign,py+y,pz])
    v.update(result);errors.append(e)
  assert max(errors)<.25,('unreachable_paw',clip,t,errors)
  # Secondary action follows the momentum, but preserves base paw contact.
  flight=max(0,min(1,y/1.2))
  v['Ear_L']=[-.16*flight,0,-.06*flight]
  v['Ear_R']=[-.14*flight,0,.06*flight]
  v['Tail']=[.18*flight,0,0]
  v['FrontPaw_L']=[-.12*flight,0,0]
  v['FrontPaw_R']=[-.12*flight,0,0]
  v['HindPaw_L']=[.10*flight,0,0]
  v['HindPaw_R']=[.10*flight,0,0]
  keys.append((t,v))
  fk,_=rig.evaluate(v)
  report.append({'phase':t,'root_y':y,'max_ik_error':max(errors),
                 'fore_y':float(fk['FrontPaw_L'][1,3]),
                 'hind_y':float(fk['HindPaw_L'][1,3])})
 return keys,report

def groom(rig):
 # Skin-safe ear grooming: the ear folds back toward the foot rather than
 # yanking a far-off hindpaw through 110 degrees of hip twist.
 rest,_=blocks(rig,'Walk')
 home=rest[0][1]
 b=dict(home)
 b['Chest']=np.asarray(home['Chest'])+[-.50,0,0]
 b['Ear_L']=[-1.0,0,-.10]
 fk,_=rig.evaluate(b)
 # Brush the lower rear base of the folded ear, not the upper tip.
 point=.50*fk['Ear_L'][:3,3]+.50*fk['Head'][:3,3]+[.05,-.13,.13]
 def pose(q):
  v=dict(b);v['Hip_L']=q[:3];v['Shin_L']=[q[3],0,q[4]]
  return v
 def objective(q):
  v=pose(q);fk,_=rig.evaluate(v)
  return np.r_[4*(fk['HindPaw_L'][:3,3]-point),.04*q]
 bounds=([-1.50,-.40,-.75,-1.60,-.90],[1.50,.40,.75,1.60,.90])
 opt=least_squares(objective,np.zeros(5),bounds=bounds,max_nfev=100)
 contact=pose(opt.x)
 fk,_=rig.evaluate(contact)
 error=float(np.linalg.norm(fk['HindPaw_L'][:3,3]-point))
 assert error<.07,('ear_outside_skin_safe_hind_reach',error)
 # Replant the other three paws, leaving the left hind foot free to groom.
 for kind,side,x,y,z in [('fore','L',.36,.21,-1.04),
                         ('fore','R',-.36,.21,-1.04),
                         ('hind','R',None,.21,None)]:
  if x is None:
   fk,_=rig.evaluate(contact);foot=fk['HindPaw_R'][:3,3]
   x,z=float(foot[0]),float(foot[2])
  contact,e=rig.ik(contact,kind,side,[x,y,z])
  assert e<.24,('support_contact',kind,side,e)
 keys=[];report=[]
 phases=[(0,0,0),(.15,.35,0),(.31,1,0),(.41,1,1),
         (.52,1,0),(.63,1,1),(.74,1,0),(.88,.35,0),(1,0,0)]
 for t,raised,rake in phases:
  values={bone:(1-raised)*np.asarray(home.get(bone,[0,0,0]))+
              raised*np.asarray(contact.get(bone,[0,0,0])) for bone in JOINTS}
  values['Ear_L']=np.asarray(values['Ear_L'])+[-.12*rake,0,-.03*rake]
  values['Shin_L']=np.asarray(values['Shin_L'])+[.055*rake,0,.025*rake]
  values['HindPaw_L']=np.asarray(values['HindPaw_L'])+[-.08*rake,0,0]
  values['RootYOffset']=0.
  fk,_=rig.evaluate(values)
  contact_point=.50*fk['Ear_L'][:3,3]+.50*fk['Head'][:3,3]+[.05,-.13,.13]
  distance=float(np.linalg.norm(fk['HindPaw_L'][:3,3]-contact_point))
  if raised==1:assert distance<.20,('hind_paw_ear_contact_lost',t,distance)
  keys.append((t,values))
  report.append({'phase':t,'hindpaw_to_ear_base_distance':distance,
                 'raised':raised,'ear_bend':rake,
                 'hip_pitch':float(values['Hip_L'][0]),
                 'hip_roll':float(values['Hip_L'][2])})
 assert all(np.allclose(keys[0][1][n],keys[-1][1][n]) for n in JOINTS)
 return keys,report

def idle(rig):
 base,_=blocks(rig,'Walk')
 pose=base[0][1];keys=[]
 for t,breath in [(0,0),(.25,1),(.5,0),(.75,-1),(1,0)]:
  v=dict(pose);v['Pelvis']=[-.78*1.27,0,0];v['Chest']=[-.22*1.27+.02*breath,0,0]
  v['Head']=[1.18-.02*breath,0,0]
  v['Ear_L']=[.035*breath,0,0];v['Ear_R']=[.035*breath,0,0]
  keys.append((t,v))
 return keys,[]
def ease(t):
 t=min(1,max(0,t));return t*t*(3-2*t)
def interpolate(keys,t):
 for i in range(1,len(keys)):
  b,vb=keys[i]
  if t<=b:
   a,va=keys[i-1];s=ease((t-a)/(b-a))
   out={k:(1-s)*np.asarray(va.get(k,[0,0,0]))+s*np.asarray(vb.get(k,[0,0,0])) for k in JOINTS}
   out['RootYOffset']=(1-s)*va.get('RootYOffset',0)+s*vb.get('RootYOffset',0)
   return out
 return keys[-1][1]
RIG=None
CACHE={}
EVIDENCE={}
def motion(clip,name,t):
 key=(clip,round(t,8))
 if key not in CACHE:
  values=interpolate(EVIDENCE[clip]['keys'],t)
  global_fk,local=RIG.evaluate(values)
  CACHE[key]=(values,global_fk,local)
 values,fk,local=CACHE[key]
 cf=local[name]
 return tuple(float(v) for v in np.r_[cf[:3,3],cf[:3,:3].reshape(9)])
def main():
 ap=argparse.ArgumentParser();ap.add_argument('source_glb',type=Path);ap.add_argument('out_dir',type=Path);a=ap.parse_args()
 global RIG
 RIG=NativeRig()
 for clip in CLIPS:
  keys,report=(idle(RIG) if clip=='Idle' else groom(RIG) if clip=='ScratchEar' else blocks(RIG,clip))
  EVIDENCE[clip]={'keys':keys,'blocking':report}
 # Original XML serializer preserves the exact same native 19-bone paths.
 legacy.CLIPS=CLIPS;legacy.motion=motion
 argv=sys.argv;sys.argv=['rabbit_animation_author.py',str(a.source_glb),str(a.out_dir)]
 try:legacy.main()
 finally:sys.argv=argv
 manifest=json.loads((a.out_dir/'manifest.json').read_text())
 manifest['stage']='v35_visual_review_required_no_roblox_upload_or_place_write'
 for clip,row in manifest['clips'].items():
  rows=[]
  for i in range(CLIPS[clip][1]+1):
   t=i/CLIPS[clip][1];v,fk,_=CACHE[(clip,round(t,8))]
   rows.append({'t':round(t,4),'root_y':round(float(v['RootYOffset']),3),
                'head':fk['Head'][:3,3].round(4).tolist(),
                'forepaw':fk['FrontPaw_L'][:3,3].round(4).tolist(),
                'forepaw_right':fk['FrontPaw_R'][:3,3].round(4).tolist(),
                'hindpaw':fk['HindPaw_L'][:3,3].round(4).tolist(),
                'hindpaw_right':fk['HindPaw_R'][:3,3].round(4).tolist(),
                'ear':fk['Ear_L'][:3,3].round(4).tolist()})
  row['samples']=rows
  row['blocking']=EVIDENCE[clip]['blocking']
 (a.out_dir/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('RABBIT_V35_PREVIEW_ONLY',json.dumps({k:{'frames':v['frames'],'duration':v['duration']} for k,v in manifest['clips'].items()}),flush=True)
if __name__=='__main__':main()
