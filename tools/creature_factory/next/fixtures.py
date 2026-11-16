"""Generate real Blender fixtures and validate their known geometry."""
from pathlib import Path
from dataclasses import asdict
import json,os,shutil
from .audit import validate_output,measured_command,sha256,write_json,glb_metadata
from .contracts import *
from .backends import probe
def generate(out,blender="blender",resolution=128):
    import numpy as np
    from PIL import Image,ImageDraw
    out=validate_output(Path(out));require(64<=resolution<=512,"Resolution 64..512")
    out.mkdir(parents=True,exist_ok=True);require(not any(out.iterdir()),"Fixture output must be empty")
    pre=probe(out/"preflight",blender)
    require(pre["backends"]["blender_cpu"]["available"],"Blender preflight failed")
    worker=Path(__file__).with_name("blender_fixtures.py")
    run=measured_command([shutil.which(blender),"--background","--factory-startup","--threads","2","--python-exit-code","1","--python",str(worker),"--",str(out),str(resolution)],out/"worker.log",600)
    require(run["status"]=="passed","Fixture worker failed; inspect worker.log")
    kinds=("flat","wavy","convex","concave","asymmetric","articulation")
    panel=Image.new("RGB",(resolution*4,(resolution+24)*len(kinds)+28),(242,242,242));draw=ImageDraw.Draw(panel)
    for i,label in enumerate(("3/4 render","Top mask","Top depth 7-9","World normals")):draw.text((i*resolution+4,8),label,fill=(20,20,20))
    summaries={}
    for k,kind in enumerate(kinds):
        p=out/kind;raw=json.loads((p/"geometry.json").read_text())
        sheet=Image.new("RGBA",(resolution*4,resolution*2),(0,0,0,0))
        for i,name in enumerate(VIEWS):
            with Image.open(p/("color-"+name+".png")) as im:sheet.paste(im,(i%4*resolution,i//4*resolution))
        sheet.save(p/"references.png")
        sh=sha256(p/"references.png")
        views=[ReferenceView(name,"references.png",sh,[i%4*resolution,i//4*resolution,resolution,resolution],CameraCalibration(**raw["cameras"][name])) for i,name in enumerate(VIEWS)]
        params=raw["parameters"]
        m=AssetManifest(kind,"thin_surface" if kind in ("flat","wavy") else "hard_surface",views,units="unit",symmetry="intentional_asymmetry" if kind=="asymmetric" else "none",
            parts=[{"id":x} for x in raw["objects"]],landmarks=[{"id":"center","xyz":[0,0,params.get("center_height",0)]}],
            articulations=[{"id":"joint","pivot":params["joint"],"clearance":params["gap"]}] if kind=="articulation" else [],
            protected_regions=[{"part":"thin_strand"}] if kind=="articulation" else [],
            thin_parts=[{"thickness":params.get("thickness",params.get("thin_width"))}] if kind in ("flat","wavy","articulation") else [],
            identity={"fixture":True,"parameters":params})
        write_json(p/"manifest.json",asdict(m));valid=validate_manifest(m,p)
        evid=[]
        for v in views:
            name=v.id;d=np.load(p/f"depth-{name}.npy");n=np.load(p/f"normal-{name}.npy");mask=np.load(p/f"mask-{name}.npy")
            require(d.dtype==np.float32 and n.dtype==np.float32 and mask.dtype==bool,"Wrong evidence dtype")
            require(d.shape==mask.shape and n.shape==(*mask.shape,3),"Evidence shape")
            require(np.isfinite(d).all() and np.isfinite(n).all() and (d[mask]>0).all() and np.allclose(np.linalg.norm(n[mask],axis=1),1,atol=1e-5),"Invalid evidence")
            require(not d[~mask].any() and not n[~mask].any(),"Background nonzero")
            evid.append(asdict(EvidenceBundle(name,v.camera,f"mask-{name}.npy",f"depth-{name}.npy",f"normal-{name}.npy")))
        write_json(p/"evidence.json",{"schema":1,"views":evid})
        write_json(p/"artifact.json",asdict(GeometryArtifact("ground-truth.glb",sha256(p/"ground-truth.glb"),"unit",raw["vertices"],raw["triangles"])))
        require(glb_metadata(p/"ground-truth.glb")["triangles"]==raw["triangles"],"GLB count differs from source")
        bounds=raw["bounds"]
        if kind=="asymmetric":
            require(abs(bounds["left_marker"]["min"][0]-params["left_extent"])<1e-5 and abs(bounds["right_marker"]["max"][0]-params["right_extent"])<1e-5,"Asymmetry bounds")
        if kind=="articulation":
            gap=bounds["limb"]["min"][0]-bounds["torso"]["max"][0]
            width=bounds["thin_strand"]["max"][0]-bounds["thin_strand"]["min"][0]
            require(abs(gap-params["gap"])<1e-5 and abs(width-params["thin_width"])<1e-5,"Joint gap/strand mismatch")
        y=28+k*(resolution+24);draw.text((5,y+4),kind,fill=(20,20,20))
        for j,name in enumerate(("color-three-quarter.png","mask-top.npy","depth-top.png","normal-top.png")):
            if name.endswith(".npy"):
                mask=np.load(p/name);im=Image.fromarray(mask.astype("uint8")*255).convert("RGB")
            elif name=="depth-top.png":
                depth=np.load(p/"depth-top.npy");mask=np.load(p/"mask-top.npy")
                rgb=np.zeros((*mask.shape,3),np.uint8);rgb[mask]=np.rint(np.clip((9-depth[mask])/2,0,1)*255).astype(np.uint8)[:,None]
                im=Image.fromarray(rgb)
            else:
                im=Image.open(p/name).convert("RGBA");bg=Image.new("RGBA",im.size,(220,225,230,255));bg.alpha_composite(im);im=bg.convert("RGB")
            panel.paste(im,(j*resolution,y+24))
        summaries[kind]={"parameters":params,"views":7,"validation":valid,"triangles":raw["triangles"],"bounds":bounds}
    def compare(a,b):
        A=out/a;B=out/b;ma=np.load(A/"mask-top.npy");mb=np.load(B/"mask-top.npy");m=ma&mb
        d=np.abs(np.load(A/"depth-top.npy")[m]-np.load(B/"depth-top.npy")[m]);na=np.load(A/"normal-top.npy")[m];nb=np.load(B/"normal-top.npy")[m]
        return {"iou":float(m.sum()/(ma|mb).sum()),"max_depth_difference":float(d.max()),"mean_depth_difference":float(d.mean()),"mean_normal_angle_degrees":float(np.degrees(np.arccos(np.clip((na*nb).sum(1),-1,1))).mean())}
    wave=compare("flat","wavy");cavity=compare("convex","concave")
    require(wave["iou"]>.999 and wave["max_depth_difference"]>.20 and wave["mean_normal_angle_degrees"]>10,"Wavy fixture distinction failed")
    require(cavity["iou"]>.999 and cavity["max_depth_difference"]>.65,"Concavity fixture distinction failed")
    panel.resize((panel.width*2,panel.height*2),Image.Resampling.NEAREST).save(out/"fixture-review.png")
    report={"schema":1,"status":"fixture_validated","fixtures":summaries,"flat_vs_wavy":wave,"convex_vs_concave":cavity,"scope":"known synthetic geometry only; no reconstruction","artistic_approval":False,"publication_allowed":False}
    write_json(out/"report.json",report);return report
