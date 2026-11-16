"""Run a real CPU depth candidate benchmark. No production adoption."""
from pathlib import Path
import sys,json,math,time,resource
import numpy as np
from PIL import Image,ImageDraw
from .depth_candidate import DepthCandidate,fit_inverse_depth,background_sensitivity
from .contracts import legacy_rabbit,require
from .audit import ROOT,REGISTRY,verify_sources,validate_output,write_json
def vis(pred,mask):
    rgb=np.zeros((*mask.shape,3),np.uint8);lo,hi=np.percentile(pred[mask],[2,98])
    gray=np.rint(np.clip((pred-lo)/max(hi-lo,1e-8),0,1)*255).astype(np.uint8);rgb[mask]=gray[mask,None]
    return Image.fromarray(rgb)
def run(fixtures,model,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preserve=verify_sources(ROOT,json.loads(REGISTRY.read_text()));runner=DepthCandidate(model);rows=[];metrics={};start=time.monotonic()
    cases=[]
    for name in ("flat","wavy","convex","concave","asymmetric","articulation"):
        p=Path(fixtures)/name
        for view in ("top","three-quarter"):
            cases.append((name,view,Image.open(p/f"color-{view}.png").convert("RGBA"),np.load(p/f"mask-{view}.npy"),np.load(p/f"depth-{view}.npy")))
    src=ROOT/"asset-library/references/rabbit-v1";m=legacy_rabbit(src)
    for v in m.views:
        x,y,w,h=v.crop
        with Image.open(src/v.source) as im:im=im.crop((x,y,x+w,y+h)).convert("RGBA")
        cases.append(("rabbit",v.id,im,np.asarray(im.getchannel("A"))>=128,None))
    for name,view,im,mask,truth in cases:
        key=name+"/"+view;p=out/name/view;p.mkdir(parents=True)
        require(mask.any(),"Empty evidence")
        a,meta=runner.predict(im,192);b,meta2=runner.predict(im,64)
        np.save(p/"relative-inverse-depth.npy",a);np.save(p/"alternate-background.npy",b)
        np.save(p/"mask.npy",mask);vis(a,mask).save(p/"relative-depth.png");vis(b,mask).save(p/"alternate-depth.png")
        report={"inference":meta,"alternate_inference":meta2,"background_sensitivity_zscore_rmse":background_sensitivity(a,b,mask),
            "foreground_range":float(np.ptp(a[mask])),"metric_depth":False,"alignment":fit_inverse_depth(a,truth,mask) if truth is not None else {"status":"no_metric_ground_truth"}}
        write_json(p/"report.json",report);metrics[key]=report
        # Review: original RGB, primary/alternate prediction, actual fixture depth where available.
        bg=Image.new("RGBA",im.size,(192,192,192,255));bg.alpha_composite(im)
        panels=[bg.convert("RGB"),vis(a,mask),vis(b,mask),vis(1/np.maximum(truth,1e-8),mask) if truth is not None else Image.new("RGB",im.size,(50,50,50))]
        rows.append((key,panels));print(key,report["alignment"],flush=True)
    panel=Image.new("RGB",(800,150*len(rows)+26),(240,240,240));draw=ImageDraw.Draw(panel)
    for i,txt in enumerate(("Source RGB","Predicted relative","Background changed","GT inverse (fixtures)")):draw.text((i*200+5,6),txt,fill=(15,15,15))
    for i,(name,imgs) in enumerate(rows):
        y=26+i*150;draw.text((5,y+2),name,fill=(15,15,15))
        for j,im in enumerate(imgs):
            im=im.copy();im.thumbnail((190,125));panel.paste(im,(j*200+(200-im.width)//2,y+22+(125-im.height)//2))
    panel.save(out/"depth-review.png")
    # No fake pass: report candidate quality separately from successful execution.
    eligible=[(k,v["alignment"]) for k,v in metrics.items() if v["alignment"]["status"]=="oracle_affine_inverse_depth"]
    failed=[k for k,v in metrics.items() if not k.startswith("rabbit/") and v["alignment"]["status"] not in ("constant_ground_truth","oracle_affine_inverse_depth")]
    poor=[k for k,v in eligible if v["improvement_over_constant"]<.25 or v["correlation"] is None or v["correlation"]<.6]
    report={"schema":1,"status":"measured_candidate_not_adopted","provenance":runner.provenance,"cases":metrics,
        "quality":{"failed_alignment":failed,"below_provisional_gate":poor,"gate":"oracle held-out correlation >=.6 and >=25% MAE improvement over constant; no production approval even if passed"},
        "wall_seconds":time.monotonic()-start,"peak_rss_mib":resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1024,
        "preservation":preserve,"limitations":["Per-view affine fit uses synthetic metric ground truth; impossible to reuse for uncalibrated concepts without anchors.","Background variation is sensitivity, not calibrated confidence.","No fusion, normals or reconstruction; no model adopted."]}
    write_json(out/"report.json",report);print(json.dumps({"status":report["status"],"quality":report["quality"],"wall_seconds":report["wall_seconds"]},indent=2))
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
