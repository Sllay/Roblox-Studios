"""C2-D/E: camera-aware surface normals and occlusion-aware evidence comparison.
Metric operations require known cameras and aligned depth in a common gauge.
No fusion, learned anatomy, or calibrated probability is claimed.
"""
from __future__ import annotations
import numpy as np
from .contracts import require
from .cameras import basis

def validate_depth(depth,mask,camera):
    require(camera.status=="known","Metric evidence requires known camera")
    require(depth.ndim==2 and depth.shape==mask.shape and mask.dtype==bool,"Depth/mask shape")
    require(np.isfinite(depth).all() and (depth[mask]>0).all(),"Invalid metric depth")
    require(mask.any(),"Empty mask")

def world_points(depth,mask,camera):
    validate_depth(depth,mask,camera)
    h,w=depth.shape;y,x=np.indices((h,w),dtype=np.float64);x+=.5;y+=.5
    r,u,b,t=map(np.asarray,basis(camera))
    if camera.projection=="orthographic":
        s=camera.ortho_scale/max(w,h);xx=(x-w/2)*s;yy=(h/2-y)*s
    else:
        k=np.asarray(camera.intrinsics);yn=(y-k[1,2])/k[1,1]
        xx=(x-k[0,2]-k[0,1]*yn)/k[0,0]*depth;yy=-yn*depth
    p=t+xx[...,None]*r+yy[...,None]*u-depth[...,None]*b
    p[~mask]=0
    return p

def project_points(points,camera,shape):
    require(camera.status=="known","Metric evidence requires known camera")
    h,w=shape;r,u,b,t=map(np.asarray,basis(camera));q=points-t
    x=q@r;y=q@u;d=-(q@b)
    if camera.projection=="orthographic":
        s=max(w,h)/camera.ortho_scale;px=w/2+x*s;py=h/2-y*s
    else:
        k=np.asarray(camera.intrinsics);safe=np.where(d>0,d,1)
        px=k[0,0]*x/safe-k[0,1]*y/safe+k[0,2];py=k[1,2]-k[1,1]*y/safe
    return px,py,d

def interior(mask):
    q=np.zeros_like(mask)
    q[1:-1,1:-1]=mask[1:-1,1:-1]&mask[:-2,1:-1]&mask[2:,1:-1]&mask[1:-1,:-2]&mask[1:-1,2:]
    return q

def normals_from_depth(depth,mask,camera,max_step):
    """Central tangent cross product, reject silhouette/occlusion discontinuities.
    max_step is a world-unit depth difference, not a smoothing parameter.
    """
    require(np.isfinite(max_step) and max_step>0,"Invalid depth jump tolerance")
    p=world_points(depth,mask,camera);ok=interior(mask)
    d=depth[1:-1,1:-1]
    jump=np.maximum.reduce([abs(d-depth[:-2,1:-1]),abs(d-depth[2:,1:-1]),abs(d-depth[1:-1,:-2]),abs(d-depth[1:-1,2:])])
    ok[1:-1,1:-1]&=jump<=max_step
    dx=p[1:-1,2:]-p[1:-1,:-2];dy=p[2:,1:-1]-p[:-2,1:-1]
    n=np.cross(dy,dx);length=np.linalg.norm(n,axis=-1)
    ok[1:-1,1:-1]&=length>1e-12
    n/=np.maximum(length[...,None],1e-12)
    r,u,b,t=map(np.asarray,basis(camera))
    toward=b if camera.projection=="orthographic" else t-p[1:-1,1:-1]
    flip=(n*toward).sum(-1)<0;n[flip]*=-1
    result=np.zeros((*mask.shape,3),np.float32);result[1:-1,1:-1]=n
    result[~ok]=0
    return result,ok

