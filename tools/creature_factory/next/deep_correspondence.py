"""Experimental dense DINOv2 patch descriptors and geometric matching.
No semantic labels, metric calibration, or production fusion are inferred.
"""
from __future__ import annotations
import numpy as np
from .contracts import require
from .cameras import basis
from .hull_alignment import ortho_project,triangulate_observations

MODEL="facebook/dinov2-small"
REVISION="150c8e7"
WEIGHT_SHA256="ae1e99fcefd534ed978cdeb8326f08030c96e28b7a81ffcbc98a857c84d14be1"

def normalize(x):
    return x/np.maximum(np.linalg.norm(x,axis=-1,keepdims=True),1e-12)

class DinoFeatures:
    def __init__(self,root):
        import torch
        from transformers import AutoModel
        from pathlib import Path
        from .audit import sha256
        p=Path(root);require(sha256(p/"model.safetensors")==WEIGHT_SHA256,"Weight digest mismatch")
        torch.set_num_threads(2);torch.set_num_interop_threads(1)
        self.torch=torch
        self.model=AutoModel.from_pretrained(p,local_files_only=True,trust_remote_code=False,use_safetensors=True).eval().to("cpu")
        self.provenance={"model":MODEL,"revision":REVISION,"weights_sha256":WEIGHT_SHA256,"license":"Apache-2.0","device":"cpu","torch":torch.__version__,"config_sha256":sha256(p/"config.json")}
    def extract(self,im,mask,background=192):
        from PIL import Image
        torch=self.torch;h,w=mask.shape;im=im.convert("RGBA").resize((w,h),Image.Resampling.LANCZOS)
        # 28x28 tokens; no center crop; preserve aspect ratio and coordinates.
        size=392;scale=size/max(h,w);nw,nh=max(1,round(w*scale)),max(1,round(h*scale));left,top=(size-nw)//2,(size-nh)//2
        canvas=Image.new("RGB",(size,size),(background,)*3);rgba=im.resize((nw,nh),Image.Resampling.LANCZOS);canvas.paste(rgba,(left,top),rgba.getchannel("A"))
        a=np.asarray(canvas,dtype=np.float32)/255
        a=(a-np.array([.485,.456,.406],np.float32))/np.array([.229,.224,.225],np.float32)
        tensor=torch.from_numpy(a.transpose(2,0,1).copy())[None]
        with torch.inference_mode():
            out=self.model(pixel_values=tensor,output_hidden_states=True)
        # Mix last and middle layer: appearance and semantic context. No trained
        # keypoint head. Bilinear sampling preserves patch-center coordinates.
        feat=torch.cat([torch.nn.functional.normalize(out.hidden_states[8][:,1:],dim=-1),torch.nn.functional.normalize(out.last_hidden_state[:,1:],dim=-1)],dim=-1)
        require(feat.shape[1]==28*28,"Unexpected patch grid")
        feat=feat.reshape(1,28,28,-1).permute(0,3,1,2)
        yy,xx=np.mgrid[2:h-2:4,2:w-2:4];ok=mask[yy,xx]&mask[yy-1,xx]&mask[yy+1,xx]&mask[yy,xx-1]&mask[yy,xx+1]
        x=xx[ok]+.5;y=yy[ok]+.5;points=np.column_stack([x,y])
        gx=2*(left+x*nw/w)/size-1;gy=2*(top+y*nh/h)/size-1
        grid=torch.from_numpy(np.column_stack([gx,gy]).astype(np.float32))[None,None]
        f=torch.nn.functional.grid_sample(feat,grid,mode="bilinear",padding_mode="border",align_corners=False)[0,:,0].T.numpy()
        return points,normalize(f)

