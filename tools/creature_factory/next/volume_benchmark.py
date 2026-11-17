"""C3-C measured depth reconstruction and neural/hull candidate benchmark.
Exact C1 depth is input only for the controlled depth reconstruction test.
Real concepts never receive synthetic or fabricated depth.
"""
from pathlib import Path
import json,sys
import numpy as np
from PIL import Image,ImageDraw
from .audit import write_json,validate_output,sha256,ROOT,REGISTRY,verify_sources
from .contracts import AssetManifest,CameraCalibration,require,path_inside
from .volumetric_reconstruction import *
from .rigid_alignment import render_mask,resized,iou
from .master_candidate import inspect_mesh
from .landmark_fixture import raster,camera,RES,DIRECTIONS

def export(v,f,path):
    import trimesh
    q=v[:,[0,2,1]].copy();q[:,2]*=-1
    mesh=trimesh.Trimesh(vertices=q,faces=f,process=False);mesh.export(path)
    from .audit import glb_metadata
    require(glb_metadata(path)["triangles"]==len(f),"Export lost faces")
def compare_depth(fixtures,out):
    report={};rows=[]
    for name in ("flat","wavy","convex","concave","asymmetric","articulation"):
        p=fixtures/name;m=AssetManifest.read(p/"manifest.json")
        views={v.id:(np.load(p/f"mask-{v.id}.npy"),v.camera) for v in m.views}
        depths={k:np.load(p/f"depth-{k}.npy") for k in views}
        train=["front","right","top","bottom"];held=["back","left","three-quarter"]
        tv={k:views[k] for k in train};h=build_hull(tv,128,1)
        carved,stats=carve_known_depth(h,tv,{k:depths[k] for k in train})
        before=depth_metrics(h,views,{k:depths[k] for k in held});after=depth_metrics(carved,views,{k:depths[k] for k in held})
        q=out/name;q.mkdir(parents=True);v,f=surface_from_grid(carved)
        export(v,f,q/"reconstructed.glb");np.savez_compressed(q/"reconstructed.npz",vertices=v,faces=f)
        report[name]={"train_views":train,"holdout_views":held,"carving":stats,"before":before,"after":after,"mesh":inspect_mesh(v,f)}
        # Independent depth maps: original hull, carved hull, heldout truth.
        k="three-quarter";mask,c=views[k];n0,_,_=ray_intervals(h,c,mask.shape);n1,_,_=ray_intervals(carved,c,mask.shape)
        gt=depths[k];lo=float(gt[mask].min())-.15;hi=float(gt[mask].max())+.15
        def vis(d):
            a=np.zeros(d.shape,np.uint8);ok=d>0;a[ok]=np.rint(np.clip((hi-d[ok])/max(hi-lo,1e-8),0,1)*255).astype(np.uint8);return Image.fromarray(a).convert("RGB")
        rows.append((name,[vis(n0),vis(n1),vis(gt)]))
    # Critical controlled tests: held-out 3/4 depth should improve on both
    # wavy and concave without substantial loss of valid surface coverage.
    for name in ("wavy","concave"):
        a=report[name]["before"]["three-quarter"];b=report[name]["after"]["three-quarter"]
        require(b["near_mae"]<a["near_mae"]*.85,f"Depth reconstruction failed {name}: {a} {b}")
        require(b["coverage"]>=a["coverage"]-.05,"Depth carving lost surface coverage")
    panel(rows,["Silhouette hull","Depth-carved hull","Held-out true depth"],out/"depth-review.png")
    return report

def panel(rows,labels,path):
    w=200*len(labels);im=Image.new("RGB",(w,26+172*len(rows)),(235,237,239));draw=ImageDraw.Draw(im)
    for i,t in enumerate(labels):draw.text((i*200+4,5),t,fill=(20,20,20))
    for i,(name,imgs) in enumerate(rows):
        y=26+i*172;draw.text((4,y),name,fill=(20,20,20))
        for j,a in enumerate(imgs):
            a=a.convert("RGB");a.thumbnail((190,145));im.paste(a,(j*200+(200-a.width)//2,y+20+(145-a.height)//2))
    im.save(path)

def sample_surface(v,f,count,seed):
    rng=np.random.default_rng(seed);p=v[f];area=np.linalg.norm(np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]),axis=1)
    ids=rng.choice(len(f),count,p=area/area.sum());q=p[ids];u=np.sqrt(rng.random(count));b=rng.random(count)
    return q[:,0]*(1-u[:,None])+q[:,1]*(u*(1-b))[:,None]+q[:,2]*(u*b)[:,None]

def truth_score(v,f,parts,defs):
    from scipy.spatial import cKDTree
    pred=sample_surface(v,f,30000,10);pt=cKDTree(pred);truth=[];recall={}
    for i,p in enumerate(parts):
        q=sample_surface(p[0],p[3],2000,100+i);truth.append(q);dist=pt.query(q)[0]
        recall[defs[i].id]={"kind":defs[i].kind,"mean_distance":float(dist.mean()),"within_0_08":float((dist<=.08).mean())}
    t=np.concatenate(truth);a=pt.query(t)[0];b=cKDTree(t).query(pred)[0]
    return {"mean_bidirectional_distance":float((a.mean()+b.mean())/2),"truth_to_candidate_mean":float(a.mean()),"candidate_to_truth_mean":float(b.mean()),"part_surface_recall":recall,"scope":"known technical fixture surface scoring, not semantic detection"}

