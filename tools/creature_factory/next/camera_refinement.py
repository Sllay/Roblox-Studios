"""C2-I.1: bounded orthographic camera refinement with landmark holdout.

Refine one camera in an independently fixed reference gauge. Other cameras
and mesh are never moved. Whole landmark identities are held out. This is
not unconstrained bundle adjustment or metric calibration of illustrations.
"""
from __future__ import annotations
from dataclasses import asdict
from itertools import combinations
import hashlib,math
import numpy as np
from .contracts import CameraCalibration,require
from .cameras import basis
from .hull_alignment import ortho_project,triangulate_observations
from .landmarks import validate_observations

def rotation(v):
    a=float(np.linalg.norm(v))
    if a<1e-12:return np.eye(3)
    x,y,z=v/a;K=np.array([[0,-z,y],[z,0,-x],[-y,x,0]])
    return np.eye(3)+math.sin(a)*K+(1-math.cos(a))*(K@K)

def adjusted_camera(cam,shape,params):
    """Parameter order log pixel scale, rotation radians XYZ, shift fractions.
    Optical-axis translation is fixed (unobservable in orthographic images)."""
    require(cam.projection=="orthographic" and cam.status!="unknown","Orthographic initial camera required")
    r,u,b,t=map(np.asarray,basis(cam));R=rotation(np.asarray(params[1:4]))@np.column_stack([r,u,b])
    scale=cam.ortho_scale*math.exp(-float(params[0]));ppu=max(shape)/scale
    # Rotate around the existing target plane center, not distant camera origin.
    pivot=np.zeros(3)
    Rdelta=R@np.column_stack([r,u,b]).T
    t=pivot+Rdelta@(t-pivot)-R[:,0]*params[4]*max(shape)/ppu+R[:,1]*params[5]*max(shape)/ppu
    return CameraCalibration("estimated","orthographic",np.column_stack([R,t]).tolist()+[[0,0,0,1]],scale,confidence=cam.confidence)

def projections(cam,shape,points):
    x,y,d=ortho_project(points,cam,shape)
    require(np.all(d>0),"Point behind camera")
    return np.column_stack([x,y])