def epipolar_mask(pa,pb,va,vb,tolerance_px=2.0):
    """Common image-plane axis of nonparallel orthographic cameras."""
    ma,ca=va;mb,cb=vb
    ra,ua,ba,ta=map(np.asarray,basis(ca));rb,ub,bb,tb=map(np.asarray,basis(cb))
    cross=np.cross(ba,bb);n=np.linalg.norm(cross)
    require(n>.15,"Parallel views are not triangulable")
    axis=cross/n
    def coords(p,m,c,r,u,t):
        h,w=m.shape;s=c.ortho_scale/max(w,h)
        return t@axis+(p[:,0]-w/2)*s*(r@axis)+(h/2-p[:,1])*s*(u@axis)
    a=coords(pa,ma,ca,ra,ua,ta);b=coords(pb,mb,cb,rb,ub,tb)
    tol=tolerance_px*(ca.ortho_scale/max(ma.shape)+cb.ortho_scale/max(mb.shape))/2
    return abs(a[:,None]-b[None,:])<=tol

def mutual_matches(pa,fa,pb,fb,allowed=None,min_similarity=.65,margin=.025):
    if min(len(pa),len(pb))<2:return []
    require(fa.shape[0]==len(pa) and fb.shape[0]==len(pb) and fa.shape[1]==fb.shape[1],"Descriptor shapes")
    require(np.isfinite(fa).all() and np.isfinite(fb).all(),"Nonfinite features")
    sim=normalize(fa)@normalize(fb).T
    if allowed is not None:sim=np.where(allowed,sim,-np.inf)
    # Margin against the best spatially distinct alternative (not an
    # adjacent sample of the same patch).
    best_b=np.argmax(sim,axis=1);best_a=np.argmax(sim,axis=0);result=[]
    for i,j in enumerate(best_b):
        if best_a[j]!=i or sim[i,j]<min_similarity:continue
        alt_b=np.linalg.norm(pb-pb[j],axis=1)>=8
        alt_a=np.linalg.norm(pa-pa[i],axis=1)>=8
        other_b=np.max(sim[i,alt_b],initial=-np.inf);other_a=np.max(sim[alt_a,j],initial=-np.inf)
        # If no alternative exists, evidence cannot establish distinctiveness.
        if not np.isfinite(other_b) or not np.isfinite(other_a):continue
        gap=min(sim[i,j]-other_b,sim[i,j]-other_a)
        if gap>=margin:result.append((int(i),int(j),float(sim[i,j]),float(gap)))
    return result

def geometric_matches(pa,fa,pb,fb,a,b,views,hull,guided=True):
    allowed=epipolar_mask(pa,pb,views[a],views[b]) if guided else None
    matches=mutual_matches(pa,fa,pb,fb,allowed);records=[]
    for i,j,score,gap in matches:
        obs={a:pa[i].tolist(),b:pb[j].tolist()}
        try:q=triangulate_observations(obs,views,2.0)
        except ValueError:continue
        p=np.asarray(q["point"]);idx=np.floor((p-hull["origin"])/hull["step"]).astype(int)
        if not (((idx>=0)&(idx<np.asarray(hull["grid"].shape))).all() and hull["grid"][tuple(idx)]):continue
        records.append({"indices":[i,j],"observations":obs,"similarity":score,"margin":gap,**q})
    return records

def evaluate_matches(records,a,b,views,truth):
    """Scoring only: both observed pixels must represent the same visible 3D
    surface. Reprojection/hull consistency alone is not a correctness label."""
    from .geometry_evidence import world_points
    points={}
    for n in (a,b):
        d,m=truth[n];points[n]=world_points(d,m,views[n][1])
    errors=[];correct=0;invalid=0
    tol=2*max(views[n][1].ortho_scale/max(views[n][0].shape) for n in (a,b))
    for r in records:
        xyz=[]
        for n in (a,b):
            x,y=r["observations"][n];ix,iy=int(x),int(y);d,m=truth[n]
            if not (0<=ix<m.shape[1] and 0<=iy<m.shape[0] and m[iy,ix]):break
            xyz.append(points[n][iy,ix])
        if len(xyz)!=2:invalid+=1;r["evaluation"]="invalid_truth_pixel";continue
        e=float(np.linalg.norm(xyz[0]-xyz[1]));errors.append(e)
        r["world_distance"]=e;r["evaluation"]="correct" if e<=tol else "incorrect";correct+=e<=tol
    return {"matches":len(records),"correct":int(correct),"invalid_truth":invalid,"precision":float(correct/len(records)) if records else None,"median_world_error":float(np.median(errors)) if errors else None,"tolerance_world":float(tol)}
