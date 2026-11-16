"""C4-A actual neural mesh reduction, immutable master and comparison images."""
from pathlib import Path
import json,sys
import numpy as np
from PIL import Image,ImageDraw
from .audit import write_json,validate_output,ROOT,REGISTRY,verify_sources,sha256
from .contracts import path_inside,require
from .mesh_optimization import optimize,cameras
from .rigid_alignment import render_mask
from .landmark_fixture import raster
from .volume_benchmark import export

def run(rabbit,fantasy,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preserve=verify_sources(ROOT,json.loads(REGISTRY.read_text()));reports={}
    for name,source in (("rabbit",rabbit),("fantasy",fantasy)):
        job=source/"job";s=json.loads((job/"job.json").read_text())
        files={}
        for p,h in s["stages"]["candidate_ready"]["outputs"].items():
            q=path_inside(job,p);require(sha256(q)==h,"Changed master");files[q.name]=q
        data=np.load(files["master.npz"]);v=data["vertices"];f=data["faces"]
        q=out/name;q.mkdir()
        a,b,r=optimize(v,f)
        np.savez_compressed(q/"optimized.npz",vertices=a,faces=b);export(a,b,q/"optimized.glb")
        require(r["selected_triangles"]<=r["master_triangles"],"Unexpected geometry growth")
        require(sha256(files["master.npz"])==s["stages"]["candidate_ready"]["outputs"][str(files["master.npz"].relative_to(job))],"Master changed")
        # Clay and silhouette comparison of the actual retained geometry.
        import trimesh
        tex=np.full((128,128,3),190,np.uint8);cams=cameras(v);ims=Image.new("RGB",(768,3*282),(235,237,239));draw=ImageDraw.Draw(ims)
        for row,k in enumerate(("front","right","three-quarter")):
            for col,(label,x,y) in enumerate((("Master",v,f),("Optimized",a,b))):
                mesh=trimesh.Trimesh(vertices=x,faces=y,process=False)
                p=(x,np.asarray(mesh.vertex_normals),np.zeros((len(x),2)),y,tex,tex);rgb,*_=raster([p],cams[k],False)
                bg=Image.new("RGBA",(256,256),(220,225,230,255));bg.alpha_composite(Image.fromarray(rgb));ims.paste(bg.convert("RGB"),(col*256,row*282+26))
                draw.text((col*256+5,row*282+5),label+" "+k,fill=(20,20,20))
            m=render_mask(v,f,cams[k],(256,256));n=render_mask(a,b,cams[k],(256,256));rgb=np.zeros((256,256,3),np.uint8);rgb[m&n]=[170,170,170];rgb[m&~n]=[230,70,60];rgb[n&~m]=[60,150,230]
            ims.paste(Image.fromarray(rgb),(512,row*282+26));draw.text((517,row*282+5),"Silhouette difference",fill=(20,20,20))
        ims.save(q/"optimization-review.png");r["master_sha256"]=sha256(files["master.npz"]);write_json(q/"report.json",r);reports[name]=r
        print(name,json.dumps({"status":r["status"],"master":r["master_triangles"],"selected":r["selected_triangles"],"attempts":[{"triangles":x.get("triangles"),"passed":x["passed"],"reason":x["reason"],"failed":x.get("failed_metrics")} for x in r["attempts"]]}),flush=True)
    write_json(out/"report.json",{"schema":1,"status":"measured_adaptive_optimization","assets":reports,"preservation":preserve,"production_approval":False})
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
