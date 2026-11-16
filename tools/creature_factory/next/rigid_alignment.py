"""C3-B bounded similarity alignment of an unchanged neural mesh.

Training silhouettes choose a single proper rotation, uniform scale and
translation; held-out views only evaluate. Never deform vertices independently.
"""
from itertools import permutations,product
import math
import numpy as np
from .contracts import require
from .hull_alignment import bounds,ortho_project,validate_views
from .camera_refinement import rotation

def rotations():
    result=[]
    for perm in permutations(range(3)):
        for signs in product((-1,1),repeat=3):
            R=np.eye(3)[:,perm]*np.asarray(signs)
            if np.linalg.det(R)>.5:result.append(R)
    return sorted(result,key=lambda R:float(np.linalg.norm(R-np.eye(3))))

def render_mask(v,f,c,shape):
    import cv2
    x,y,d=ortho_project(v,c,shape)
    # Fixed-point pixel centers, triangle union, not even-odd contour fill.
    uv=np.rint((np.column_stack([x,y])-.5)*16).astype(np.int32)
    out=np.zeros(shape,np.uint8)
    for tri in uv[f]:cv2.fillConvexPoly(out,tri,1,lineType=cv2.LINE_8,shift=4)
    return out.astype(bool)

def resized(views,max_side):
    from PIL import Image
    out={}
    for k,(m,c) in views.items():
        h,w=m.shape;s=max_side/max(h,w);size=(max(1,round(w*s)),max(1,round(h*s)))
        out[k]=(np.asarray(Image.fromarray(m.astype(np.uint8)*255).resize(size,Image.Resampling.BOX))>=128,c)
    return out

def iou(a,b):
    return float((a&b).sum()/max(1,(a|b).sum()))

def fit_similarity(v,f,views,train,heldout):
    require(len(train)>=2 and bool(heldout) and set(train).isdisjoint(heldout),"Independent training and holdout required")
    require(set(train+heldout)<=set(views),"Unknown camera")
    gauge=validate_views({k:views[k] for k in train+heldout})
    require(v.ndim==2 and v.shape[1]==3 and np.isfinite(v).all(),"Invalid mesh")
    require(f.ndim==2 and f.shape[1]==3 and f.min()>=0 and f.max()<len(v),"Invalid faces")
    tviews={k:views[k] for k in train}
    lo,hi=bounds(tviews);center=(lo+hi)/2;extent=hi-lo
    # Center original mesh; fit uniform scale only, never per-axis stretching.
    vc=(v.min(0)+v.max(0))/2;v0=v-vc
    small=resized(tviews,80)
    def initial(R):
        q=v0@R.T;ext=np.ptp(q,axis=0);s=float(ext@extent/(ext@ext))
        return R,s,center.copy()
    def points(p):
        R,s,t=p;return v0@R.T*s+t
    def scores(p,vs):
        q=points(p);return {k:iou(render_mask(q,f,c,m.shape),m) for k,(m,c) in vs.items()}
    def loss(p):
        a=scores(p,small);return float(np.mean(list(a.values())))
    baseline=initial(np.eye(3))
    candidates=[]
    for R in rotations():
        p=initial(R);candidates.append((loss(p),p))
    best=max(candidates,key=lambda x:x[0]);p=best[1];score=best[0]
    # Bounded local search; fit exclusively on training views.
    for ang,sc,shift in ((.20,.12,.08),(.09,.05,.035),(.035,.02,.014)):
        for repeat in range(2):
            for axis in range(7):
                R,s,t=p;options=[]
                for sign in (-1,1):
                    if axis<3:
                        rv=np.zeros(3);rv[axis]=ang*sign;option=(rotation(rv)@R,s,t.copy())
                    elif axis==3:option=(R,s*math.exp(sc*sign),t.copy())
                    else:
                        tt=t.copy();tt[axis-4]+=shift*extent.max()*sign;option=(R,s,tt)
                    if not (.5*baseline[1]<=option[1]<=2*baseline[1]) or np.linalg.norm(option[2]-center)>.35*extent.max():continue
                    options.append((loss(option),option))
                if options:
                    candidate=max(options,key=lambda x:x[0])
                    if candidate[0]>score+1e-6:score,p=candidate
    evalviews=resized({k:views[k] for k in train+heldout},192)
    before=scores(baseline,evalviews);after=scores(p,evalviews)
    mean=lambda a,keys:float(np.mean([a[k] for k in keys]))
    old=mean(before,heldout);new=mean(after,heldout)
    accept=new>old+.005 and min(after[k]-before[k] for k in heldout)>=-.03 and mean(after,train)>mean(before,train)+.005
    R,s,t=p
    transformed=points(p)
    return transformed,points(baseline),{"schema":1,"status":"similarity_hypothesis_improved" if accept else "holdout_rejected_or_no_improvement","gauge":gauge,"train_views":train,"holdout_views":heldout,"before":before,"after":after,"train_mean_before":mean(before,train),"train_mean_after":mean(after,train),"heldout_mean_before":old,"heldout_mean_after":new,"rotation":R.tolist(),"scale":s,"translation":t.tolist(),"source_center":vc.tolist(),"proper_rotation":float(np.linalg.det(R)),"geometry_deformed":False,"production_fusion":False,"artistic_approval":False,"limitations":["Only one similarity transform; cannot recover missing thickness, anatomy or concavities.","Opposite orthographic silhouettes do not independently measure hidden surface depth.","Estimated cameras remain nonmetric."]}
