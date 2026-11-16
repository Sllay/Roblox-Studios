"""Benchmark visual-hull constraints without using depth truth for alignment.
Fixture ground truth is read only after inference for scoring.
Rabbit remains an estimated-camera diagnostic, never a metric reconstruction.
"""
from pathlib import Path
import json,sys,itertools
import numpy as np
from PIL import Image,ImageDraw
from .contracts import CameraCalibration,require
from .hull_alignment import *
from .geometry_evidence import relative_stability
from .audit import write_json,validate_output,ROOT,REGISTRY,verify_sources

def resize_mask(m,max_side=192):
    h,w=m.shape;s=min(1,max_side/max(h,w));size=(max(1,round(w*s)),max(1,round(h*s)))
    return np.asarray(Image.fromarray(m.astype(np.uint8)*255).resize(size,Image.Resampling.BOX))>=128
def resize_float(a,shape):
    return np.asarray(Image.fromarray(a.astype(np.float32)).resize((shape[1],shape[0]),Image.Resampling.BILINEAR),dtype=np.float32)
def view_files(root):
    job=json.loads((root/"job.json").read_text())
    def files(stage):return {Path(p).name:root/p for p in job["stages"][stage]["outputs"]}
    seg=files("segmentation_ready");refs=files("reference_ready")
    cal=json.loads(files("calibration_ready")["calibration.json"].read_text())
    return {k:(np.asarray(Image.open(seg[k+"-core-mask.png"]))>0,CameraCalibration(**v["camera"]),refs[k+".png"]) for k,v in cal["views"].items() if v["camera"]["status"]!="unknown" and v["camera"]["projection"]=="orthographic"}

def gray_depth(a,valid,lo,hi):
    z=np.zeros(a.shape,np.uint8);z[valid]=np.rint(np.clip((hi-a[valid])/max(hi-lo,1e-8),0,1)*255).astype(np.uint8)
    return Image.fromarray(z).convert("RGB")
def overlay_mask(mask,hit):
    rgb=np.zeros((*mask.shape,3),np.uint8);rgb[mask]=[170,170,170];rgb[hit&mask]=[68,175,120];rgb[hit&~mask]=[230,153,54];rgb[mask&~hit]=[230,75,75]
    return Image.fromarray(rgb)
def feature_tracks(raw,views,hull):
    """Conservative appearance correspondences. Never label anatomical parts.
    Require mutual ratio-test matches, geometric reprojection, and 3-view cycles.
    """
    import cv2
    sift=cv2.SIFT_create(nfeatures=1000,contrastThreshold=.02);matcher=cv2.BFMatcher(cv2.NORM_L2)
    kp={};des={};scaled={}
    for name,(mask,cam,source) in raw.items():
        m=views[name][0];im=Image.open(source).convert("RGBA");im=im.resize((m.shape[1],m.shape[0]),Image.Resampling.LANCZOS)
        bg=Image.new("RGBA",im.size,(192,192,192,255));bg.alpha_composite(im)
        gray=np.asarray(bg.convert("L"));k,d=sift.detectAndCompute(gray,m.astype(np.uint8)*255);kp[name]=k;des[name]=d
    def matches(a,b):
        if des[a] is None or des[b] is None or min(len(des[a]),len(des[b]))<2:return {}
        def good(x,y):return {p.queryIdx:p.trainIdx for p,q in matcher.knnMatch(des[x],des[y],k=2) if p.distance<.72*q.distance}
        ab=good(a,b);ba=good(b,a);return {i:j for i,j in ab.items() if ba.get(j)==i}
    pairs={};counts={};nodes={}
    for a,b in itertools.combinations(views,2):
        r1,u1,b1,t1=map(np.asarray,basis(views[a][1]));r2,u2,b2,t2=map(np.asarray,basis(views[b][1]))
        if abs(b1@b2)>.95:continue
        accepted={};candidate=matches(a,b)
        for i,j in candidate.items():
            obs={a:kp[a][i].pt,b:kp[b][j].pt}
            try:q=triangulate_observations(obs,views,2)
            except ValueError:continue
            idx=np.floor((np.asarray(q["point"])-hull["origin"])/hull["step"]).astype(int)
            if ((idx>=0)&(idx<np.asarray(hull["grid"].shape))).all() and hull["grid"][tuple(idx)]:
                accepted[i]=j
                nodes.setdefault((a,i),set()).add((b,j));nodes.setdefault((b,j),set()).add((a,i))
        pairs[a,b]=accepted;counts[a+"/"+b]={"mutual":len(candidate),"reprojection_hull_accepted":len(accepted)}
    tracks=[];seen=set()
    for a,edges in nodes.items():
        for b,c in itertools.combinations(edges,2):
            if len({a[0],b[0],c[0]})<3 or c not in nodes.get(b,set()):continue
            key=tuple(sorted([a,b,c]))
            if key in seen:continue
            seen.add(key);obs={n:kp[n][i].pt for n,i in key}
            try:q=triangulate_observations(obs,views,2)
            except ValueError:continue
            tracks.append({"observations":{n:list(p) for n,p in obs.items()},**q})
    return {"keypoints":{k:len(v) for k,v in kp.items()},"pairs":counts,"three_view_tracks":tracks,"semantic_landmarks":False,"scope":"appearance candidates only; not independent anatomical ground truth"}

