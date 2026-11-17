"""C2-D/E validation on certified C1/C2 artifacts. No new neural inference."""
from pathlib import Path
import json,sys
import numpy as np
from PIL import Image,ImageDraw
from .contracts import AssetManifest,require
from .geometry_evidence import *
from .audit import write_json,validate_output,ROOT,REGISTRY,verify_sources

def color_normals(n,ok):
    rgb=np.zeros(n.shape,np.uint8);rgb[ok]=np.rint((n[ok]+1)*127.5).clip(0,255).astype(np.uint8);return Image.fromarray(rgb)
def color_labels(l):
    pal=np.array([[30,30,30],[73,183,126],[76,133,207],[229,72,75],[145,145,145],[237,154,46]],np.uint8)
    return Image.fromarray(pal[l])
def gray_score(score):
    return Image.fromarray(np.rint(score.clip(0,1)*255).astype(np.uint8)).convert("RGB")
def report_result(r,mask):
    return {"supported_pixels":int(((r["support"]>0)&mask).sum()),"conflicting_pixels":int(((r["conflicts"]>0)&mask).sum()),"occluded_pixels":int(((r["occluded"]>0)&mask).sum()),"positive_score_pixels":int((r["score"]>0).sum()),"foreground_pixels":int(mask.sum())}
