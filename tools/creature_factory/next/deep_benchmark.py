"""CPU experiment: compare DINOv2 against SIFT on known geometry and rabbit.
Truth is loaded only for scoring, never for matching."""
from pathlib import Path
import itertools,json,sys,time,resource
import numpy as np
from PIL import Image,ImageDraw
from .audit import write_json,validate_output,ROOT,REGISTRY,verify_sources
from .hull_benchmark import view_files,resize_mask,resize_float,consistency
from .hull_alignment import *
from .deep_correspondence import *
from .geometry_evidence import world_points

def sift_features(im,mask):
    import cv2
    h,w=mask.shape;im=im.convert("RGBA").resize((w,h),Image.Resampling.LANCZOS)
    bg=Image.new("RGBA",im.size,(192,192,192,255));bg.alpha_composite(im)
    kp,d=cv2.SIFT_create(nfeatures=1000,contrastThreshold=.02).detectAndCompute(np.asarray(bg.convert("L")),mask.astype(np.uint8)*255)
    return np.array([[k.pt[0]+.5,k.pt[1]+.5] for k in kp],dtype=np.float32).reshape(-1,2),normalize(d) if d is not None else np.empty((0,128),np.float32)
def sift_matches(pa,fa,pb,fb,a,b,views,hull):
    import cv2
    if min(len(pa),len(pb))<2:return []
    matcher=cv2.BFMatcher(cv2.NORM_L2)
    def good(x,y):return {p.queryIdx:p.trainIdx for p,q in matcher.knnMatch(x,y,k=2) if p.distance<.72*q.distance}
    ab=good(fa,fb);ba=good(fb,fa);out=[]
    for i,j in ab.items():
        if ba.get(j)!=i:continue
        obs={a:pa[i].tolist(),b:pb[j].tolist()}
        try:r=triangulate_observations(obs,views,2)
        except ValueError:continue
        idx=np.floor((np.asarray(r["point"])-hull["origin"])/hull["step"]).astype(int)
        if ((idx>=0)&(idx<np.asarray(hull["grid"].shape))).all() and hull["grid"][tuple(idx)]:out.append({"observations":obs,**r})
    return out
def preview(a,b,images,records,size=260):
    canvas=Image.new("RGB",(size*2,size+24),(224,228,231));draw=ImageDraw.Draw(canvas)
    transforms={}
    for j,n in enumerate((a,b)):
        im=images[n].copy();bg=Image.new("RGBA",im.size,(224,228,231,255));bg.alpha_composite(im);im=bg.convert("RGB")
        w,h=im.size;im.thumbnail((size,size));x=j*size+(size-im.width)//2;y=24+(size-im.height)//2
        canvas.paste(im,(x,y));transforms[n]=(x,y,im.width/w,im.height/h);draw.text((j*size+6,4),n,fill=(20,20,20))
    for r in records[:60]:
        coords=[]
        for n in (a,b):
            x,y=r["observations"][n];ox,oy,sx,sy=transforms[n];coords.append((ox+x*sx,oy+y*sy))
        c=(37,155,100) if r.get("evaluation")=="correct" else (213,76,65) if r.get("evaluation") else (78,119,202)
        draw.line(coords,fill=c,width=1)
        for x,y in coords:draw.ellipse((x-2,y-2,x+2,y+2),fill=c)
    return canvas

def tracks_from_pairs(pairs,views,hull):
    """Three-view tracks with unique patch indices, nonparallel pair edges.
    Shared identity is still an appearance hypothesis."""
    nodes={}
    for (a,b),records in pairs.items():
        for r in records:
            i,j=r["indices"];u=(a,i);v=(b,j)
            nodes.setdefault(u,[]).append((v,r));nodes.setdefault(v,[]).append((u,r))
    out=[];seen=set()
    for u,edges in nodes.items():
        for (v,r),(w,s) in itertools.combinations(edges,2):
            if len({u[0],v[0],w[0]})<3:continue
            key=tuple(sorted((u,v,w)))
            if key in seen:continue
            seen.add(key);obs={**r["observations"],**s["observations"]}
            try:q=triangulate_observations(obs,views,2)
            except ValueError:continue
            idx=np.floor((np.asarray(q["point"])-hull["origin"])/hull["step"]).astype(int)
            if ((idx>=0)&(idx<np.asarray(hull["grid"].shape))).all() and hull["grid"][tuple(idx)]:out.append({"observations":obs,**q})
    return out

