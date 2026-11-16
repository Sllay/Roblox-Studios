"""Outer-hull visibility diagnostic for already matched image points.

The visual hull is a conservative silhouette intersection, not the true
surface. Proximity to its first ray hit is therefore a diagnostic, not a
semantic or physical correspondence certificate. Concave true surfaces
can be well behind the outer hull and must not be discarded in production.
"""
from __future__ import annotations
import numpy as np
from .contracts import require
from .cameras import basis

def shell_gap(record,views,intervals,step):
    require(np.isfinite(step) and step>0,"Invalid voxel step")
    point=np.asarray(record["point"],np.float64)
    require(point.shape==(3,) and np.isfinite(point).all(),"Invalid point")
    gaps={}
    for name,xy in record["observations"].items():
        mask,cam=views[name];ray=intervals[name]
        require(cam.projection=="orthographic" and cam.status in ("known","estimated"),"Camera required")
        x,y=map(float,xy)
        if not (np.isfinite([x,y]).all() and 0<=x<mask.shape[1] and 0<=y<mask.shape[0]):return None
        i,j=int(y),int(x)
        near=float(ray["near"][i,j]);far=float(ray["far"][i,j])
        if not mask[i,j] or not (np.isfinite([near,far]).all() and 0<near<=far) or int(ray["runs"][i,j])!=1:return None
        r,u,b,t=map(np.asarray,basis(cam));depth=-float((point-t)@b)
        if depth<=0:return None
        # Absolute deviation: do not accept points in front of the shell
        # merely because their signed distance is negative.
        gaps[name]=abs(depth-near)/step
    if len(gaps)<2:return None
    return {"per_view_gap_voxels":gaps,"max_gap_voxels":float(max(gaps.values()))}

def filter_shell(records,views,intervals,step,tolerance):
    require(np.isfinite(tolerance) and tolerance>0,"Invalid tolerance")
    accepted=[]
    for rec in records:
        gap=shell_gap(rec,views,intervals,step)
        if gap is not None and gap["max_gap_voxels"]<=tolerance:
            accepted.append({**rec,"outer_shell_diagnostic":gap})
    return accepted