def run(fixtures,depth_root,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preserve=verify_sources(ROOT,json.loads(REGISTRY.read_text()))
    rows=[];metrics={};neural={};tolerance=.075;max_step=.16
    for p in sorted(Path(fixtures).iterdir()):
        if not (p/"manifest.json").is_file():continue
        m=AssetManifest.read(p/"manifest.json");views={};norms={}
        for v in m.views:
            d=np.load(p/f"depth-{v.id}.npy");mask=np.load(p/f"mask-{v.id}.npy");truth=np.load(p/f"normal-{v.id}.npy")
            views[v.id]=(d,mask,v.camera)
            n,ok=normals_from_depth(d,mask,v.camera,max_step)
            a=np.degrees(np.arccos(np.clip(np.sum(n[ok]*truth[ok],axis=1),-1,1)))
            norms[v.id]={"valid_pixels":int(ok.sum()),"foreground_pixels":int(mask.sum()),"mean_angle":float(a.mean()) if len(a) else None,"p95_angle":float(np.percentile(a,95)) if len(a) else None}
            q=out/p.name/v.id;q.mkdir(parents=True)
            np.save(q/"derived-normals.npy",n);np.save(q/"normal-valid.npy",ok)
            color_normals(n,ok).save(q/"normals.png")
        gt=assess_multiview(views,tolerance,max_step)
        # Deliberately corrupt one surface by moving its top depth toward camera.
        d,mask,cam=views["top"];bad=d.copy();bad[mask]-=.35
        corrupted={**views,"top":(bad,mask,cam)}
        fail=assess_multiview(corrupted,tolerance,max_step)
        clean=report_result(gt["top"],mask);dirty=report_result(fail["top"],mask)
        metrics[p.name]={"normals":norms,"clean_top":clean,"corrupted_top":dirty,"corruption_world_units":.35}
        q=out/p.name/"top"
        for tag,r in (("clean",gt["top"]),("corrupted",fail["top"])):
            np.save(q/f"{tag}-support.npy",r["support"]);np.save(q/f"{tag}-conflicts.npy",r["conflicts"]);np.save(q/f"{tag}-score.npy",r["score"])
            gray_score(r["score"]).save(q/f"{tag}-score.png")
            color_labels(r["pairs"]["three-quarter"]).save(q/f"{tag}-vs-three-quarter.png")
        if p.name in ("flat","wavy","convex","concave"):
            require(norms["top"]["mean_angle"]<8,"Top analytic normals inaccurate")
        # Neural alignment uses sparse synthetic metric anchors only. Never
        # infer metric scales for the rabbit, and never feed this to a mesh.
        for name in ("top","three-quarter"):
            q=Path(depth_root)/p.name/name;pred=np.load(q/"relative-inverse-depth.npy");alt=np.load(q/"alternate-background.npy")
            td,tm,tc=views[name];stable=relative_stability(pred,alt,tm)
            yy,xx=np.indices(tm.shape);anchor=tm&(xx%8==3)&(yy%8==3)
            result={"anchor_count":int(anchor.sum()),"mean_background_stability":float(stable[tm].mean()),"metric_scope":"synthetic anchors only"}
            try:
                a,b,n=fit_anchors(pred[anchor],td[anchor]);aligned=align_scores(pred,tm,a,b)
                held=tm&~anchor;err=abs(aligned[held]-td[held]);base=abs(np.median(td[anchor])-td[held])
                # Cross-check against independent exact other views (diagnostic oracle).
                other={k:v for k,v in views.items() if k!=name}
                chk=assess_multiview({name:(aligned,tm,tc),**other},tolerance,max_step)[name]
                result.update(status="synthetic_anchor_aligned",heldout_mae=float(err.mean()),heldout_constant_mae=float(base.mean()),alignment=[a,b],retained_anchors=n,agreement=report_result(chk,tm))
                np.save(out/p.name/name/"candidate-aligned.npy",aligned);np.save(out/p.name/name/"candidate-conflicts.npy",chk["conflicts"])
            except ValueError as exc:result.update(status="rejected_alignment",reason=str(exc))
            neural[p.name+"/"+name]=result
        rows.append((p.name,[color_normals(np.load(p/"normal-top.npy"),mask),Image.open(out/p.name/"top"/"normals.png"),gray_score(gt["top"]["score"]),color_labels(fail["top"]["pairs"]["three-quarter"])]))
    require(len(metrics)==6,"Six fixtures required")
    # Quantitative test of conflict detector on known smooth surfaces.
    for name in ("flat","wavy","convex","concave"):
        c=metrics[name]["clean_top"];f=metrics[name]["corrupted_top"]
        require(c["conflicting_pixels"]/c["foreground_pixels"]<.12,f"Clean false conflicts: {name} {c}")
        require(f["conflicting_pixels"]>c["conflicting_pixels"]+.10*c["foreground_pixels"],f"Corruption not detected: {name} {f}")
    # Rabbit: only relative background stability, no fabricated metric alignment.
    rabbit={};rabbit_rows=[]
    for p in sorted((Path(depth_root)/"rabbit").iterdir()):
        if not p.is_dir():continue
        a=np.load(p/"relative-inverse-depth.npy");b=np.load(p/"alternate-background.npy");mask=np.load(p/"mask.npy")
        s=relative_stability(a,b,mask);q=out/"rabbit"/p.name;q.mkdir(parents=True)
        np.save(q/"relative-stability.npy",s);gray_score(s).save(q/"relative-stability.png")
        rabbit[p.name]={"mean_stability":float(s[mask].mean()),"low_stability_fraction":float((s[mask]<.5).mean()),"metric_alignment":"unavailable","fusion_allowed":False}
        rabbit_rows.append((p.name,[Image.open(p/"relative-depth.png"),Image.open(p/"alternate-depth.png"),gray_score(s)]))
    def panel(rows,labels,path):
        w=200*len(labels);im=Image.new("RGB",(w,28+170*len(rows)),(240,240,240));draw=ImageDraw.Draw(im)
        for i,t in enumerate(labels):draw.text((i*200+4,6),t,fill=(20,20,20))
        for i,(name,images) in enumerate(rows):
            y=28+i*170;draw.text((4,y),name,fill=(20,20,20))
            for j,img in enumerate(images):
                img=img.convert("RGB");img.thumbnail((190,145));im.paste(img,(j*200+(200-img.width)//2,y+18+(145-img.height)//2))
        im.save(path)
    panel(rows,["GT world normals","Derived normals","Clean support","Corrupted vs 3/4"],out/"fixture-review.png")
    panel(rabbit_rows,["Relative prediction","Alternate background","Relative stability"],out/"rabbit-review.png")
    report={"schema":1,"status":"validated_geometry_diagnostics","tolerance":tolerance,"max_depth_step":max_step,"fixtures":metrics,"neural_anchor_diagnostics":neural,"rabbit":rabbit,"preservation":preserve,"labels":LABELS,"limitations":["Known-camera exact fixture tests only; sparse synthetic anchors are oracle evaluation.","Relative stability is a heuristic, not geometric confidence.","No estimated-camera fusion, semantic landmarks or production reconstruction; evidence_ready remains blocked."]}
    write_json(out/"report.json",report);print(json.dumps({"status":report["status"],"fixture_top":{k:{"normal_mean":v["normals"]["top"]["mean_angle"],"clean":v["clean_top"],"corrupted":v["corrupted_top"]} for k,v in metrics.items()},"rabbit":rabbit},indent=2))
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
