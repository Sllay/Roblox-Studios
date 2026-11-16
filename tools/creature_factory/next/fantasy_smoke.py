"""Fresh, generic neural generation smoke on a known fantasy creature.

This is a deliberately simple technical input, not artistic production.
No geometry from the source fixture is passed to the neural generator.
"""
from pathlib import Path
from dataclasses import asdict
import sys,json
import numpy as np
from PIL import Image,ImageDraw
from .anatomy import Anatomy,Part
from .contracts import AssetManifest,ReferenceView,VIEWS,require
from .audit import write_json,sha256,validate_output
from .landmark_fixture import sphere,raster,camera,RES,DIRECTIONS
from .dag import build,validate_job

def run(upstream,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    src=out/"input";src.mkdir()
    defs=[Part("body","body")]
    data=[((0,.1,1.12),(.60,1.0,.48))]
    def add(id,kind,center,radii,side="none",thin=False):
        defs.append(Part(id,kind,"body",side,protected=thin,thin=thin,articulation="ball" if kind in ("leg","wing","head") else "flexible"))
        data.append((center,radii))
    # Two heads, six legs, four thin wings, one asymmetric tail.
    for side,sign in (("left",1),("right",-1)):
        add(side+"_head","head",(sign*.35,-.91,1.60),(.34,.41,.35),side)
        for i,y in enumerate((-.55,.10,.75)):
            add(f"{side}_leg_{i}","leg",(sign*.46,y,.54),(.16,.19,.57),side)
        for i,y in enumerate((-.15,.52)):
            add(f"{side}_wing_{i}","wing",(sign*.88,y,1.43+i*.24),(.64,.33,.075),side,True)
    add("tail","tail",(.28,1.23,1.18),(.20,.45,.16))
    anatomy=Anatomy(defs,{"head":2,"leg":6,"wing":4,"tail":1})
    parts=[]
    for i,(center,radii) in enumerate(data):
        v,n,uv,f=sphere(center,radii)
        # Distinct but simple painted colors, not marker IDs.
        color=(86,153,123) if defs[i].kind=="wing" else (174,119,72)
        tex=np.tile(np.asarray(color,np.uint8),(128,128,1));parts.append((v,n,uv,f,tex,tex))
    sheet=Image.new("RGBA",(RES*4,RES*2));views=[]
    for i,name in enumerate(VIEWS):
        c=camera(DIRECTIONS[name]);rgb,d,m,n,ids=raster(parts,c,False)
        im=Image.fromarray(rgb);im.save(out/(name+"-reference.png"))
        sheet.paste(im,((i%4)*RES,(i//4)*RES))
        views.append((name,c))
    sheet.save(src/"references.png");h=sha256(src/"references.png")
    manifest=AssetManifest("fantasy-technical-smoke","creature",[ReferenceView(name,"references.png",h,[(i%4)*RES,(i//4)*RES,RES,RES],c) for i,(name,c) in enumerate(views)],units="unit",symmetry="intentional_asymmetry",identity={"anatomy":asdict(anatomy),"technical_fixture":True})
    write_json(src/"manifest.json",asdict(manifest))
    cfg={"candidate_ready":{"backend":"generic_triposr","upstream":str(upstream.resolve()),"resolution":128,"view":"three-quarter"}}
    job=out/"job";s=build(src/"manifest.json",job,cfg);c=s["stages"]["candidate_ready"]
    require(c["state"]=="succeeded",str(c))
    require(s["stages"]["master_ready"]["state"]=="blocked","Production gate bypass")
    require(build(src/"manifest.json",job,cfg,resume=True)["stages"]["candidate_ready"]["attempt"]==c["attempt"],"Inference cache miss")
    require(validate_job(job)["status"]=="valid_incomplete","Job integrity")
    files={Path(p).name:job/p for p in c["outputs"]}
    import shutil,trimesh
    shutil.copyfile(files["master.glb"],out/"master.glb")
    z=np.load(files["master.npz"]);v=z["vertices"];f=z["faces"]
    # For visualization only, normalize the native mesh to the fixture camera
    # volume; no claimed alignment, no geometry edits to the master file.
    lo=v.min(0);hi=v.max(0);vv=(v-(lo+hi)/2)*(2.4/max(hi-lo))+[0,0,1.15]
    mesh=trimesh.Trimesh(vertices=vv,faces=f,process=False);tex=np.full((128,128,3),190,np.uint8)
    part=(vv,np.asarray(mesh.vertex_normals),np.zeros((len(vv),2)),f,tex,tex)
    panel=Image.new("RGB",(RES*4,RES*2+48),(235,237,239));draw=ImageDraw.Draw(panel)
    for i,name in enumerate(("front","right","back","three-quarter")):
        im=Image.open(out/(name+"-reference.png"));bg=Image.new("RGBA",im.size,(220,225,230,255));bg.alpha_composite(im)
        panel.paste(bg.convert("RGB"),(i*RES,24));draw.text((i*RES+4,5),"Reference "+name,fill=(20,20,20))
        rgb,*_=raster([part],camera(DIRECTIONS[name]),False);im=Image.fromarray(rgb);bg=Image.new("RGBA",im.size,(220,225,230,255));bg.alpha_composite(im)
        panel.paste(bg.convert("RGB"),(i*RES,RES+48));draw.text((i*RES+4,RES+28),"Native candidate "+name,fill=(20,20,20))
    panel.save(out/"fantasy-review.png")
    report=json.loads(files["candidate.json"].read_text());report.update(declared_anatomy=anatomy.summary(),cache_reused=True,geometry_anatomy_verified=False,job_status=s["status"])
    write_json(out/"report.json",report);print(json.dumps(report),flush=True)
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