def consistency(candidates,views,step):
    """Cross-check only where both candidate maps have valid depth.
    Missing prediction is unknown, not an absent surface.
    """
    result={}
    for name,(depth,ok) in candidates.items():
        m,c=views[name];h,w=m.shape;r,u,b,t=map(np.asarray,basis(c));yy,xx=np.where(ok);s=c.ortho_scale/max(w,h)
        pts=t+(xx[:,None]+.5-w/2)*s*r+(h/2-yy[:,None]-.5)*s*u-depth[yy,xx,None]*b
        report={}
        for target,(td,tok) in candidates.items():
            if target==name:continue
            tm,tc=views[target];x,y,z=ortho_project(pts,tc,tm.shape);ix=np.floor(x).astype(int);iy=np.floor(y).astype(int)
            inb=(ix>=0)&(iy>=0)&(ix<tm.shape[1])&(iy<tm.shape[0])&(z>0)
            i=np.flatnonzero(inb);i=i[tok[iy[i],ix[i]]]
            if not len(i):report[target]={"overlap":0};continue
            delta=z[i]-td[iy[i],ix[i]];tol=max(3*step,.02)
            report[target]={"overlap":len(i),"agreement":int((abs(delta)<=tol).sum()),"occluded":int((delta>tol).sum()),"contradiction":int((delta<-tol).sum())}
        result[name]=report
    return result

