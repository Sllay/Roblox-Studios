"""C3-B compare real candidate meshes with reference masks; no regeneration."""
from pathlib import Path
import json,sys,shutil
import numpy as np
from PIL import Image,ImageDraw
from .audit import write_json,validate_output,sha256,ROOT,REGISTRY,verify_sources
from .contracts import CameraCalibration,require,path_inside
from .rigid_alignment import fit_similarity,render_mask,resized,iou
from .landmark_fixture import raster,camera
def run(rabbit,fantasy,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preserve=verify_sources(ROOT,json.loads(REGISTRY.read_text()));reports={}
    for label,source,train,held in (("rabbit",rabbit,["front","right"],["back","left"]),("fantasy",fantasy,["front","right","top"],["back","left","bottom","three-quarter"])):
        job=source/"job";state=json.loads((job/"job.json").read_text())
        def files(stage):
            result={}
            for p,h in state["stages"][stage]["outputs"].items():
                q=path_inside(job,p);require(sha256(q)==h,"Stale job artifact");result[q.name]=q
            return result
        candidate=files("candidate_ready");seg=files("segmentation_ready");cal=json.loads(files("calibration_ready")["calibration.json"].read_text())
        data=np.load(candidate["master.npz"]);v=data["vertices"];f=data["faces"];views={}
        for k in train+held:
            c=CameraCalibration(**cal["views"][k]["camera"]);m=np.asarray(Image.open(seg[k+"-core-mask.png"]))>0
            views[k]=(m,c)
        aligned,baseline,report=fit_similarity(v,f,views,train,held)
        q=out/label;q.mkdir();np.savez_compressed(q/"aligned-hypothesis.npz",vertices=aligned.astype(np.float32),faces=f)
        # Candidate diagnostic geometry is separate, never replace original.
        import trimesh
        # Convert world Z-up to glTF Y-up on the export boundary.
        gltf=aligned[:,[0,2,1]].copy();gltf[:,2]*=-1
        trimesh.Trimesh(vertices=gltf,faces=f,process=False).export(q/"aligned-hypothesis.glb")
        small=resized(views,192);panel=Image.new("RGB",(192*len(small),3*212),(235,237,239));draw=ImageDraw.Draw(panel)
        for i,(k,(m,c)) in enumerate(small.items()):
            for j,(title,mask) in enumerate((("Reference",m),("Initial",render_mask(baseline,f,c,m.shape)),("Aligned",render_mask(aligned,f,c,m.shape)))):
                img=Image.fromarray(mask.astype(np.uint8)*255).convert("RGB");panel.paste(img,(i*192+(192-img.width)//2,j*212+20+(192-img.height)//2))
                draw.text((i*192+4,j*212+4),title+" "+k+(" (H)" if k in held else ""),fill=(20,20,20))
        panel.save(q/"silhouette-review.png")
        # Check isotropic scaling on actual mesh edges, not just params.
        e=f[:min(len(f),10000),:2];a=np.linalg.norm(v[e[:,0]]-v[e[:,1]],axis=1);b=np.linalg.norm(aligned[e[:,0]]-aligned[e[:,1]],axis=1);ok=a>1e-7
        report["max_relative_edge_scale_error"]=float(np.max(abs(b[ok]/a[ok]/report["scale"]-1)))
        require(report["max_relative_edge_scale_error"]<1e-3,"Nonuniform deformation")
        # Extent anisotropy cannot change through a rigid similarity.
        report["native_extent"]=np.ptp(v,axis=0).tolist()
        write_json(q/"report.json",report);reports[label]=report
        print(label,json.dumps(report),flush=True)
    write_json(out/"report.json",{"schema":1,"status":"measured_similarity_alignment","assets":reports,"preservation":preserve})
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
