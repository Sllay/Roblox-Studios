"""Validate triangulated pixel correspondences as depth anchors.

Synthetic annotation generator can inspect fixture geometry to simulate a
correct match; the solver receives only pixels, cameras, scores and hull.
Real rabbit uses appearance hypotheses, not fabricated anatomy.
"""
from pathlib import Path
import json,sys
import numpy as np
from PIL import Image,ImageDraw
from .hull_alignment import *
from .hull_benchmark import view_files,resize_mask,resize_float,gray_depth,consistency
from .geometry_evidence import world_points
from .audit import write_json,validate_output

def synthetic_annotations(root,views,source):
    # Test-only reference observations, with visibility verified against exact
    # C1 depth buffers. No world point or true depth is passed to the solver.
    p=Path(root);mask=np.load(p/f"mask-{source}.npy");depth=np.load(p/f"depth-{source}.npy")
    _,cam=views[source];points=world_points(depth,mask,cam);h,w=mask.shape
    truth={k:(np.load(p/f"depth-{k}.npy"),np.load(p/f"mask-{k}.npy")) for k in views}
    out=[]
    for y in range(3,h-3,5):
        for x in range(3,w-3,5):
            if not mask[y-1:y+2,x-1:x+2].all():continue
            q=points[y,x];obs={source:[x+.5,y+.5]}
            for name,(m,c) in views.items():
                if name==source:continue
                d,gt=truth[name];px,py,z=ortho_project(q,c,m.shape);ix,iy=int(np.floor(px)),int(np.floor(py))
                if not (1<=ix<m.shape[1]-1 and 1<=iy<m.shape[0]-1 and gt[iy-1:iy+2,ix-1:ix+2].all()):continue
                # Only observations of the same visible surface, not occlusions.
                if abs(float(d[iy,ix])-z)>max(.035,c.ortho_scale/max(m.shape)*1.5):continue
                if abs(np.asarray(basis(c)[2])@np.asarray(basis(cam)[2]))>.95:continue
                obs[name]=[float(px),float(py)]
            if len(obs)>=2:out.append(obs)
    return out

def run(fixtures,ab,depthroot,hullroot,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    report={};rows=[]
    for name in ("flat","wavy","convex","concave","asymmetric","articulation","rabbit"):
        views={k:(resize_mask(m),c) for k,(m,c,p) in view_files(Path(ab)/name).items()}
        q=out/name;q.mkdir();h=np.load(Path(hullroot)/name/"hull.npz");step=float(h["step"]);report[name]={};candidates={}
        for k,(m,c) in views.items():
            dp=Path(depthroot)/name/k
            if not (dp/"relative-inverse-depth.npy").exists():continue
            p=q/k;p.mkdir();z=np.load(Path(hullroot)/name/k/"ray-intervals.npz");near,far,runs=z["near"],z["far"],z["runs"]
            score=resize_float(np.load(dp/"relative-inverse-depth.npy"),m.shape)
            if name=="rabbit":
                tracks=json.loads((Path(hullroot)/name/"appearance-tracks.json").read_text())["three_view_tracks"]
                obs=[t["observations"] for t in tracks];kind="appearance_hypotheses"
            else:obs=synthetic_annotations(Path(fixtures)/name,views,k);kind="synthetic_annotations"
            write_json(p/"observations.json",{"source":kind,"observations":obs})
            d,r=align_from_observations(score,m,near,far,runs,step,k,views,obs,kind)
            valid=m&(near>0);lo=float(near[valid].min());hi=float(far[valid].max())
            if d is not None:
                np.save(p/"aligned.npy",d);candidates[k]=(d,d>0);gray_depth(d,d>0,lo,hi).save(p/"aligned.png")
            if name!="rabbit":
                gt=np.load(Path(fixtures)/name/f"depth-{k}.npy");gm=np.load(Path(fixtures)/name/f"mask-{k}.npy")
                if d is not None:
                    ok=(d>0)&gm;err=abs(d[ok]-gt[ok]);base=abs(near[ok]-gt[ok])
                    r.update(dense_truth_mae=float(err.mean()),same_pixel_hull_mae=float(base.mean()),dense_truth_pixels=int(ok.sum()),improvement_over_hull_near=float(1-err.mean()/max(base.mean(),1e-12)))
                gray_depth(gt,gm,lo,hi).save(p/"truth.png")
                images=[gray_depth(near,near>0,lo,hi),Image.open(p/"aligned.png") if d is not None else Image.new("RGB",(m.shape[1],m.shape[0]),(40,40,40)),Image.open(p/"truth.png")]
                rows.append((name+"/"+k,r["status"],images))
            report[name][k]=r;print(name,k,r,flush=True)
        report[name]["cross_view"]=consistency(candidates,views,step)
    im=Image.new("RGB",(660,26+166*len(rows)),(240,240,240));draw=ImageDraw.Draw(im)
    for j,t in enumerate(("Hull near","Triangulated alignment","True depth")):draw.text((j*220+5,5),t,fill=(20,20,20))
    for i,(name,status,imgs) in enumerate(rows):
        y=26+i*166;draw.text((4,y),name+" | "+status,fill=(20,20,20))
        for j,img in enumerate(imgs):
            img.thumbnail((204,142));im.paste(img,(j*220+(220-img.width)//2,y+20+(142-img.height)//2))
    im.save(out/"anchor-review.png")
    write_json(out/"report.json",{"schema":1,"status":"measured_anchor_alignment","assets":report,"limitations":["Synthetic exact correspondences are generated from C1 ground truth for test only; no world truth is supplied to the alignment solver.","Rabbit appearance hypotheses are not verified anatomical landmarks; no metric alignment or fusion.","No production reconstruction enabled."]})
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
