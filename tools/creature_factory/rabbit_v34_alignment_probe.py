"""Read-only anatomical calibration: native Roblox bone frames vs Blender armature.

Fits a single global similarity transform using all 19 rest joints. If no
consistent transform exists, preview re-targeting is INVALID and must stop.
"""
import bpy,json,sys,math
import numpy as np
from pathlib import Path
args=sys.argv[sys.argv.index('--')+1:]
assert len(args)==3
blend,receipt,out=map(Path,args)
bpy.ops.wm.open_mainfile(filepath=str(blend))
arm=bpy.data.objects['RabbitRig']
assert arm.type=='ARMATURE'
rows=json.loads(receipt.read_text())['boneRows']
native={r['name']:r for r in rows}
assert len(native)==19 and set(native)==set(x.name for x in arm.data.bones)
def matrix(local):
 t=np.asarray(local[:3],dtype=float)
 r=np.asarray(local[3:],dtype=float).reshape(3,3)
 a=np.eye(4);a[:3,:3]=r;a[:3,3]=t
 return a
cache={}
def fk(n):
 if n in cache:return cache[n]
 row=native[n];parent=row['parent']
 a=np.eye(4) if parent=='RootPart' else fk(parent)
 cache[n]=a@matrix(row['localFrame'])
 return cache[n]
names=sorted(native)
src=np.array([fk(n)[:3,3] for n in names])
dst=np.array([arm.data.bones[n].matrix_local.translation[:] for n in names])
mu_a=src.mean(0);mu_b=dst.mean(0)
a=src-mu_a;b=dst-mu_b
u,s,vt=np.linalg.svd(a.T@b)
mirror=np.diag([1,1,np.linalg.det(vt.T@u.T)])
R=vt.T@mirror@u.T
scale=np.sum((a@R.T)*b)/np.sum(a*a)
offset=mu_b-scale*R@mu_a
expected=src@R.T*scale+offset
error=np.linalg.norm(expected-dst,axis=1)
report={'names':names,'rms':float(np.sqrt(np.mean(error*error))),
        'max_error':float(error.max()),'scale':float(scale),
        'rotation':R.tolist(),'translation':offset.tolist(),
        'all':{n:{'native':src[i].tolist(),'blend':dst[i].tolist(),
                  'mapped':expected[i].tolist(),'residual':float(error[i])}
               for i,n in enumerate(names)}}
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(report,indent=2)+'\n')
print('RABBIT_V34_REST_ALIGNMENT',json.dumps({
    'rms':report['rms'],'max_error':report['max_error'],
    'scale':report['scale'],'rotation':report['rotation'],
    'highest_error_joints':sorted(((n,report['all'][n]['residual']) for n in names),
                                   key=lambda x:-x[1])[:7]}),flush=True)
