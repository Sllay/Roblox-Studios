"""Fit the existing learned surface to independent concept views.

No re-generation, no primitive substitution, no decimation. A smooth,
positive-scale cross-section transform corrects single-view depth and lean.
UVs remain attached to the original vertices. The original checkpoint is
retained, and the strict independent silhouette audit remains unchanged.
"""
import argparse,json,hashlib
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import gaussian_filter1d
from rabbit_organic_reference import panel_data,intervals,HEIGHT

def masks_for(v,f,maps):
    result={}
    for k,a in maps.items():
        u=a["center"]+a["sign"]*v[:,a["axis"]]/a["scale"]
        p=np.column_stack([u,a["bottom"]-v[:,2]/a["scale"]])
        im=Image.new("1",(250,475));draw=ImageDraw.Draw(im)
        for t in f:draw.polygon([tuple(q) for q in p[t]],fill=1)
        result[k]=np.asarray(im,dtype=bool)
    return result

def scores(v,f,refs,maps):
    pred=masks_for(v,f,maps)
    return {k:float((m&refs[k]).sum()/max(1,(m|refs[k]).sum())) for k,m in pred.items()}

def rows(v,f,zs):
    # Exact triangle-edge/plane intersections, with no image viewport clipping.
    edges=np.unique(np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1),axis=0)
    a=v[edges[:,0]];b=v[edges[:,1]]
    lo=np.minimum(a[:,2],b[:,2]);hi=np.maximum(a[:,2],b[:,2])
    out=[]
    for z in zs:
        hit=(lo<=z)&(hi>z)&(hi-lo>1e-9)
        aa=a[hit];bb=b[hit]
        if not len(aa):out.append([np.nan]*4);continue
        t=(z-aa[:,2])/(bb[:,2]-aa[:,2])
        q=aa[:,:2]+t[:,None]*(bb[:,:2]-aa[:,:2])
        out.append([q[:,0].min(),q[:,0].max(),q[:,1].min(),q[:,1].max()])
    return np.asarray(out)

def target_rows(refs,maps,zs):
    out=[]
    for z in zs:
        line=[]
        for keys in (("front","back"),("right","left")):
            r=[]
            for k in keys:
                it=intervals(refs,maps,k,z)
                if it:r.append([min(t[0] for t in it),max(t[1] for t in it)])
            line.extend(np.mean(r,axis=0) if r else [np.nan,np.nan])
        out.append(line)
    return np.asarray(out)

def smooth_valid(values,valid,sigma):
    x=np.arange(len(values))
    assert valid.sum()>len(values)*.7
    return gaussian_filter1d(np.interp(x,x[valid],values[valid]),sigma,mode="nearest")

def fit_params(source,target,sigma):
    result=[]
    for axis in (0,1):
        a,b=source[:,2*axis:2*axis+2].T
        c,d=target[:,2*axis:2*axis+2].T
        sw=b-a;tw=d-c
        valid=np.isfinite(a+b+c+d)&(sw>.06)&(tw>.06)
        ratio=np.clip(tw/np.maximum(sw,1e-6),.4,2.0)
        center=(a+b)/2;dst=(c+d)/2
        logs=smooth_valid(np.log(ratio),valid,sigma)
        shift=smooth_valid(dst-center,valid,sigma)
        center=smooth_valid(center,valid,sigma)
        result.append((center,logs,shift))
    return result

def deform(v,zs,params,strength):
    out=v.copy()
    for axis,(center,logs,shift) in enumerate(params):
        c=np.interp(v[:,2],zs,center)
        sc=np.exp(strength*np.interp(v[:,2],zs,logs))
        off=strength*np.interp(v[:,2],zs,shift)
        out[:,axis]=c+(v[:,axis]-c)*sc+off
    return out

def rotate(v,deg):
    t=np.deg2rad(deg);r=np.array([[np.cos(t),-np.sin(t),0],[np.sin(t),np.cos(t),0],[0,0,1]])
    return v@r.T

def quality(s):
    return .35*s["front"]+.25*s["right"]+.25*s["left"]+.15*s["back"]

def geometry_check(v,f):
    p=v[f];a=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0])
    assert np.all(np.isfinite(v)) and np.all(np.linalg.norm(a,axis=1)>1e-11),"Degenerate fitted faces"
    e=np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1)
    _,counts=np.unique(e,axis=0,return_counts=True)
    assert np.all(counts==2),"Non-manifold fit"
    return True

def main(out):
    p=out/"neural-mesh.npz";d=np.load(p)
    arrays={k:d[k] for k in d.files};d.close()
    v=arrays["vertices"].astype(np.float64);f=arrays["faces"]
    master=arrays["master_vertices"].astype(np.float64)
    refs,_,maps,_=panel_data()
    before=scores(v,f,refs,maps)
    zs=np.linspace(.025,HEIGHT-.025,145)
    target=target_rows(refs,maps,zs)
    best=None; trials=[]
    # Evaluate the actual projection after each calibrated deformation.
    # Yaw range is relative to the already aligned neural checkpoint.
    for yaw in (-20,-10,0,10,20,30,40):
        rv=rotate(v,yaw);source=rows(rv,f,zs)
        for sigma in (2.0,4.0):
            params=fit_params(source,target,sigma)
            for strength in (.7,1.0):
                q=deform(rv,zs,params,strength)
                s=scores(q,f,refs,maps)
                metric=quality(s)
                trials.append({"yawOffset":yaw,"sigma":sigma,"strength":strength,"scores":s})
                if best is None or metric>best[0]:
                    best=(metric,yaw,sigma,strength,params,q,s)
        print("calibration yaw",yaw,"best",best[0],flush=True)
    _,yaw,sigma,strength,params,q,after=best
    assert quality(after)>quality(before)+.03,"Calibration did not improve independent views"
    geometry_check(q,f)
    qm=deform(rotate(master,yaw),zs,params,strength)
    geometry_check(qm,arrays["master_faces"])
    # Preserve original artifact and UV correspondences. No texture projection or re-bake.
    np.savez_compressed(out/"neural-mesh-unfitted.npz",**arrays)
    arrays["vertices"]=q.astype(np.float32);arrays["master_vertices"]=qm.astype(np.float32)
    np.savez_compressed(p,**arrays)
    np.savez_compressed(out/"runtime-mesh.npz",vertices=arrays["vertices"],faces=f)
    report=json.loads((out/"neural-report.json").read_text())
    report["calibrationFit"]={"method":"smooth positive-scale cross-section deformation",
        "before":before,"after":after,"yawOffset":yaw,"smoothingSigma":sigma,"strength":strength,
        "maxVertexDisplacement":float(np.max(np.linalg.norm(q-v,axis=1))),
        "unchangedFaceCount":int(len(f)),"topologyPreserved":True,"uvPreserved":True,
        "trials":trials}
    report["limitations"].append("Multiview silhouette fitting does not independently resolve facial detail or hidden concavities.")
    (out/"neural-report.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"before":before,"after":after,"yaw":yaw,"sigma":sigma,"strength":strength}),flush=True)
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("out",type=Path);a=p.parse_args();main(a.out)
