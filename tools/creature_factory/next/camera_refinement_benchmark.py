"""C2-I.1 controlled camera correction and actual rabbit readiness diagnosis."""
from pathlib import Path
import json,sys
import numpy as np
from PIL import Image,ImageDraw
from .audit import write_json,validate_output,sha256,ROOT,REGISTRY,verify_sources
from .contracts import AssetManifest,CameraCalibration,require,path_inside
from .landmarks import LandmarkBundle,LandmarkObservation
from .camera_refinement import *

def run(fixture,ab,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preservation=verify_sources(ROOT,json.loads(REGISTRY.read_text()))
    m=AssetManifest.read(fixture/"manifest.json")
    views={v.id:(np.load(fixture/(v.id+"-geometry.npz"))["mask"],v.camera) for v in m.views}
    hashes={v.id:sha256(fixture/(v.id+"-painted.png")) for v in m.views}
    bundle=LandmarkBundle.from_dict(json.loads((fixture/"landmarks.json").read_text()))
    target="top";mask,true=views[target]
    initial=adjusted_camera(true,mask.shape,[.095,.055,-.045,.035,.025,-.025])
    # Exact annotated observations are a separate control from marker centroids.
    truth=json.loads((fixture/"truth.json").read_text())
    exact=LandmarkBundle(bundle.asset_id,bundle.definitions,[LandmarkObservation(o["landmark_id"],o["view_id"],"visible" if o["visible"] else "unknown","fixture_truth",1 if o["visible"] else 0,o["xy"],hashes[o["view_id"]]) for o in truth["observations"]])
    reports={};images=[]
    for name,b in (("exact",exact),("detected",bundle)):
        fitted,r=refine_bundle(b,target,views,hashes,initial)
        require(fitted is not None,f"{name}: {r}")
        require(r["holdout_after"]["rmse"]<r["holdout_before"]["rmse"]*.5,"Heldout improvement")
        require(r["holdout_after"]["rmse"]<3,"Heldout absolute error")
        # Score final pose against the true camera only after the solve.
        R=np.asarray(fitted.world_from_camera)[:3,:3];T=np.asarray(true.world_from_camera)[:3,:3]
        r["rotation_error_deg"]=float(np.degrees(np.arccos(np.clip((np.trace(T.T@R)-1)/2,-1,1))))
        r["relative_scale_error"]=abs(fitted.ortho_scale/true.ortho_scale-1)
        require(r["rotation_error_deg"]<5 and r["relative_scale_error"]<.06,"Camera recovery accuracy")
        reports[name]=r
        # Wrong identity in one held-out target observation must be rejected.
        bad={k:dict(v) for k,v in r["independent_anchors"].items()}
        held=r["holdout_ids"];bad[held[0]]["xy"]=[bad[held[0]]["xy"][0]+30,bad[held[0]]["xy"][1]-25]
        _,probe=refine(initial,mask.shape,bad);require(probe["status"]=="holdout_rejected_or_no_improvement","Wrong holdout not rejected")
        r["wrong_identity_probe"]=probe["status"]
        src=Image.open(fixture/"top-natural.png").convert("RGBA")
        panel=Image.new("RGB",(768,282),(235,237,239));draw=ImageDraw.Draw(panel)
        for j,(label,c) in enumerate((("Perturbed camera",initial),("Refined camera",fitted),("Known true camera",true))):
            bg=Image.new("RGBA",src.size,(225,229,233,255));bg.alpha_composite(src);panel.paste(bg.convert("RGB"),(256*j,26));draw.text((256*j+5,5),name+" / "+label,fill=(20,20,20))
            for k,a in r["independent_anchors"].items():
                x,y=a["xy"];px,py,d=ortho_project(np.asarray(a["point"]),c,mask.shape);ox=256*j
                color=(30,150,75) if k in r["holdout_ids"] else (60,100,210)
                draw.line((ox+x,26+y,ox+px,26+py),fill=(230,65,45),width=2);draw.ellipse((ox+x-2,26+y-2,ox+x+2,26+y+2),fill=color)
        images.append(panel)
    panel=Image.new("RGB",(768,564),(235,237,239))
    for i,im in enumerate(images):panel.paste(im,(0,i*282))
    panel.save(out/"camera-refinement-review.png")
    # Real concept: preserve all original camera hypotheses if independent
    # evidence is insufficient. No fabricated extra points or camera poses.
    job=ab/"rabbit";state=json.loads((job/"job.json").read_text())
    def files(stage):
        f={}
        for p,h in state["stages"][stage]["outputs"].items():
            q=path_inside(job,p);require(sha256(q)==h,"Stale evidence");f[q.name]=q
        return f
    refs=files("reference_ready");seg=files("segmentation_ready");cal=json.loads(files("calibration_ready")["calibration.json"].read_text())
    rv={n:(np.asarray(Image.open(seg[n+"-core-mask.png"]))>0,CameraCalibration(**r["camera"])) for n,r in cal["views"].items()}
    rh={n:sha256(refs[n+".png"]) for n in rv}
    rb=LandmarkBundle.from_dict(json.loads((ROOT/"docs/benchmarks/creature-factory-next/rabbit-landmark-proposals.json").read_text()))
    rabbit={}
    for n in rv:
        c,r=refine_bundle(rb,n,rv,rh);require(c is None,"Unreviewed sparse rabbit unexpectedly refined");rabbit[n]=r
    report={"schema":1,"status":"controlled_camera_refinement_validated","fixture":reports,"rabbit":rabbit,"preservation":preservation,"limitations":["One-camera bounded refinement in fixed reference gauge, not full joint bundle adjustment.","Fixture marker observations and exact projected annotations are controlled tests, not natural semantic detection.","Rabbit has insufficient independent surface landmarks; no camera or mesh changed.","Estimated cameras remain nonmetric; no production fusion."]}
    write_json(out/"report.json",report)
    print(json.dumps({"fixture":{k:{a:v[a] for a in ("anchors","holdout_before","holdout_after","rotation_error_deg","relative_scale_error")} for k,v in reports.items()},"rabbit":{k:{"status":v["status"],"anchors":v.get("anchors",0)} for k,v in rabbit.items()}}),flush=True)
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
