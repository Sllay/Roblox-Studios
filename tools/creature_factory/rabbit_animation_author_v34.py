"""Rabbit V34 REVIEW ONLY. Real native 19-bone FK + constrained paw IK.

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
 'Walk':[(0,-1.27,1.18,0,.23,-.98,.22,.40),(.13,-1.31,1.22,-.04,.20,-.94,.18,.58),
         (.31,-1.03,.93,.43,.48,-1.16,.39,.72),(.48,-1.02,.94,.56,.52,-1.25,.46,.65),
         (.69,-1.20,1.12,.28,.24,-1.15,.27,.43),(.85,-1.27,1.18,0,.23,-1.04,.22,.40),
         (1,-1.27,1.18,0,.23,-.98,.22,.40)],
 'Run':[(0,-1.35,1.23,-.04,.22,-.98,.20,.43),(.14,-1.24,1.12,-.08,.23,-.96,.18,.65),
        (.31,-.96,.87,.66,.53,-1.20,.49,.76),(.49,-1.14,1.07,1,.54,-1.34,.44,.84),
        (.69,-1.18,1.10,.65,.30,-1.34,.42,.68),(.85,-1.35,1.23,0,.22,-1.04,.20,.46),
        (1,-1.35,1.23,-.04,.22,-.98,.20,.43)]
}
CLIPS={'Idle':(3,40,True,0),'Walk':(.79,40,True,1),'Run':(.68,40,True,1),'ScratchEar':(2.35,64,False,2)}
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
 keys=[];report=[]
 for t,ch,hd,y,fy,fz,hy,hz in BLOCKS[clip]:
  # Distribute spine pitch over pelvis and chest: avoid a 90-degree kink.
  v={'Pelvis':[.78*ch,0,0],'Chest':[.22*ch,0,0],
     'Head':[hd,0,0],'RootYOffset':y};errors=[]
  for kind,py,pz,width in (('fore',fy,fz,.36),('hind',hy,hz,.45)):
   for side,sign in (('L',1),('R',-1)):
    result,e=rig.ik(v,kind,side,[width*sign,py+y,pz])
    v.update(result);errors.append(e)
  assert max(errors)<.23,(clip,t,errors)
  keys.append((t,v));report.append({'phase':t,'root_y':y,'max_ik_error':max(errors)})
 return keys,report
def groom(rig):
 # Begin and finish in the SAME natural crouch used by Idle/Walk.
 # Solve ONE physically reachable forepaw-to-ear contact pose, then blend to
 # it rather than allowing the elbow solver to flip branches mid-motion.
 rest,_=blocks(rig,'Walk')
 home=rest[0][1]
 b=dict(home)
 b['Pelvis']=[-1.27*.78+.18,0,0]
 b['Chest']=[-1.27*.22+.08,0,0]
 b['Head']=[1.18-.14,0,0]
 b['Ear_L']=[-.35,0,-.10]
 fk,_=rig.evaluate(b)
 target=fk['Ear_L'][:3,3]+np.array([.04,-.23,-.06])
 contact,error=rig.ik(b,'fore','L',target)
 assert error<.11,('ear_contact',error)
 keys=[];report=[]
 for t,raised,rake in [(0,0,0),(.17,.45,0),(.33,1,0),(.43,1,1),
                        (.54,1,0),(.64,1,1),(.74,1,0),(.85,.5,.4),(1,0,0)]:
  values={}
  for bone in JOINTS:
   values[bone]=(1-raised)*np.asarray(home.get(bone,[0,0,0]))+raised*np.asarray(contact.get(bone,[0,0,0]))
  values['Ear_L']=np.asarray(values['Ear_L'])+[-.24*rake,0,0]
  values['FrontPaw_L']=np.asarray(values['FrontPaw_L'])+[.10*rake,0,0]
  values['RootYOffset']=0.0
  fk,_=rig.evaluate(values)
  distance=float(np.linalg.norm(fk['FrontPaw_L'][:3,3]-fk['Ear_L'][:3,3]))
  if raised==1:assert distance<.46,(t,distance)
  keys.append((t,values))
  report.append({'phase':t,'forepaw_to_ear_distance':distance,'raised':raised})
 assert np.linalg.norm(keys[0][1]['Chest']-keys[-1][1]['Chest'])<1e-9
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
 manifest['stage']='visual_review_required_no_roblox_upload_or_place_write'
 for clip,row in manifest['clips'].items():
  rows=[]
  for i in range(CLIPS[clip][1]+1):
   t=i/CLIPS[clip][1];v,fk,_=CACHE[(clip,round(t,8))]
   rows.append({'t':round(t,4),'root_y':round(float(v['RootYOffset']),3),
                'head':fk['Head'][:3,3].round(4).tolist(),
                'forepaw':fk['FrontPaw_L'][:3,3].round(4).tolist(),
                'hindpaw':fk['HindPaw_L'][:3,3].round(4).tolist(),
                'ear':fk['Ear_L'][:3,3].round(4).tolist()})
  row['samples']=rows
  row['blocking']=EVIDENCE[clip]['blocking']
 (a.out_dir/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('RABBIT_V34_PREVIEW_ONLY',json.dumps({k:{'frames':v['frames'],'duration':v['duration']} for k,v in manifest['clips'].items()}),flush=True)
if __name__=='__main__':main()
