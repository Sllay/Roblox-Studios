"""C2-B: explicit camera geometry and conservative orthographic hypotheses."""
from __future__ import annotations
from dataclasses import asdict
import math,statistics,json
from .contracts import CameraCalibration,require
from .audit import write_json

AXES={
 "front":((1,0,0),(0,0,1),(0,-1,0)),
 "back":((-1,0,0),(0,0,1),(0,1,0)),
 "left":((0,-1,0),(0,0,1),(-1,0,0)),
 "right":((0,1,0),(0,0,1),(1,0,0)),
 "top":((1,0,0),(0,1,0),(0,0,1)),
 "bottom":((-1,0,0),(0,1,0),(0,0,-1)),
}
DIM={"front":("x","z"),"back":("x","z"),"left":("y","z"),"right":("y","z"),"top":("x","y"),"bottom":("x","y")}
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def add(a,b):return tuple(x+y for x,y in zip(a,b))
def mul(a,s):return tuple(x*s for x in a)
def basis(c):
    require(c.status!="unknown","Unknown camera")
    m=c.world_from_camera
    return tuple(tuple(m[i][j] for i in range(3)) for j in range(4))
def project(c,point,size):
    """Pixel coordinates use centers at i+.5; depth is camera-forward -Z."""
    w,h=size;r,u,b,t=basis(c);q=tuple(x-y for x,y in zip(point,t))
    x,y,d=dot(q,r),dot(q,u),-dot(q,b)
    require(d>0,"Point behind camera")
    if c.projection=="orthographic":
        ppu=max(w,h)/c.ortho_scale;return (w/2+x*ppu,h/2-y*ppu,d)
    k=c.intrinsics;return (k[0][0]*x/d+k[0][1]*(-y/d)+k[0][2],k[1][1]*(-y/d)+k[1][2],d)
def unproject(c,pixel,depth,size):
    w,h=size;r,u,b,t=basis(c);x,y=pixel
    require(math.isfinite(depth) and depth>0,"Invalid depth")
    if c.projection=="orthographic":
        s=c.ortho_scale/max(w,h);xx=(x-w/2)*s;yy=(h/2-y)*s
    else:
        k=c.intrinsics;yn=(y-k[1][2])/k[1][1];xx=(x-k[0][2]-k[0][1]*yn)/k[0][0]*depth;yy=-yn*depth
    return add(add(add(t,mul(r,xx)),mul(u,yy)),mul(b,-depth))
def estimate_orthographic(reports,allowed):
    """Weak shape-box alignment, not metric camera recovery.
    Fit shared extent ratios using upright views; do not estimate 3/4 pose.
    Border-clipped panels excluded. Absolute scale and distance are gauges.
    """
    ratios={"x":[],"y":[]}
    for name in ("front","back","left","right"):
        if name not in reports or name not in allowed:continue
        q=reports[name]
        if q["touches_edge"]:continue
        a,b,c,d=q["bbox"];ratios[DIM[name][0]].append((c-a)/(d-b))
    if not all(ratios.values()):return {},{"status":"insufficient_unclipped_upright_views"}
    dims={"x":statistics.median(ratios["x"]),"y":statistics.median(ratios["y"]),"z":1.0}
    estimates={};distance=3*max(dims.values())
    for name,q in reports.items():
        if name not in AXES or name not in allowed or q["touches_edge"]:continue
        w,h=q["size"];a,b,c,d=q["bbox"];dx,dy=DIM[name]
        sx=(c-a)/dims[dx];sy=(d-b)/dims[dy];ppu=math.sqrt(sx*sy)
        residual=abs(math.log(sx/sy))
        # Do not silently accept incompatible aspect ratios.
        if residual>math.log(1.25):continue
        right,up,back=AXES[name];offset_x=((a+c)/2-w/2)/ppu;offset_y=(h/2-(b+d)/2)/ppu
        t=add(add(mul(right,-offset_x),mul(up,-offset_y)),mul(back,distance))
        mat=[[right[i],up[i],back[i],t[i]] for i in range(3)]+[[0,0,0,1]]
        cam=CameraCalibration("estimated","orthographic",mat,max(w,h)/ppu,confidence=max(.05,.45*(1-residual)))
        estimates[name]={"camera":asdict(cam),"aspect_log_residual":residual,"method":"canonical orthographic bbox alignment","metric_depth_allowed":False,"confidence_semantics":"heuristic; not calibrated probability"}
    return estimates,{"status":"hypothesis_only","normalized_extents":dims,"height_gauge":1.0,"distance_gauge":distance,"upright_ratios":ratios}
def calibrate(m,source,out,cfg,inputs):
    raw=json.loads(inputs["segmentation_ready"]["segmentation.json"].read_text())
    reports=raw["views"];allowed={v.id for v in m.views if v.camera.status=="unknown"}
    estimates,hypothesis=estimate_orthographic(reports,allowed) if cfg.get("estimate_unknown",True) else ({},{"status":"disabled"})
    result={}
    for v in m.views:
        if v.camera.status!="unknown":
            result[v.id]={"camera":asdict(v.camera),"method":"manifest supplied","metric_depth_allowed":v.camera.status=="known","confidence_semantics":"manifest declared; known is not inferred"}
        elif v.id in estimates:result[v.id]=estimates[v.id]
        else:result[v.id]={"camera":asdict(v.camera),"method":"unavailable","metric_depth_allowed":False,"reason":"insufficient evidence, clipped panel or uncalibrated three-quarter pose"}
    # Compare opposing-view extent ratios (diagnostic only, no forced symmetry).
    checks=[]
    for a,b in (("front","back"),("left","right"),("top","bottom")):
        if a not in reports or b not in reports:continue
        def ratio(n):
            x,y,X,Y=reports[n]["bbox"];return (X-x)/(Y-y)
        residual=abs(math.log(ratio(a)/ratio(b)))
        checks.append({"views":[a,b],"aspect_log_residual":residual,"suspect":residual>math.log(1.25)})
    report={"schema":1,"status":"camera_evidence_ready","views":result,"hypothesis":hypothesis,"opposing_view_diagnostics":checks,
      "limitations":["Estimated orthographic cameras use silhouette extent hypotheses and arbitrary scale/distance; not metric calibration.","No pose recovery for unknown three-quarter cameras; no fabricated depth.","Anatomical correspondence and learned depth remain C2-C/D."]}
    write_json(out/"calibration.json",report)
    return {"known":sum(x["camera"]["status"]=="known" for x in result.values()),"estimated":sum(x["camera"]["status"]=="estimated" for x in result.values()),"unknown":sum(x["camera"]["status"]=="unknown" for x in result.values())}
