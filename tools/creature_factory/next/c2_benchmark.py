"""C2-A/B independent benchmark against C1 fixture buffers and rabbit source pixels."""
from pathlib import Path
import json,shutil,sys,math
import numpy as np
from PIL import Image,ImageDraw
from dataclasses import asdict
from .contracts import AssetManifest,CameraCalibration,legacy_rabbit,require
from .dag import build,read_state,validate_job
from .cameras import project,unproject
from .audit import write_json,validate_output,sha256,ROOT,REGISTRY,verify_sources

def outputs(root,state,name):
    return {Path(p).name:root/p for p in state["stages"][name]["outputs"]}
def run(fixtures,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preserve=verify_sources(ROOT,json.loads(REGISTRY.read_text()))
    summary={};tiles=[]
    for p in sorted(Path(fixtures).iterdir()):
        if not (p/"manifest.json").is_file():continue
        m=AssetManifest.read(p/"manifest.json");job=out/p.name
        s=build(p/"manifest.json",job)
        require(s["stages"]["calibration_ready"]["state"]=="succeeded",str(s["stages"]))
        require(s["stages"]["evidence_ready"]["state"]=="blocked","Future evidence must remain blocked")
        seg=outputs(job,s,"segmentation_ready");cal=outputs(job,s,"calibration_ready")
        c=json.loads(cal["calibration.json"].read_text());views={}
        for v in m.views:
            mask=np.asarray(Image.open(seg[v.id+"-mask.png"]))>0
            gt=np.load(p/f"mask-{v.id}.npy");d=np.load(p/f"depth-{v.id}.npy")
            require(mask.shape==gt.shape,"Mask dimensions")
            iou=float((mask&gt).sum()/(mask|gt).sum())
            core=np.asarray(Image.open(seg[v.id+"-core-mask.png"]))>0
            core_iou=float((core&gt).sum()/(core|gt).sum())
            require(not (core&~mask).any(),"Core must be subset of coverage")
            camera=CameraCalibration(**c["views"][v.id]["camera"])
            require(camera==v.camera,"Known camera mutated")
            yy,xx=np.where(gt);errors=[];surface=[]
            for y,x in zip(yy[::max(1,len(yy)//256)],xx[::max(1,len(xx)//256)]):
                z=float(d[y,x]);world=unproject(camera,(x+.5,y+.5),z,(gt.shape[1],gt.shape[0]))
                q=project(camera,world,(gt.shape[1],gt.shape[0]))
                errors.append(max(abs(q[0]-x-.5),abs(q[1]-y-.5),abs(q[2]-z)))
                if v.id=="top" and p.name in ("flat","wavy","convex","concave"):
                    a,b,h=world
                    expected=0 if p.name=="flat" else .22*math.sin(2*math.pi*a/1.5)*math.cos(math.pi*b/2) if p.name=="wavy" else (1 if p.name=="convex" else -1)*.35*(1-(a/1.5)**2)*(1-b*b)
                    surface.append(abs(h-expected))
            require(max(errors)<1e-4,"Camera projection roundtrip")
            if surface:require(max(surface)<.004,"Independent analytic surface reprojection")
            require(core_iou>.90, f"Center-coverage mask accuracy {p.name}/{v.id}: {core_iou}")
            views[v.id]={"coverage_mask_iou":iou,"core_mask_iou":core_iou,"reprojection_max":max(errors),"analytic_surface_max":max(surface) if surface else None,"samples":len(errors)}
        before={k:v["attempt"] for k,v in s["stages"].items() if v["state"]=="succeeded"}
        resumed=build(p/"manifest.json",job,resume=True)
        require(before=={k:v["attempt"] for k,v in resumed["stages"].items() if v["state"]=="succeeded"},"Cache not reused")
        require(validate_job(job)["status"]=="valid_incomplete","Invalid fixture job")
        summary[p.name]=views
        tiles.append((p.name,seg["segmentation-review.png"]))
    require(len(summary)==6,"Expected six C1 fixtures")
    # Original files remain immutable; only copies in a separate staging directory.
    src=ROOT/"asset-library/references/rabbit-v1";r=legacy_rabbit(src);staging=out/"rabbit-input";staging.mkdir()
    for name in {v.source for v in r.views}:shutil.copyfile(src/name,staging/name)
    write_json(staging/"manifest.json",asdict(r));job=out/"rabbit"
    s=build(staging/"manifest.json",job);require(s["stages"]["calibration_ready"]["state"]=="succeeded",str(s["stages"]))
    seg=outputs(job,s,"segmentation_ready");cal=outputs(job,s,"calibration_ready")
    rabbit=json.loads(cal["calibration.json"].read_text());rseg=json.loads(seg["segmentation.json"].read_text())
    require(all(x["camera"]["status"]!="known" for x in rabbit["views"].values()),"Fabricated calibration")
    shutil.copyfile(seg["segmentation-review.png"],out/"rabbit-segmentation.png")
    # Compact real evidence sheet: top view mask for each fixture, plus source.
    panel=Image.new("RGB",(768,6*155),(245,245,245));draw=ImageDraw.Draw(panel)
    for i,(name,_) in enumerate(tiles):
        p=Path(fixtures)/name;j=out/name;state=read_state(j);q=outputs(j,state,"segmentation_ready")
        for col,path in enumerate((p/"color-top.png",q["top-core-mask.png"],p/"depth-top.png",p/"normal-top.png")):
            im=Image.open(path).convert("RGBA");bg=Image.new("RGBA",im.size,(225,230,235,255));bg.alpha_composite(im);panel.paste(bg.convert("RGB").resize((144,144)),(col*192,i*155+11))
        draw.text((4,i*155),name,fill=(20,20,20))
    panel.save(out/"fixture-evidence.png")
    report={"schema":1,"status":"c2ab_validated","fixture_views":sum(len(v) for v in summary.values()),"fixtures":summary,"rabbit":{"segmentation":rseg,"calibration":rabbit},"preservation":preserve,
        "limitations":["Alpha segmentation only, not semantic part masks. Low-alpha coverage preserves possible thin features; majority coverage is compared with center-sampled rays.","Estimated camera gauge not metric.","Depth estimation and normals from real images remain unavailable; fixture maps are C1 ground truth only."],"artistic_approval":False,"publication_allowed":False}
    write_json(out/"report.json",report);print(json.dumps({"status":report["status"],"views":report["fixture_views"],"rabbit_calibration":s["stages"]["calibration_ready"]["metrics"]},indent=2))
if __name__=="__main__":run(Path(sys.argv[1]),Path(sys.argv[2]))
