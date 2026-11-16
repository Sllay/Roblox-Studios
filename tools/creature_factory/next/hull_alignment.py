"""C2 experimental orthographic visual hull and constrained depth alignment.
A hull is an outer-volume hypothesis, never measured depth or a final mesh.
Estimated cameras remain explicitly in a normalized, nonmetric gauge.
"""
from __future__ import annotations
from itertools import combinations,product
import numpy as np
from .contracts import require
from .cameras import basis
from .geometry_evidence import interior

def ortho_project(points,camera,shape):
    require(camera.status in ("known","estimated") and camera.projection=="orthographic","Orthographic calibrated/hypothesis camera required")
    h,w=shape;r,u,b,t=map(np.asarray,basis(camera));q=points-t;s=max(w,h)/camera.ortho_scale
    return w/2+(q@r)*s,h/2-(q@u)*s,-(q@b)

def validate_views(views):
    require(len(views)>=2,"At least two orthographic views")
    states={c.status for m,c in views.values()}
    require(states in ({"known"},{"estimated"}),"Mixed or unknown camera gauges")
    for m,c in views.values():
        require(m.ndim==2 and m.dtype==bool and m.any() and c.projection=="orthographic","Invalid view")
    return "known_camera_outer_hypothesis" if states=={"known"} else "estimated_camera_normalized_hypothesis"

def bounds(views):
    """Intersect silhouette bounding-box halfspaces, not guessed object size."""
    A=[];B=[]
    for mask,c in views.values():
        h,w=mask.shape;y,x=np.where(mask);r,u,b,t=map(np.asarray,basis(c));s=c.ortho_scale/max(w,h)
        xmin=(x.min()-w/2)*s;xmax=(x.max()+1-w/2)*s
        ymin=(h/2-y.max()-1)*s;ymax=(h/2-y.min())*s
        A.extend([r,-r,u,-u]);B.extend([xmax+r@t,-xmin-r@t,ymax+u@t,-ymin-u@t])
    A=np.asarray(A);B=np.asarray(B)
    require(np.linalg.matrix_rank(A)==3,"Unbounded parallel cameras")
    pts=[]
    for ids in combinations(range(len(A)),3):
        a=A[list(ids)]
        if abs(np.linalg.det(a))<1e-8:continue
        p=np.linalg.solve(a,B[list(ids)])
        if (A@p<=B+1e-7).all():pts.append(p)
    require(bool(pts),"Incompatible view bounds")
    pts=np.asarray(pts);lo=pts.min(0);hi=pts.max(0)
    require((hi-lo>1e-8).all(),"Degenerate hull bounds")
    return lo,hi

def dilate(mask,radius=1):
    from PIL import Image,ImageFilter
    if radius==0:return mask.copy()
    return np.asarray(Image.fromarray(mask.astype(np.uint8)*255).filter(ImageFilter.MaxFilter(2*radius+1)))>0

def build_hull(views,resolution=112,padding_pixels=1):
    gauge=validate_views(views)
    require(type(resolution)==int and 32<=resolution<=192,"Hull resolution 32..192")
    require(type(padding_pixels)==int and 0<=padding_pixels<=3,"Padding 0..3")
    padded={n:(dilate(m,padding_pixels),c) for n,(m,c) in views.items()}
    lo,hi=bounds(padded);step=float((hi-lo).max()/resolution)
    lo=lo-step;hi=hi+step
    shape=np.ceil((hi-lo)/step).astype(int)
    require(int(np.prod(shape))<=8_000_000,"Hull voxel budget exceeded")
    grid=np.zeros(tuple(shape),bool);flat=grid.reshape(-1)
    # Chunked carving, strict intersection of relaxed silhouettes.
    for start in range(0,flat.size,65536):
        ids=np.arange(start,min(start+65536,flat.size));xyz=np.column_stack(np.unravel_index(ids,tuple(shape)))
        p=lo+(xyz+.5)*step;keep=np.ones(len(p),bool)
        for m,c in padded.values():
            x,y,d=ortho_project(p,c,m.shape);ix=np.floor(x).astype(int);iy=np.floor(y).astype(int)
            inside=(ix>=0)&(iy>=0)&(ix<m.shape[1])&(iy<m.shape[0])&(d>0)
            hit=np.zeros(len(p),bool);hit[inside]=m[iy[inside],ix[inside]];keep&=hit
        flat[ids]=keep
    require(grid.any(),"Empty hull: inconsistent references or insufficient resolution")
    return {"grid":grid,"origin":lo,"step":step,"gauge":gauge,"padding_pixels":padding_pixels}

