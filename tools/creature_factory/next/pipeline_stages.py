"""Opt-in end-to-end experimental review runners, no production promotion."""
from pathlib import Path
import json,shutil
import numpy as np
from PIL import Image
from .audit import write_json,sha256
from .contracts import CameraCalibration,require
from .rigid_alignment import fit_similarity,render_mask,resized,iou
from .hull_alignment import build_hull
from .volumetric_reconstruction import neural_occupancy,prior_candidates,surface_from_grid
from .surface_refinement import refine
from .mesh_optimization import optimize
from .uv_atlas import unwrap
from .functional_gate import evaluate_functional_parts
from .anatomy import Anatomy

def read_views(inputs):
    seg=inputs["segmentation_ready"];cal=json.loads(inputs["calibration_ready"]["calibration.json"].read_text())
    return {k:(np.asarray(Image.open(seg[k+"-core-mask.png"]))>0,CameraCalibration(**r["camera"])) for k,r in cal["views"].items() if r["camera"]["status"]!="unknown" and r["camera"]["projection"]=="orthographic"}
def load_mesh(p):
    with np.load(p,allow_pickle=False) as z:return z["vertices"],z["faces"]
def save_mesh(out,name,v,f):np.savez_compressed(out/(name+".npz"),vertices=v,faces=f)
def align_stage(m,source,out,cfg,inputs):
    views=read_views(inputs);v,f=load_mesh(inputs["candidate_ready"]["master.npz"])
    train=cfg.get("train_views",[k for k in ("front","right","top") if k in views]);held=cfg.get("holdout_views",[k for k in views if k not in train])
    a,b,r=fit_similarity(v,f,views,train,held)
    chosen=a if r["status"]=="similarity_hypothesis_improved" else b
    save_mesh(out,"aligned",chosen,f);write_json(out/"alignment-report.json",r)
    return {"status":r["status"],"heldout_iou":r["heldout_mean_after"]}
def select_volume_hypothesis(reports,grids):
    """C3 evidence gate: silhouette agreement cannot certify anatomy.
    Until measured surface evidence and part preservation gates exist,
    a voxel hull is a diagnostic only. No override or approval by IoU.
    The unchanged neural candidate is not claimed to have correct anatomy.
    """
    require("neural" in reports and bool(grids),"Missing volume candidates")
    diagnostic=max(grids,key=lambda k:reports[k]["objective"])
    return {"selected":"neural","diagnostic_candidate":diagnostic,
            "status":"surface_evidence_required","anatomy_verified":False,
            "reason":"Silhouette-only volume can fill limb gaps and erase anatomy; retain neural prior for experimental review only."}

def volume_stage(m,source,out,cfg,inputs):
    views=read_views(inputs);v,f=load_mesh(inputs["candidate_alignment_ready"]["aligned.npz"])
    r=json.loads(inputs["candidate_alignment_ready"]["alignment-report.json"].read_text());train=r["train_views"];held=r["holdout_views"];vs=resized({k:views[k] for k in train+held},192)
    h=build_hull({k:vs[k] for k in train},cfg.get("resolution",128),1);p=neural_occupancy(v,f,h);grids=prior_candidates(h,p)
    def scores(x,y):
        s={k:iou(render_mask(x,y,c,mask.shape),mask) for k,(mask,c) in vs.items()}
        return {"views":s,"train_mean":float(np.mean([s[k] for k in train])),"holdout_mean":float(np.mean([s[k] for k in held]))}
    reports={"neural":scores(v,f)};meshes={"neural":(v,f)}
    for name,g in grids.items():
        a,b=surface_from_grid({**h,"grid":g});meshes[name]=(a,b);r=scores(a,b)
        r["prior_iou"]=float((g&p).sum()/max(1,(g|p).sum()));r["objective"]=r["train_mean"]-.1*(1-r["prior_iou"]);reports[name]=r
    decision=select_volume_hypothesis(reports,grids)
    selected=decision["selected"];diagnostic=decision["diagnostic_candidate"]
    # Keep the outer-volume candidate for inspection, never substitute it for
    # an organic master just because it matches external contours.
    a,b=meshes[diagnostic];save_mesh(out,"volume-diagnostic",a,b)
    a,b=meshes[selected];save_mesh(out,"volume",a,b)
    raw=m.identity.get("anatomy");required=[p.id for p in Anatomy.read(raw).parts] if raw else []
    functional=evaluate_functional_parts(required,{}, {}) if required else {"status":"blocked_functional_anatomy","reason":"no declared part graph","production_approval":False}
    write_json(out/"volume-report.json",{"schema":1,**decision,"metrics":reports,"functional_gate":functional,"depth_used":False,"production_approval":False})
    return {**decision,"heldout_iou":reports[selected]["holdout_mean"]}
def refine_stage(m,source,out,cfg,inputs):
    v,f=load_mesh(inputs["candidate_volume_ready"]["volume.npz"]);views=read_views(inputs)
    a,b,r=refine(v,f,views);save_mesh(out,"refined",a,b);write_json(out/"refinement-report.json",r)
    return {"status":r["status"],"roughness_before":r["roughness_before_deg"],"roughness_after":r["roughness_after_deg"]}
def optimize_stage(m,source,out,cfg,inputs):
    v,f=load_mesh(inputs["candidate_refinement_ready"]["refined.npz"])
    a,b,r=optimize(v,f,ratios=tuple(cfg.get("ratios",(.85,.65,.5,.35,.25,.15,.08))))
    save_mesh(out,"optimized",a,b);write_json(out/"optimization-report.json",r)
    return {"status":r["status"],"triangles":len(b),"reduction_fraction":r["reduction_fraction"]}
def uv_stage(m,source,out,cfg,inputs):
    v,f=load_mesh(inputs["candidate_optimized_ready"]["optimized.npz"]);r=unwrap(v,f,out,cfg.get("resolution",2048))
    return {"status":r["status"],"charts":r["selected"]["charts"],"triangles":len(f)}
def review_stage(m,source,out,cfg,inputs):
    reports={}
    for name,files in inputs.items():
        for filename,p in files.items():
            if filename.endswith("-report.json") or filename=="candidate.json":
                reports[name+"/"+filename]=json.loads(p.read_text())
    uv=inputs["candidate_uv_ready"]
    for name in ("uv-review.glb","uv-layout.png","checker.png","uv.npz"):shutil.copyfile(uv[name],out/name)
    write_json(out/"review.json",{"schema":1,"status":"experimental_review_package","asset_id":m.asset_id,"files":{name:sha256(out/name) for name in ("uv-review.glb","uv-layout.png","checker.png","uv.npz")},"reports":reports,"rig_status":"blocked_unverified_anatomy" if m.rig_required else "not_requested","artistic_approval":False,"publication_allowed":False,"production_ready":False,"limitations":["Candidate workflow; not a verified final 3D asset.","No automatic semantic part verification or rig. No final painted albedo.","Estimated-camera and silhouette-only hypotheses cannot establish hidden surface fidelity."]})
    return {"status":"experimental_review_package","rig_status":"blocked_unverified_anatomy" if m.rig_required else "not_requested"}
RUNNERS={"candidate_alignment_ready":align_stage,"candidate_volume_ready":volume_stage,"candidate_refinement_ready":refine_stage,"candidate_optimized_ready":optimize_stage,"candidate_uv_ready":uv_stage,"candidate_review_ready":review_stage}