# 0 untested; 1 agree; 2 occluded; 3 contradiction; 4 uncertain/boundary;
# 5 outside silhouette. No agreement is inferred from absence of conflict.
LABELS={0:"untested",1:"agree",2:"occluded",3:"contradiction",4:"uncertain",5:"outside_silhouette"}
def compare_pair(depth,mask,camera,target_depth,target_mask,target_camera,tolerance,max_step):
    require(np.isfinite(tolerance) and tolerance>0,"Invalid tolerance")
    validate_depth(target_depth,target_mask,target_camera)
    p=world_points(depth,mask,camera);source=interior(mask)
    y,x=np.where(source);px,py,z=project_points(p[y,x],target_camera,target_mask.shape)
    h,w=target_mask.shape
    ix=np.floor(px).astype(int);iy=np.floor(py).astype(int)
    inbounds=(z>0)&(ix>=1)&(ix<w-1)&(iy>=1)&(iy<h-1)
    labels=np.zeros(mask.shape,np.uint8);labels[y,x]=4
    y,x,ix,iy,z=[a[inbounds] for a in (y,x,ix,iy,z)]
    # Require full 3x3 foreground neighborhood for depth comparisons,
    # and full 3x3 background for a definite silhouette violation.
    neighbors=np.stack([target_mask[iy+j,ix+i] for j in (-1,0,1) for i in (-1,0,1)])
    all_fg=neighbors.all(0);all_bg=~neighbors.any(0)
    labels[y[all_bg],x[all_bg]]=5
    vals=np.stack([target_depth[iy+j,ix+i] for j in (-1,0,1) for i in (-1,0,1)])
    stable=all_fg&(np.ptp(vals,axis=0)<=2*max_step)
    # Conservative min/max interval accommodates pixel sampling and sloping surfaces.
    lo=vals.min(0);hi=vals.max(0)
    # An occluded point is behind *all* samples in the neighborhood.
    occ=stable&(z>hi+tolerance);conf=stable&(z<lo-tolerance)
    agree=stable&~occ&~conf&(abs(z-target_depth[iy,ix])<=tolerance)
    labels[y[occ],x[occ]]=2;labels[y[conf],x[conf]]=3;labels[y[agree],x[agree]]=1
    return labels

def assess_multiview(views,tolerance,max_step):
    """Independent directed visibility tests; retain disagreements, never average.
    views maps ID -> (depth, mask, known camera). Confidence is a heuristic
    support score, not probability or permission to modify a mesh.
    """
    require(len(views)>=2,"Need at least two calibrated views")
    results={}
    for name,(depth,mask,cam) in views.items():
        support=np.zeros(mask.shape,np.uint16);conflict=support.copy();occluded=support.copy();pairs={}
        for target,(td,tm,tc) in views.items():
            if target==name:continue
            l=compare_pair(depth,mask,cam,td,tm,tc,tolerance,max_step)
            support+=l==1;conflict+=(l==3)|(l==5);occluded+=l==2
            pairs[target]=l
        score=np.zeros(mask.shape,np.float32)
        good=(support>0)&(conflict==0)&mask
        score[good]=support[good]/(len(views)-1)
        results[name]={"support":support,"conflicts":conflict,"occluded":occluded,"score":score,"pairs":pairs}
    return results

def relative_stability(primary,alternate,mask):
    """Background perturbation agreement in standardized relative-depth space.
    High agreement is necessary but not sufficient for geometric correctness.
    No metric alignment or camera inference is performed.
    """
    require(primary.shape==alternate.shape==mask.shape and mask.dtype==bool,"Relative shape")
    require(mask.any() and np.isfinite(primary).all() and np.isfinite(alternate).all(),"Invalid relative score")
    a=primary[mask].astype(np.float64);b=alternate[mask].astype(np.float64)
    out=np.zeros(mask.shape,np.float32)
    if min(a.std(),b.std())<1e-8:return out
    z=(a-a.mean())/a.std()-(b-b.mean())/b.std()
    out[mask]=np.exp(-.5*z*z).astype(np.float32)
    return out

def fit_anchors(scores,depths):
    """Positive affine inverse-depth alignment from explicit metric anchors.
    Anchors must come from measured or synthetic ground truth, not alpha bounds.
    """
    s=np.asarray(scores,dtype=np.float64);d=np.asarray(depths,dtype=np.float64)
    require(s.ndim==1 and s.shape==d.shape and len(s)>=8,"At least eight aligned anchors required")
    require(np.isfinite(s).all() and np.isfinite(d).all() and (d>0).all(),"Invalid anchors")
    require(np.ptp(s)>1e-8 and np.ptp(1/d)>1e-8,"Insufficient anchor depth span")
    # Deterministic robust trimming with positive orientation retained.
    active=np.ones(len(s),bool)
    for _ in range(3):
        a,b=np.linalg.lstsq(np.column_stack([s[active],np.ones(active.sum())]),1/d[active],rcond=None)[0]
        residual=1/d-(a*s+b);med=np.median(residual[active]);mad=np.median(abs(residual[active]-med))
        candidate=abs(residual-med)<=max(3.5*1.4826*mad,1e-8)
        if candidate.sum()<8 or np.array_equal(candidate,active):break
        active=candidate
    require(a>0 and np.all(a*s+b>0),"Inverse-depth orientation invalid")
    return float(a),float(b),int(active.sum())

def align_scores(scores,mask,scale,offset):
    require(np.isfinite(scale) and np.isfinite(offset) and scale>0,"Invalid inverse-depth alignment")
    inv=scale*scores.astype(np.float64)+offset
    require(np.isfinite(inv[mask]).all() and (inv[mask]>0).all(),"Invalid aligned depth")
    depth=np.zeros(scores.shape,np.float32);depth[mask]=(1/inv[mask]).astype(np.float32)
    return depth