def ray_intervals(hull,camera,shape):
    """Sample voxel occupancy at <=half-voxel intervals; retain disjoint spans.
    Near/far are conservative approximate outer intervals, not observed surfaces.
    """
    h,w=shape;grid=hull["grid"];lo=hull["origin"];s=hull["step"]
    hi=lo+np.asarray(grid.shape)*s;r,u,b,t=map(np.asarray,basis(camera))
    corners=np.array(list(product(*zip(lo,hi))));z=-(corners-t)@b
    d0=max(1e-6,float(z.min())-s);d1=float(z.max())+s
    require(d1>d0,"Hull behind camera")
    depths=np.arange(d0,d1+s*.5,s*.5)
    near=np.zeros((h,w),np.float32);far=near.copy();runs=np.zeros((h,w),np.uint16)
    yy,xx=np.indices((h,w));scale=camera.ortho_scale/max(w,h)
    origins=t+(xx.reshape(-1,1)+.5-w/2)*scale*r+(h/2-yy.reshape(-1,1)-.5)*scale*u
    nf=near.ravel();ff=far.ravel();rf=runs.ravel()
    for k in range(0,len(origins),512):
        p=origins[k:k+512,None,:]-depths[None,:,None]*b
        ids=np.floor((p-lo)/s).astype(int);ok=((ids>=0)&(ids<np.asarray(grid.shape))).all(-1)
        hits=np.zeros(ok.shape,bool);q=ids[ok];hits[ok]=grid[q[:,0],q[:,1],q[:,2]]
        anyhit=hits.any(1);first=np.argmax(hits,1);last=len(depths)-1-np.argmax(hits[:,::-1],1)
        sl=slice(k,k+len(hits));nf[sl]=np.where(anyhit,np.maximum(d0,depths[first]-s*.5),0)
        ff[sl]=np.where(anyhit,depths[last]+s*.5,0)
        rf[sl]=hits[:,0].astype(np.uint16)+(hits[:,1:]&~hits[:,:-1]).sum(1)
    return near,far,runs

def align_hypothesis(scores,mask,near,far,runs,step,stable=None):
    """Fit a positive affine inverse-depth map to *intervals*, not ground truth.
    Narrow contiguous rays are weak midpoint anchors. Use spatially disjoint
    blocks for validation; reject negative orientation, weak span and leakage.
    """
    require(scores.shape==mask.shape==near.shape==far.shape==runs.shape,"Alignment shapes")
    require(np.isfinite(scores).all() and np.isfinite(near).all() and np.isfinite(far).all(),"Nonfinite alignment")
    valid=interior(mask)&(near>0)&(far>=near)&(runs==1)
    if stable is not None:valid&=stable>=.5
    coverage=float(valid.sum()/max(mask.sum(),1))
    report={"coverage":coverage,"scope":"hull pseudo-anchors only; nonmetric if cameras estimated","fusion_allowed":False}
    if valid.sum()<32:return None,{**report,"status":"insufficient_contiguous_rays"}
    width=far-near;cut=float(np.percentile(width[valid],35))
    anchors=valid&(width<=max(cut,3*step))
    yy,xx=np.indices(mask.shape);train=anchors&(((xx//8)+(yy//8))%3!=0);test=valid&(((xx//8)+(yy//8))%3==0)
    if min(train.sum(),test.sum())<16:return None,{**report,"status":"insufficient_spatial_anchors"}
    midpoint=(near+far)/2
    x=scores[train].astype(np.float64);y=1/midpoint[train].astype(np.float64)
    if np.ptp(midpoint[train])<3*step or np.std(x)<1e-8:return None,{**report,"status":"insufficient_hull_depth_span"}
    a,b=np.linalg.lstsq(np.column_stack([x,np.ones(len(x))]),y,rcond=None)[0]
    corr=float(np.corrcoef(x,y)[0,1])
    report.update(anchors=int(train.sum()),heldout=int(test.sum()),anchor_correlation=corr,anchor_width_p35=cut)
    if a<=0 or corr<.25:return None,{**report,"status":"unsupported_orientation"}
    inv=a*scores.astype(np.float64)+b
    if (inv[valid]<=0).any():return None,{**report,"status":"nonpositive_inverse_depth"}
    d=np.zeros(scores.shape,np.float32);d[valid]=(1/inv[valid]).astype(np.float32)
    outside=np.maximum(near[test]-d[test],0)+np.maximum(d[test]-far[test],0)
    outside_rate=float((outside>2*step).mean())
    report.update(scale=float(a),offset=float(b),heldout_interval_violation_fraction=outside_rate,heldout_interval_mae=float(outside.mean()))
    if outside_rate>.10:return None,{**report,"status":"heldout_interval_rejected"}
    # Do not clip into hull: that hides contradiction. Keep only consistent rays.
    ok=valid&(d>=near-2*step)&(d<=far+2*step);d[~ok]=0
    return d,{**report,"status":"hull_aligned_candidate","retained_fraction":float(ok.sum()/mask.sum())}

def triangulate_observations(observations,views,max_reprojection_px=2.0):
    """Explicit named pixel correspondences, not automatic semantic labels.
    Orthographic least squares; require nonparallel views and consistent gauge.
    """
    require(len(observations)>=2,"Need two observations")
    sub={n:views[n] for n in observations};gauge=validate_views(sub);A=[];B=[]
    for name,p in observations.items():
        m,c=sub[name];h,w=m.shape;r,u,b,t=map(np.asarray,basis(c));x,y=p
        require(np.isfinite([x,y]).all() and 0<=x<w and 0<=y<h,"Observation outside image")
        s=c.ortho_scale/max(w,h);A.extend([r,u]);B.extend([(x-w/2)*s+r@t,(h/2-y)*s+u@t])
    A=np.asarray(A);B=np.asarray(B)
    require(np.linalg.matrix_rank(A)==3,"Parallel views cannot triangulate")
    point=np.linalg.lstsq(A,B,rcond=None)[0];err={}
    for name,p in observations.items():
        m,c=sub[name];x,y,d=ortho_project(point,c,m.shape);require(d>0,"Triangulation behind camera")
        err[name]=float(np.hypot(x-p[0],y-p[1]))
    require(max(err.values())<=max_reprojection_px,"Inconsistent correspondence")
    return {"point":point.tolist(),"reprojection_pixels":err,"gauge":gauge}
