"""Versioned semantic landmark observations, distinct from appearance matches.

Identity is supplied by a reviewed annotation or a declared detector. A
geometrically consistent track cannot promote an unreviewed semantic guess.
"""
from __future__ import annotations
from dataclasses import dataclass,asdict
import re,math
import numpy as np
from .contracts import require,VIEWS,finite
from .cameras import basis
from .hull_alignment import triangulate_observations,ortho_project

@dataclass(frozen=True)
class LandmarkDefinition:
    id:str
    part:str
    side:str="midline"
    kind:str="surface"
    description:str=""
    def __post_init__(self):
        require(re.fullmatch(r"[a-z][a-z0-9_]{0,79}",self.id),"Invalid landmark identity")
        require(bool(self.part) and self.side in ("left","right","midline","none"),"Landmark part/side")
        require(self.kind in ("surface","joint","region"),"Landmark kind")

@dataclass(frozen=True)
class LandmarkObservation:
    landmark_id:str
    view_id:str
    visibility:str
    source:str
    confidence:float
    xy:list|None=None
    reference_sha256:str=""
    def __post_init__(self):
        finite(asdict(self))
        require(self.view_id in VIEWS,"Unknown landmark view")
        require(self.visibility in ("visible","occluded","unknown","out_of_frame"),"Visibility")
        require(self.source in ("reviewed","unreviewed_annotation","detector_candidate","fixture_truth","fixture_marker_detector"),"Observation source")
        require(isinstance(self.confidence,(int,float)) and 0<=self.confidence<=1,"Confidence must be 0..1")
        require(re.fullmatch("[0-9a-f]{64}",self.reference_sha256),"Reference SHA required")
        if self.visibility=="visible":
            require(isinstance(self.xy,list) and len(self.xy)==2 and all(isinstance(x,(int,float)) and math.isfinite(x) for x in self.xy),"Visible observation needs pixel coordinates")
        else:require(self.xy is None,"Invisible/unknown observations cannot claim pixels")

@dataclass(frozen=True)
class LandmarkBundle:
    asset_id:str
    definitions:list[LandmarkDefinition]
    observations:list[LandmarkObservation]
    schema:int=1
    def __post_init__(self):
        require(self.schema==1 and bool(self.asset_id),"Bundle identity/schema")
        ids=[d.id for d in self.definitions];require(len(ids)==len(set(ids)) and bool(ids),"Duplicate/missing landmark identity")
        seen=set()
        for o in self.observations:
            key=(o.landmark_id,o.view_id)
            require(o.landmark_id in ids and key not in seen,"Unknown or duplicate landmark/view")
            seen.add(key)
    @classmethod
    def from_dict(cls,raw):
        return cls(raw["asset_id"],[LandmarkDefinition(**x) for x in raw["definitions"]],[LandmarkObservation(**x) for x in raw["observations"]],raw.get("schema",1))

def validate_observations(bundle,views,hashes):
    """Bind each annotation to exact cropped reference bytes, not just view name."""
    for o in bundle.observations:
        require(o.view_id in views and hashes.get(o.view_id)==o.reference_sha256,"Observation reference changed or unavailable")
        if o.visibility!="visible":continue
        m,c=views[o.view_id];x,y=o.xy;h,w=m.shape
        require(0<=x<w and 0<=y<h,"Landmark outside crop")
        # A joint can be internal; a visible surface point must be foreground.
        if next(d for d in bundle.definitions if d.id==o.landmark_id).kind=="surface":
            require(bool(m[int(y),int(x)]),"Visible surface landmark outside foreground")
    return True

def solve_landmarks(bundle,views,hashes,max_holdout_px=3.0,min_confidence=.65):
    """Fit from two nonparallel views; reserve all remaining visible views.
    Do not choose the fit pair by holdout error. Output is a hypothesis.
    """
    validate_observations(bundle,views,hashes)
    results={}
    for d in bundle.definitions:
        obs=[o for o in bundle.observations if o.landmark_id==d.id]
        usable=[o for o in obs if o.visibility=="visible" and o.confidence>=min_confidence and views[o.view_id][1].status!="unknown" and views[o.view_id][1].projection=="orthographic"]
        report={"kind":d.kind,"side":d.side,"visible":len(usable),"unobserved":len(obs)-len(usable),"production_fusion":False,"metric_candidate":False}
        if d.kind!="surface":
            results[d.id]={**report,"status":"not_surface_anchor"};continue
        if len(usable)<3:
            results[d.id]={**report,"status":"insufficient_independent_views"};continue
        gauges={views[o.view_id][1].status for o in usable}
        if len(gauges)!=1:
            results[d.id]={**report,"status":"mixed_camera_gauge"};continue
        # Select pair by camera separation and declared confidence only.
        pairs=[]
        for i,a in enumerate(usable):
            for b in usable[i+1:]:
                ba=np.asarray(basis(views[a.view_id][1])[2]);bb=np.asarray(basis(views[b.view_id][1])[2])
                sep=float(np.linalg.norm(np.cross(ba,bb)))
                if sep>.25:pairs.append((sep*min(a.confidence,b.confidence),a.view_id,b.view_id,a,b))
        if not pairs:
            results[d.id]={**report,"status":"parallel_views"};continue
        _,_,_,a,b=max(pairs,key=lambda v:v[:3]);fit={a.view_id:a.xy,b.view_id:b.xy}
        try:q=triangulate_observations(fit,views,max_holdout_px)
        except ValueError as exc:
            results[d.id]={**report,"status":"fit_rejected","reason":str(exc)};continue
        p=np.asarray(q["point"]);held={}
        for o in usable:
            if o.view_id in fit:continue
            m,c=views[o.view_id];x,y,z=ortho_project(p,c,m.shape)
            held[o.view_id]=float(np.hypot(x-o.xy[0],y-o.xy[1])) if z>0 else 1e9
        ok=bool(held) and max(held.values())<=max_holdout_px
        sources=sorted({o.source for o in usable});reviewed=all(o.source=="reviewed" for o in usable)
        results[d.id]={**report,"status":"heldout_consistent" if ok else "heldout_rejected","point":q["point"],"gauge":q["gauge"],"fit_views":list(fit),"fit_reprojection":q["reprojection_pixels"],"heldout_reprojection":held,"sources":sources,"reviewed_identity":reviewed,"metric_candidate":bool(ok and gauges=={"known"} and reviewed)}
    return results