def run(fixtures,ab,depthroot,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preserve=verify_sources(ROOT,json.loads(REGISTRY.read_text()))
    summaries={};rows=[];rabbit_rows=[];all_tracks=None
    for name in ("flat","wavy","convex","concave","asymmetric","articulation","rabbit"):
        raw=view_files(Path(ab)/name);views={k:(resize_mask(m),c) for k,(m,c,p) in raw.items()}
        q=out/name;q.mkdir();hull=build_hull(views,112,1)
        np.savez_compressed(q/"hull.npz",grid=hull["grid"],origin=hull["origin"],step=hull["step"])
        res={"gauge":hull["gauge"],"shape":list(hull["grid"].shape),"voxel_size":hull["step"],"occupied":int(hull["grid"].sum()),"views":{}}
        candidates={}
        for k,(m,c) in views.items():
            p=q/k;p.mkdir();near,far,runs=ray_intervals(hull,c,m.shape);hit=near>0
            np.savez_compressed(p/"ray-intervals.npz",near=near,far=far,runs=runs,mask=m)
            overlay_mask(m,hit).save(p/"silhouette-check.png")
            valid=m&hit;report={"mask_iou":float((m&hit).sum()/(m|hit).sum()),"ray_coverage":float(valid.sum()/m.sum()),"multi_span_fraction":float((runs[m]>1).mean()),"interval_width_median":float(np.median((far-near)[valid])) if valid.any() else None}
            dp=Path(depthroot)/name/k
            if not (dp/"relative-inverse-depth.npy").exists():
                res["views"][k]=report;continue
            score=resize_float(np.load(dp/"relative-inverse-depth.npy"),m.shape);alt=resize_float(np.load(dp/"alternate-background.npy"),m.shape)
            stable=relative_stability(score,alt,m)
            d,ar=align_hypothesis(score,m,near,far,runs,hull["step"],stable);report["alignment"]=ar
            lo=float(near[valid].min()) if valid.any() else 0;hi=float(far[valid].max()) if valid.any() else 1
            gray_depth(near,hit,lo,hi).save(p/"hull-near.png");gray_depth(far,hit,lo,hi).save(p/"hull-far.png")
            if d is not None:
                ok=d>0;candidates[k]=(d,ok);np.save(p/"aligned-hypothesis.npy",d);gray_depth(d,ok,lo,hi).save(p/"aligned.png")
            if name!="rabbit":
                # Only here access depth truth; never used to fit hull or alignment.
                gt=np.load(Path(fixtures)/name/f"depth-{k}.npy");gm=np.load(Path(fixtures)/name/f"mask-{k}.npy")
                require(gt.shape==m.shape,"Fixture resolution changed")
                use=gm&valid;err=np.maximum(near[use]-gt[use],0)+np.maximum(gt[use]-far[use],0)
                report["ground_truth_evaluation"]={"interval_contains_truth_fraction":float((err<=2*hull["step"]).mean()),"interval_mae":float(err.mean()),"hull_near_mae":float(abs(near[use]-gt[use]).mean())}
                if d is not None:
                    common=use&(d>0);a=abs(d[common]-gt[common]);b=abs(near[common]-gt[common])
                    report["ground_truth_evaluation"].update(aligned_mae=float(a.mean()),same_pixel_hull_near_mae=float(b.mean()),evaluated_pixels=int(common.sum()),improvement_over_hull_near=float(1-a.mean()/max(b.mean(),1e-12)))
                gray_depth(gt,gm,lo,hi).save(p/"ground-truth.png")
            images=[Image.open(p/"silhouette-check.png"),Image.open(p/"hull-near.png"),Image.open(p/"hull-far.png"),Image.open(p/"aligned.png") if d is not None else Image.new("RGB",(m.shape[1],m.shape[0]),(45,45,45))]
            if name!="rabbit":images.append(Image.open(p/"ground-truth.png"))
            (rabbit_rows if name=="rabbit" else rows).append((name+"/"+k,ar["status"],images))
            res["views"][k]=report
        res["cross_view_candidates"]=consistency(candidates,views,hull["step"])
        if name=="rabbit":
            all_tracks=feature_tracks(raw,views,hull);write_json(q/"appearance-tracks.json",all_tracks);res["appearance_tracks"]=all_tracks
        # Known synthetic control: project an explicit point from the hull into
        # three cameras and check the generic triangulation routine.
        else:
            vox=np.argwhere(hull["grid"]);point=hull["origin"]+(vox[len(vox)//2]+.5)*hull["step"]
            obs={k:ortho_project(point,c,m.shape)[:2] for k,(m,c) in views.items() if k in ("front","right","top")}
            tri=triangulate_observations(obs,views);res["correspondence_control_error"]=float(np.linalg.norm(np.asarray(tri["point"])-point))
            require(res["correspondence_control_error"]<1e-6,"Triangulation control")
        summaries[name]=res
        print(name,json.dumps({"gauge":res["gauge"],"views":{k:{"iou":v["mask_iou"],"alignment":v.get("alignment",{}).get("status"),"gt":v.get("ground_truth_evaluation")} for k,v in res["views"].items()}},allow_nan=False),flush=True)
    def panel(rows,labels,path):
        im=Image.new("RGB",(192*len(labels),28+166*len(rows)),(240,240,240));draw=ImageDraw.Draw(im)
        for i,t in enumerate(labels):draw.text((i*192+5,5),t,fill=(20,20,20))
        for i,(name,status,imgs) in enumerate(rows):
            y=28+i*166;draw.text((4,y),name+" | "+status,fill=(20,20,20))
            for j,img in enumerate(imgs):
                img.thumbnail((180,140));im.paste(img,(j*192+(192-img.width)//2,y+20+(140-img.height)//2))
        im.save(path)
    panel(rows,["Silhouette check","Hull near","Hull far","Aligned hypothesis","True depth"],out/"fixture-hull-review.png")
    panel(rabbit_rows,["Silhouette check","Hull near","Hull far","Aligned hypothesis"],out/"rabbit-hull-review.png")
    report={"schema":1,"status":"measured_experimental_hull_alignment","assets":summaries,"preservation":preserve,
      "limitations":["Visual hull cannot recover hidden concavities or establish anatomical identity.","Voxel approximation and padding can remove or inflate thin features.","Hull midpoint pseudo-anchors are not measured surface anchors; interval compatibility does not imply correctness.","Rabbit cameras use an estimated normalized gauge, and three-quarter remains uncalibrated. Appearance tracks are not semantic landmarks.","No production fusion or reconstruction enabled."]}
    write_json(out/"report.json",report)
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