def split_ids(ids):
    # Frozen split by identity, not measured error.
    ordered=sorted(ids,key=lambda n:hashlib.sha256(("c2-camera-v1:"+n).encode()).hexdigest())
    n=max(3,len(ordered)//3)
    return ordered[n:],ordered[:n]

def independent_points(bundle,target,views,hashes,min_confidence=.65):
    validate_observations(bundle,views,hashes);result={};rejected={}
    for definition in bundle.definitions:
        if definition.kind!="surface":continue
        obs=[o for o in bundle.observations if o.landmark_id==definition.id and o.visibility=="visible" and o.confidence>=min_confidence]
        t=next((o for o in obs if o.view_id==target),None)
        if t is None:continue
        others=[o for o in obs if o.view_id!=target and views[o.view_id][1].status!="unknown" and views[o.view_id][1].projection=="orthographic"]
        if len(others)<2:
            rejected[definition.id]="insufficient_reference_views";continue
        states={views[o.view_id][1].status for o in others}
        if len(states)!=1:rejected[definition.id]="mixed_reference_gauge";continue
        pairs=[]
        for a,b in combinations(others,2):
            ba=np.asarray(basis(views[a.view_id][1])[2]);bb=np.asarray(basis(views[b.view_id][1])[2])
            sep=float(np.linalg.norm(np.cross(ba,bb)))
            if sep>.35:pairs.append((sep*min(a.confidence,b.confidence),a.view_id,b.view_id,a,b))
        if not pairs:rejected[definition.id]="parallel_reference_views";continue
        _,_,_,a,b=max(pairs,key=lambda x:x[:3])
        try:q=triangulate_observations({a.view_id:a.xy,b.view_id:b.xy},views,3.0)
        except ValueError:rejected[definition.id]="reference_triangulation_failed";continue
        p=np.asarray(q["point"]);errors={}
        for o in others:
            m,c=views[o.view_id];x,y,d=ortho_project(p,c,m.shape)
            errors[o.view_id]=float(np.hypot(x-o.xy[0],y-o.xy[1])) if d>0 else 1e9
        if max(errors.values())>3:
            rejected[definition.id]="reference_views_disagree";continue
        result[definition.id]={"point":p.tolist(),"xy":t.xy,"weight":min(t.confidence,a.confidence,b.confidence),"reference_views":[a.view_id,b.view_id],"reference_residuals":errors,"reference_gauge":next(iter(states)),"source":t.source}
    return result,rejected

def refine(cam,shape,anchors):
    report={"status":"not_attempted","production_fusion":False,"metric_calibration":False,"anchors":len(anchors)}
    if len(anchors)<9:return None,{**report,"status":"insufficient_independent_landmarks","minimum":9}
    if len({a["reference_gauge"] for a in anchors.values()})!=1:return None,{**report,"status":"mixed_reference_gauge"}
    train,test=split_ids(list(anchors));report.update(train_ids=train,holdout_ids=test)
    def arrays(ids):
        return np.array([anchors[n]["point"] for n in ids]),np.array([anchors[n]["xy"] for n in ids]),np.array([anchors[n]["weight"] for n in ids])
    p,y,w=arrays(train);q,z,_=arrays(test);size=max(shape)
    if np.linalg.matrix_rank(p-p.mean(0),tol=1e-5)<3:return None,{**report,"status":"degenerate_3d_support"}
    # Bounds prevent camera fit from hiding concept changes via extreme pose.
    limits=np.array([.22,.18,.18,.18,.12,.12])
    params=np.zeros(6);prior=np.array([.3,.4,.4,.4,.3,.3])
    def residual(x):
        return (projections(adjusted_camera(cam,shape,x),shape,p)-y).ravel()
    def jac(x):
        eps=1e-5
        return np.column_stack([(residual(x+np.eye(6)[i]*eps)-residual(x-np.eye(6)[i]*eps))/(2*eps) for i in range(6)])
    def loss(x):
        e=np.linalg.norm(residual(x).reshape(-1,2),axis=1)
        return float(np.sum(w*np.where(e<=2,.5*e*e,2*(e-1)))+.5*np.sum((prior*x)**2))
    J=jac(params);sing=np.linalg.svd(J,compute_uv=False)
    report["jacobian_condition"]=float(sing[0]/max(sing[-1],1e-12))
    if sing[-1]<1e-5 or report["jacobian_condition"]>1e4:return None,{**report,"status":"ill_conditioned_camera_fit"}
    for it in range(40):
        e=residual(params);J=jac(params);norm=np.linalg.norm(e.reshape(-1,2),axis=1)
        weights=np.repeat(np.sqrt(w*np.minimum(1,2/np.maximum(norm,1e-12))),2)
        A=np.vstack([J*weights[:,None],np.diag(prior),np.eye(6)*.05])
        b=np.r_[-e*weights,-prior*params,np.zeros(6)]
        dx=np.linalg.lstsq(A,b,rcond=None)[0];old=loss(params);changed=False
        for alpha in (1,.5,.25,.125,.0625):
            candidate=np.clip(params+alpha*dx,-limits,limits)
            if loss(candidate)<old-1e-10:params=candidate;changed=True;break
        if not changed or np.linalg.norm(dx)<1e-7:break
    fitted=adjusted_camera(cam,shape,params)
    def metrics(c,points,obs):
        err=np.linalg.norm(projections(c,shape,points)-obs,axis=1)
        return {"rmse":float(np.sqrt(np.mean(err**2))),"max":float(err.max()),"per_point":err.tolist()}
    before=metrics(cam,q,z);after=metrics(fitted,q,z)
    train_before=metrics(cam,p,y);train_after=metrics(fitted,p,y)
    report.update(params=params.tolist(),train_before=train_before,train_after=train_after,holdout_before=before,holdout_after=after,iterations=it+1,candidate_camera=asdict(fitted))
    if np.any(abs(params)>=limits*.995):return None,{**report,"status":"camera_bounds_reached"}
    # Improvement must be visible on untouched identities. Keep the original
    # if it was already consistent; never choose a camera on training loss alone.
    if before["rmse"]<=.25:
        return None,{**report,"status":"original_camera_already_consistent"}
    if after["rmse"]>3 or after["max"]>5 or after["rmse"]>before["rmse"]*.85 or before["rmse"]-after["rmse"]<.25 or train_after["rmse"]>train_before["rmse"]:
        return None,{**report,"status":"holdout_rejected_or_no_improvement"}
    return fitted,{**report,"status":"refined_camera_hypothesis","metric_calibration":False}

def refine_bundle(bundle,target,views,hashes,initial=None):
    m,c=views[target];cam=initial or c
    if cam.status=="unknown" or cam.projection!="orthographic":return None,{"status":"unsupported_initial_camera","production_fusion":False}
    anchors,rejected=independent_points(bundle,target,views,hashes)
    fitted,report=refine(cam,m.shape,anchors)
    return fitted,{**report,"target":target,"independent_anchors":anchors,"rejected_anchors":rejected,"original_camera":asdict(cam)}