def run(fixtures,ab,hullroot,depthroot,model,out):
    start=time.monotonic();out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preserve=verify_sources(ROOT,json.loads(REGISTRY.read_text()));runner=DinoFeatures(model)
    summary={};panels=[];rabbit_panels=[]
    for name in ("flat","wavy","convex","concave","asymmetric","articulation","rabbit"):
        raw=view_files(Path(ab)/name);views={k:(resize_mask(m),c) for k,(m,c,p) in raw.items()}
        images={k:Image.open(p).convert("RGBA").resize((views[k][0].shape[1],views[k][0].shape[0]),Image.Resampling.LANCZOS) for k,(m,c,p) in raw.items()}
        z=np.load(Path(hullroot)/name/"hull.npz");hull={"grid":z["grid"],"origin":z["origin"],"step":float(z["step"])}
        f={k:runner.extract(images[k],m) for k,(m,c) in views.items()};s={k:sift_features(images[k],m) for k,(m,c) in views.items()}
        q=out/name;q.mkdir();pairs={};records={};report={};best=None
        for a,b in itertools.combinations(views,2):
            if abs(np.asarray(basis(views[a][1])[2])@np.asarray(basis(views[b][1])[2]))>.95:continue
            pa,fa=f[a];pb,fb=f[b];deep=geometric_matches(pa,fa,pb,fb,a,b,views,hull)
            unguided=geometric_matches(pa,fa,pb,fb,a,b,views,hull,False)
            baseline=sift_matches(*s[a],*s[b],a,b,views,hull)
            pairs[a,b]=deep;key=a+"/"+b;records[key]={"deep":deep,"unguided":unguided,"sift":baseline}
            if name!="rabbit":
                truth={n:(np.load(Path(fixtures)/name/f"depth-{n}.npy"),np.load(Path(fixtures)/name/f"mask-{n}.npy")) for n in (a,b)}
                report[key]={k:evaluate_matches(v,a,b,views,truth) for k,v in records[key].items()}
            else:report[key]={k:{"matches":len(v),"precision":None} for k,v in records[key].items()}
            n=len(deep)
            if best is None or n>best[0]:best=(n,a,b,deep)
            if name=="rabbit":rabbit_panels.append((key,preview(a,b,images,deep)))
        tracks=tracks_from_pairs(pairs,views,hull)
        # Synthetic and real tracks are appearance hypotheses. On fixtures
        # check every pair inside a track, not just the low reprojection error.
        track_metrics={}
        if name!="rabbit":
            good=0
            for r in tracks:
                names=list(r["observations"]);ok=True
                for a,b in itertools.combinations(names,2):
                    truth={n:(np.load(Path(fixtures)/name/f"depth-{n}.npy"),np.load(Path(fixtures)/name/f"mask-{n}.npy")) for n in (a,b)}
                    check=evaluate_matches([{"observations":r["observations"]}],a,b,views,truth)
                    ok &= check["correct"]==1
                good+=ok
            track_metrics={"correct":int(good),"precision":float(good/len(tracks)) if tracks else None}
        align={}
        if name=="rabbit":
            for k,(m,c) in views.items():
                dp=Path(depthroot)/name/k
                if not (dp/"relative-inverse-depth.npy").exists():continue
                rr=np.load(Path(hullroot)/name/k/"ray-intervals.npz");score=resize_float(np.load(dp/"relative-inverse-depth.npy"),m.shape)
                d,r=align_from_observations(score,m,rr["near"],rr["far"],rr["runs"],hull["step"],k,views,[v["observations"] for v in tracks],"appearance_hypotheses")
                align[k]=r
                if d is not None:np.save(q/(k+"-diagnostic-aligned.npy"),d)
        if best and name!="rabbit":panels.append((name+" "+best[1]+"/"+best[2],preview(best[1],best[2],images,best[3])))
        write_json(q/"matches.json",records);write_json(q/"tracks.json",tracks)
        summary[name]={"pairs":report,"three_view_tracks":len(tracks),"track_evaluation":track_metrics,"alignment":align,"semantic_landmarks":False}
        print(name,"deep",sum(len(v) for v in pairs.values()),"tracks",len(tracks),"align",align,flush=True)
    def panel(items,path):
        w=520;im=Image.new("RGB",(w,310*len(items)),(245,245,245));d=ImageDraw.Draw(im)
        for i,(title,p) in enumerate(items):d.text((4,i*310+4),title,fill=(20,20,20));im.paste(p,(0,i*310+22))
        im.save(path)
    panel(panels,out/"fixture-matches.png");panel(rabbit_panels,out/"rabbit-matches.png")
    aggregate={}
    for method in ("deep","unguided","sift"):
        m=[v[method] for n,r in summary.items() if n!="rabbit" for v in r["pairs"].values()]
        count=sum(v["matches"] for v in m);correct=sum(v["correct"] for v in m)
        aggregate[method]={"matches":count,"correct":correct,"precision":correct/count if count else None}
    report={"schema":1,"status":"measured_candidate_not_adopted","provenance":runner.provenance,"aggregate":aggregate,"assets":summary,"seconds":time.monotonic()-start,"peak_rss_mib":resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1024,"preservation":preserve,
      "limitations":["Deep descriptors are not semantic keypoints; no verified anatomical labels.","Fixture ground truth used solely for scoring; rabbit has estimated cameras and no metric truth.","Geometric filtering and three-view chains can still match wrong surface points. No production fusion.","No threshold tuning or model adoption from this experiment."]}
    write_json(out/"report.json",report);print(json.dumps({"aggregate":aggregate,"seconds":report["seconds"],"rss":report["peak_rss_mib"]}),flush=True)
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
