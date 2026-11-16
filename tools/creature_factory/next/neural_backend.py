"""Generic local TripoSR inference for a single chosen reference.

No species-specific image edits, shape primitives, component removal,
triangle ceiling, UV generation or artificial anatomy certification.
"""
from pathlib import Path
import sys,os,subprocess,tempfile,shutil,time
from .contracts import require,GeometryArtifact
from .audit import sha256,write_json,glb_metadata
from .master_candidate import inspect_mesh
from dataclasses import asdict
CODE_REV="107cefdc244c39106fa830359024f6a2f1c78871"
def generate_candidate(m,source,out,cfg,inputs):
    import numpy as np
    import torch,trimesh
    from PIL import Image
    from skimage.measure import marching_cubes
    from .contracts import path_inside
    upstream=Path(cfg["upstream"]).resolve()
    require(subprocess.check_output(["git","-C",str(upstream),"rev-parse","HEAD"],text=True).strip()==CODE_REV,"Upstream revision mismatch")
    require(not subprocess.check_output(["git","-C",str(upstream),"status","--porcelain","--untracked-files=no"],text=True).strip(),"Upstream has modified tracked files")
    resolution=cfg.get("resolution",192)
    require(type(resolution)==int and 64<=resolution<=384,"Explicit CPU sampling resolution 64..384")
    # This is a sampling/resource guardrail, not a face-count limit.
    view=cfg.get("view","three-quarter")
    p=inputs["reference_ready"][view+".png"]
    with Image.open(p) as original:im=original.convert("RGBA")
    box=im.getchannel("A").getbbox();require(box is not None,"Empty reference")
    im=im.crop(box);size=max(im.size);side=int(np.ceil(size/.86))
    bg=Image.new("RGBA",(side,side),(128,128,128,255))
    bg.alpha_composite(im,((side-im.width)//2,(side-im.height)//2))
    image=bg.convert("RGB").resize((512,512),Image.Resampling.LANCZOS)
    image.save(out/"conditioning.png")
    # Reuse only the pinned model loader and field query, not rabbit-specific
    # conditioning, alignment, component pruning, UV or polish functions.
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
    import rabbit_neural_inference as legacy
    torch.set_num_threads(min(2,os.cpu_count() or 1));torch.set_num_interop_threads(1)
    start=time.monotonic()
    with tempfile.TemporaryDirectory(prefix="creature-next-triposr-") as tmp:
        copy=Path(tmp)/"upstream";shutil.copytree(upstream,copy,ignore=shutil.ignore_patterns(".git"))
        model=legacy.load_model(copy)
        with torch.inference_mode():latent=model([image],device="cpu")[0]
        radius=float(model.renderer.cfg.radius);axis=np.linspace(-radius,radius,resolution,dtype=np.float32)
        step=2*radius/(resolution-1);field=np.empty((resolution,)*3,np.float32)
        for i in range(0,resolution,2):
            x,y,z=np.meshgrid(axis[i:i+2],axis,axis,indexing="ij")
            pts=np.stack([x,y,z],-1).reshape(-1,3)
            field[i:i+2]=legacy.query(model,latent,pts,"density_act").reshape(x.shape)
            if i%24==0:print("density slab",i,"/",resolution,flush=True)
        require(np.isfinite(field).all() and field.min()<25<field.max(),"No valid density isosurface")
        v,f,_,_=marching_cubes(field,level=25,spacing=(step,)*3,allow_degenerate=False)
        v=(v-radius).astype(np.float32);f=f.astype(np.int32)
    # Preserve every learned component. Fix face orientation, not topology.
    mesh=trimesh.Trimesh(vertices=v,faces=f,process=False);mesh.fix_normals()
    f=np.asarray(mesh.faces,dtype=np.int32)
    stats=inspect_mesh(v,f)
    np.savez_compressed(out/"master.npz",vertices=v,faces=f)
    mesh.export(out/"master.glb")
    require(glb_metadata(out/"master.glb")["triangles"]==len(f),"Export changed face count")
    write_json(out/"geometry.json",asdict(GeometryArtifact("master.glb",sha256(out/"master.glb"),"unit",len(v),len(f))))
    write_json(out/"candidate.json",{"schema":1,"status":"experimental_master_candidate","asset_id":m.asset_id,"fresh_inference":True,"source_view":view,"reference_sha256":sha256(p),"model":{"code_revision":CODE_REV,"checkpoint_revision":legacy.MODEL_REV,"checkpoint_sha256":legacy.WEIGHT_SHA,"license":"MIT"},"resolution":resolution,"metrics":stats,"seconds":time.monotonic()-start,"frame":"TripoSR native normalized frame, not calibrated to manifest axes/units","components_preserved":True,"artistic_approval":False,"publication_allowed":False,"limitations":["Single-image hypothesis. No multiview fusion, metric calibration or verified anatomical counts.","Master has no UV or rig; all surface components retained."]})
    return {"triangles":len(f),"vertices":len(v),"scope":"fresh experimental master, native frame"}
