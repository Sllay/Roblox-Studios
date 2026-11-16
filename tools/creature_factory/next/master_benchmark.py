"""End-to-end C3-A adapter smoke with real archive and independent renders."""
from pathlib import Path
from dataclasses import asdict
import sys,json,shutil
import numpy as np
from PIL import Image,ImageDraw
from .audit import ROOT,REGISTRY,verify_sources,sha256,write_json,validate_output
from .contracts import legacy_rabbit,require
from .dag import build,validate_job
from .landmark_fixture import raster,camera
from .anatomy import Anatomy,Part

def run(archive,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preservation=verify_sources(ROOT,json.loads(REGISTRY.read_text()))
    src=ROOT/"asset-library/references/rabbit-v1";m=legacy_rabbit(src);stage=out/"input";stage.mkdir()
    for n in {v.source for v in m.views}:shutil.copyfile(src/n,stage/n)
    shutil.copyfile(archive,stage/"checkpoint.zip")
    raw=asdict(m);parts=[Part("body","body"),Part("head","head","body")]
    for side in ("left","right"):
        parts.append(Part(side+"_ear","ear","head",side,protected=True,articulation="ball"))
        for i in range(3):parts.append(Part(f"{side}_whisker_{i}","whisker","head",side,protected=True,thin=True))
    raw["identity"]["anatomy"]=asdict(Anatomy(parts,{"ear":2,"whisker":6}))
    write_json(stage/"manifest.json",raw)
    config={"candidate_ready":{"backend":"verified_triposr_checkpoint","archive":"checkpoint.zip","sha256":"d045c52dd746d74db9b37dd5b974791c52a11813750efdd2b38536e5d706dd9c"}}
    job=out/"job";s=build(stage/"manifest.json",job,config)
    c=s["stages"]["candidate_ready"]
    require(c["state"]=="succeeded",str(c))
    require(s["stages"]["master_ready"]["state"]=="blocked","Production gate bypass")
    a=build(stage/"manifest.json",job,config,resume=True)
    require(a["stages"]["candidate_ready"]["attempt"]==c["attempt"],"Candidate cache not reused")
    require(validate_job(job)["status"]=="valid_incomplete","Job integrity")
    files={Path(p).name:job/p for p in c["outputs"]}
    # Independent CPU triangle rasterization of the actual imported vertices.
    import trimesh
    data=np.load(files["master.npz"]);v=data["vertices"];f=data["faces"]
    mesh=trimesh.Trimesh(vertices=v,faces=f,process=False)
    texture=np.full((128,128,3),190,np.uint8);part=(v,np.asarray(mesh.vertex_normals),np.zeros((len(v),2)),f,texture,texture)
    sheet=Image.new("RGB",(1024,282),(233,235,238));draw=ImageDraw.Draw(sheet)
    for i,(name,dir) in enumerate((("Front",(0,-1,0)),("Side",(1,0,0)),("Back",(0,1,0)),("Three-quarter",(-1,-1,.8)))):
        rgba,*_=raster([part],camera(dir),False);im=Image.fromarray(rgba);bg=Image.new("RGBA",im.size,(221,225,229,255));bg.alpha_composite(im)
        sheet.paste(bg.convert("RGB"),(256*i,26));draw.text((256*i+6,6),name,fill=(20,20,20))
    sheet.save(out/"master-review.png")
    shutil.copyfile(files["master.glb"],out/"master.glb")
    report=json.loads(files["candidate.json"].read_text());report.update(cache_reused=True,preservation=preservation,job_status=s["status"])
    write_json(out/"report.json",report);print(json.dumps(report),flush=True)
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