def compare_neural(rabbit,fantasy,alignment,out):
    from .fantasy_smoke import fixture_geometry
    parts,anatomy=fixture_geometry()
    reports={}
    for name,src,train,held in (("rabbit",rabbit,["front","right"],["back","left"]),("fantasy",fantasy,["front","right","top"],["back","left","bottom","three-quarter"])):
        job=src/"job";state=json.loads((job/"job.json").read_text())
        def files(stage):
            r={}
            for p,h in state["stages"][stage]["outputs"].items():
                q=path_inside(job,p);require(sha256(q)==h,"Changed source evidence");r[q.name]=q
            return r
        seg=files("segmentation_ready");cal=json.loads(files("calibration_ready")["calibration.json"].read_text())
        views={k:(np.asarray(Image.open(seg[k+"-core-mask.png"]))>0,CameraCalibration(**cal["views"][k]["camera"])) for k in train+held}
        tv={k:views[k] for k in train};hull=build_hull(resized(tv,192),128,1)
        source=np.load(alignment/name/"aligned-hypothesis.npz");v=source["vertices"];f=source["faces"]
        prior=neural_occupancy(v,f,hull);grids=prior_candidates(hull,prior);q=out/name;q.mkdir(parents=True)
        vs=resized(views,192);meshes={"neural":(v,f)};metrics={}
        def score(v,f):
            s={k:iou(render_mask(v,f,c,m.shape),m) for k,(m,c) in vs.items()}
            return {"views":s,"train_mean":float(np.mean([s[k] for k in train])),"holdout_mean":float(np.mean([s[k] for k in held]))}
        metrics["neural"]=score(v,f)
        for k,g in grids.items():
            a,b=surface_from_grid({**hull,"grid":g});meshes[k]=(a,b);r=score(a,b)
            r["prior_iou"]=float((g&prior).sum()/max(1,(g|prior).sum()))
            r["training_objective"]=r["train_mean"]-.1*(1-r["prior_iou"])
            r["mesh"]=inspect_mesh(a,b);metrics[k]=r
        # Choose from predeclared candidate family using training only.
        # Heldout data evaluates, never picks or tunes the candidate.
        chosen=max(grids,key=lambda k:metrics[k]["training_objective"]);a,b=meshes[chosen]
        for k,(x,y) in meshes.items():
            if name=="fantasy":metrics[k]["truth_evaluation"]=truth_score(x,y,parts,anatomy.parts)
        improved=metrics[chosen]["holdout_mean"]>metrics["neural"]["holdout_mean"]+.005
        export(a,b,q/"volume-hypothesis.glb");np.savez_compressed(q/"volume-hypothesis.npz",vertices=a,faces=b)
        # Render the actual candidate geometry with calibrated cameras for the
        # technical fantasy. For rabbit, normalized estimated gauge only.
        rows=[]
        for k,(m,c) in vs.items():
            ims=[Image.fromarray(m.astype(np.uint8)*255),Image.fromarray(render_mask(v,f,c,m.shape).astype(np.uint8)*255),Image.fromarray(render_mask(*meshes["hull"],c,m.shape).astype(np.uint8)*255),Image.fromarray(render_mask(a,b,c,m.shape).astype(np.uint8)*255)]
            rows.append((k+(" heldout" if k in held else ""),ims))
        panel(rows,["Reference","Neural prior","Hull only","Selected volume"],q/"comparison.png")
        if name=="fantasy":
            import trimesh
            mesh=trimesh.Trimesh(vertices=a,faces=b,process=False);tex=np.full((128,128,3),190,np.uint8)
            part=(a,np.asarray(mesh.vertex_normals),np.zeros((len(a),2)),b,tex,tex);rr=[]
            for k in ("front","right","three-quarter"):
                rgb,*_=raster([part],views[k][1],False);im=Image.fromarray(rgb);bg=Image.new("RGBA",im.size,(220,225,230,255));bg.alpha_composite(im);rr.append((k,[bg.convert("RGB")]))
            panel(rr,["Selected volume clay"],q/"clay.png")
        reports[name]={"selected":chosen,"holdout_improved_over_neural":improved,"metrics":metrics,"train":train,"heldout":held,"production_approval":False,"depth_used":False,"limitations":["No trusted depth available; prior/visual hull hypotheses only.","Candidate selection uses training silhouettes, not anatomical verification."]}
        write_json(q/"report.json",reports[name]);print(name,json.dumps({"selected":chosen,"metrics":{k:{a:b for a,b in r.items() if a in ("train_mean","holdout_mean","prior_iou")} for k,r in metrics.items()}}),flush=True)
    return reports

def run(fixtures,rabbit,fantasy,alignment,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preservation=verify_sources(ROOT,json.loads(REGISTRY.read_text()))
    depth=compare_depth(fixtures,out/"known-depth");neural=compare_neural(rabbit,fantasy,alignment,out/"candidates")
    write_json(out/"report.json",{"schema":1,"status":"measured_volumetric_candidates","known_depth":depth,"neural_hypotheses":neural,"preservation":preservation,"production_approval":False})
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
