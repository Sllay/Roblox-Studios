"""Reference-conditioned neural reconstruction. CPU-only, private runner.
No remote inference and no upload of concept images to any model provider.
Source and checkpoint are pinned; only public model files are downloaded.
"""
import argparse, hashlib, json, os, sys, time, gc, subprocess, tempfile
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
from skimage.measure import marching_cubes
import cv2
import torch
import trimesh
import xatlas
import fast_simplification
from huggingface_hub import hf_hub_download
from omegaconf import OmegaConf
from rabbit_organic_reference import panel_data, checked, REF, HEIGHT
CODE_REV="107cefdc244c39106fa830359024f6a2f1c78871"
MODEL_REV="c1cf7716aed5aa6c1c5e174657791ef0e1327bde"
WEIGHT_SHA="429e2c6b22a0923967459de24d67f05962b235f79cde6b032aa7ed2ffcd970ee"
CONFIG_SHA="74ca708ce086bf68e97709ea6b3d91f14717921c04691e84043f0eb8fcc68e62"
MODEL="stabilityai/TripoSR"
def digest(p):
    h=hashlib.sha256()
    with open(p,"rb") as f:
        for block in iter(lambda:f.read(1024*1024),b""):h.update(block)
    return h.hexdigest()
def prepare(out):
    manifest=checked();img=Image.open(REF/"hero.png").convert("RGBA")
    a=np.array(img);rgb=a[:,:,:3].copy();alpha=a[:,:,3]
    y,x=np.ogrid[-3:4,-3:4];mask=ndi.binary_opening(alpha>110,structure=x*x+y*y<=9)
    mask=ndi.binary_fill_holes(ndi.binary_closing(mask,iterations=2))
    labels,n=ndi.label(mask);sizes=np.bincount(labels.ravel());sizes[0]=0
    assert n and sizes.max()>100000
    mask=labels==sizes.argmax()
    # Remove thin illustrated whisker strokes from the conditioning image.
    # Their final six closed 3D strands are authored separately after inference.
    strokes=[[(790,456),(718,451),(640,462)],[(790,465),(720,472),(650,505)],
             [(795,470),(744,491),(690,535)],[(880,440),(916,432),(953,435)],
             [(880,455),(918,460),(940,478)],[(880,465),(916,488),(930,520)]]
    ink=np.zeros(mask.shape,np.uint8)
    for line in strokes:
        q=np.array([(round(px*a.shape[1]/1280),round(py*a.shape[0]/1169)) for px,py in line],np.int32)
        cv2.polylines(ink,[q],False,255,5,cv2.LINE_AA)
    ink[~mask]=0
    rgb=cv2.inpaint(rgb,ink,4,cv2.INPAINT_TELEA)
    yy,xx=np.where(mask);box=(xx.min(),yy.min(),xx.max()+1,yy.max()+1)
    rgba=np.dstack([rgb,np.where(ndi.binary_dilation(mask,iterations=1),alpha,0).astype(np.uint8)])
    fg=Image.fromarray(rgba).crop(box)
    canvas=Image.new("RGBA",(max(fg.size),)*2,(128,128,128,0))
    canvas.alpha_composite(fg,((canvas.width-fg.width)//2,(canvas.height-fg.height)//2))
    n=int(round(canvas.width/.86))
    back=Image.new("RGBA",(n,n),(128,128,128,255))
    back.alpha_composite(canvas,((n-canvas.width)//2,(n-canvas.height)//2))
    im=back.convert("RGB").resize((512,512),Image.Resampling.LANCZOS)
    im.save(out/"conditioning.png")
    return im,manifest
def load_model(upstream):
    # Explicit, reviewed CPU backend for upstream's optional compiled extension.
    target=upstream/"tsr/models/isosurface.py"
    s=target.read_text()
    old="from torchmcubes import marching_cubes"
    assert old in s
    target.write_text(s.replace(old,"from tsr_cpu_marching_cubes import marching_cubes",1))
    sys.path.insert(0,str(upstream))
    from tsr.system import TSR
    config=Path(hf_hub_download(MODEL,"config.yaml",revision=MODEL_REV))
    ckpt=Path(hf_hub_download(MODEL,"model.ckpt",revision=MODEL_REV))
    assert digest(config)==CONFIG_SHA,"config hash mismatch"
    assert digest(ckpt)==WEIGHT_SHA,"checkpoint hash mismatch"
    cfg=OmegaConf.load(config);OmegaConf.resolve(cfg)
    model=TSR(cfg)
    try:weights=torch.load(ckpt,map_location="cpu",weights_only=True,mmap=True)
    except RuntimeError as e:
        if "mmap" not in str(e).lower():raise
        weights=torch.load(ckpt,map_location="cpu",weights_only=True)
    model.load_state_dict(weights,strict=True,assign=True)
    del weights;gc.collect()
    model.eval();model.renderer.set_chunk_size(8192)
    return model
def query(model,code,p,key):
    with torch.inference_mode():
        t=torch.from_numpy(np.ascontiguousarray(p,dtype=np.float32))
        return model.renderer.query_triplane(model.decoder,t,code)[key].detach().cpu().numpy()
def extract(model,code,res):
    radius=float(model.renderer.cfg.radius)
    ax=np.linspace(-radius,radius,res,dtype=np.float32);step=2*radius/(res-1)
    field=np.empty((res,res,res),np.float32)
    for i in range(0,res,3):
        x,y,z=np.meshgrid(ax[i:i+3],ax,ax,indexing="ij")
        p=np.stack([x,y,z],axis=-1).reshape(-1,3)
        field[i:i+3]=query(model,code,p,"density_act").reshape(x.shape)
        if i%24==0:print("density slab",i,"/",res,flush=True)
    assert field.min()<25<field.max(),(field.min(),field.max())
    v,f,_,_=marching_cubes(field,level=25,spacing=(step,)*3,allow_degenerate=False)
    v=v-radius
    mesh=trimesh.Trimesh(vertices=v,faces=f,process=True)
    comps=mesh.split(only_watertight=False)
    assert len(comps)
    # Preserve the dominant connected anatomical surface; log removed area.
    comps=sorted(comps,key=lambda m:m.area,reverse=True)
    main=comps[0];ratio=float(main.area/sum(m.area for m in comps))
    assert ratio>.9,("Unexpected disconnected anatomy",ratio)
    main.fix_normals()
    assert main.is_watertight,"Neural master has open boundary"
    return main,{"connectedComponents":len(comps),"retainedAreaFraction":ratio}
def valid_reduction(master,m):
    if not len(m.faces) or not m.is_watertight or not m.is_winding_consistent:
        return False
    if m.euler_number!=master.euler_number or len(m.split(only_watertight=False))!=1:
        return False
    return .95<=float(m.area/master.area)<=1.05

def simplify(master,target):
    # Blender's collapse decimator is a separate implementation. Never accept
    # topology damage, or close arbitrary holes after an unsafe reduction.
    with tempfile.TemporaryDirectory(prefix="rabbit-decimate-") as tmp:
        tmp=Path(tmp); src=tmp/"source.npz"; dst=tmp/"result.npz"
        np.savez(src,vertices=np.asarray(master.vertices),faces=np.asarray(master.faces))
        script=Path(__file__).with_name("rabbit_neural_decimate.py")
        proc=subprocess.run(["blender","-b","--factory-startup","--python-exit-code","1",
            "--python",str(script),"--",str(src),str(dst),str(target)],
            check=True,capture_output=True,text=True)
        if not dst.exists():raise RuntimeError(proc.stdout[-3000:]+proc.stderr[-3000:])
        data=np.load(dst)
        m=trimesh.Trimesh(vertices=data["vertices"],faces=data["faces"],process=False)
        m.fix_normals()
        if valid_reduction(master,m):return m,"blender_collapse"
    # Alternative backend: accept only if independent topology checks pass.
    v,f=fast_simplification.simplify(np.ascontiguousarray(master.vertices,dtype=np.float64),np.ascontiguousarray(master.faces,dtype=np.int32),target_count=min(target,len(master.faces)))
    m=trimesh.Trimesh(vertices=v,faces=f,process=False);m.fix_normals()
    if valid_reduction(master,m):return m,"fast_simplification"
    raise ValueError("No topology-preserving reduction at target "+str(target))

def atlas_mesh(mesh,res):
    a=xatlas.Atlas();a.add_mesh(np.asarray(mesh.vertices,np.float32),np.asarray(mesh.faces,np.uint32))
    options=xatlas.PackOptions();options.resolution=res;options.padding=8;options.bilinear=True
    a.generate(pack_options=options)
    vm,ix,uv=a[0]
    return np.asarray(vm),np.asarray(ix),np.asarray(uv)
def position_atlas(v,f,uv,size):
    xyz=np.zeros((size,size,3),np.float32);filled=np.zeros((size,size),bool)
    uv=uv*(size-1)
    for face in f:
        q=uv[face];p=v[face]
        lo=np.maximum(np.floor(q.min(0)).astype(int),0);hi=np.minimum(np.ceil(q.max(0)).astype(int),size-1)
        if np.any(hi<lo):continue
        x,y=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1))
        a,b,c=q;d=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(d)<1e-8:continue
        w0=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/d
        w1=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/d
        w2=1-w0-w1;mask=(w0>=-.001)&(w1>=-.001)&(w2>=-.001)
        if not mask.any():continue
        w=np.stack([w0[mask],w1[mask],w2[mask]],axis=1)
        xyz[y[mask],x[mask]]=w@p;filled[y[mask],x[mask]]=True
    return xyz,filled
def bake(model,code,mesh,vm,ix,uv,out,size):
    pos,mask=position_atlas(mesh.vertices[vm],ix,uv,size)
    coverage=float(mask.mean());assert coverage>.08
    p=pos[mask];rgb=np.empty_like(p)
    for i in range(0,len(p),65536):
        rgb[i:i+65536]=query(model,code,p[i:i+65536],"color")
    img=np.zeros((size,size,3),np.uint8);img[mask]=np.rint(np.clip(rgb,0,1)*255).astype(np.uint8)
    # Nearest-chart gutter, applied only to the unoccupied region within 8 px.
    dist,near=ndi.distance_transform_edt(~mask,return_indices=True)
    fill=(~mask)&(dist<=8);img[fill]=img[near[0][fill],near[1][fill]]
    Image.fromarray(img[::-1]).save(out/"neural-albedo.png")
    return coverage
def transform(v,yaw):
    a=np.deg2rad(yaw);r=np.array([[np.cos(a),-np.sin(a),0],[np.sin(a),np.cos(a),0],[0,0,1]])
    p=v@r.T;lo=p.min(0);hi=p.max(0);center=np.array([(lo[0]+hi[0])/2,(lo[1]+hi[1])/2,lo[2]])
    scale=HEIGHT/(hi[2]-lo[2])
    return (p-center)*scale,r,center,scale
def score(p,f,masks,maps,k):
    a=maps[k];u=a["center"]+a["sign"]*p[:,a["axis"]]/a["scale"]
    q=np.column_stack([u,a["bottom"]-p[:,2]/a["scale"]])*.5
    im=Image.new("1",(125,238));dr=ImageDraw.Draw(im)
    for t in f:dr.polygon([tuple(x) for x in q[t]],fill=1)
    pred=np.asarray(im,dtype=bool)
    ref=np.asarray(Image.fromarray(masks[k].astype(np.uint8)*255).resize((125,238),Image.Resampling.NEAREST))>0
    return float((pred&ref).sum()/max(1,(pred|ref).sum()))
def align(mesh,master):
    masks,_,maps,_=panel_data()
    # TripoSR's input camera is +X; the approved hero faces image-right.
    # Optimize within that orientation family against the real front and profiles.
    candidates=[]
    for yaw in range(-160,-94,5):
        p,r,c,s=transform(mesh.vertices,yaw)
        scores={k:score(p,mesh.faces,masks,maps,k) for k in ("front","right","left","back")}
        total=.35*scores["front"]+.25*scores["right"]+.25*scores["left"]+.15*scores["back"]-.0005*abs(yaw+130)
        candidates.append((total,yaw,scores))
    _,yaw,metrics=max(candidates,key=lambda x:x[0])
    p,r,c,s=transform(mesh.vertices,yaw)
    master_p=(master.vertices@r.T-c)*s
    return p,master_p,{"yawDegrees":yaw,"scale":s,"referenceAlignmentIoU":metrics}
def main():
    p=argparse.ArgumentParser();p.add_argument("--upstream",type=Path,required=True);p.add_argument("--out",type=Path,required=True);p.add_argument("--resolution",type=int,default=192)
    args=p.parse_args();out=args.out;out.mkdir(parents=True,exist_ok=True)
    torch.set_num_threads(min(4,os.cpu_count() or 2));torch.set_num_interop_threads(1)
    start=time.monotonic();im,manifest=prepare(out)
    print("loading pinned neural model",flush=True);model=load_model(args.upstream)
    print("infer hero image on CPU",flush=True)
    with torch.inference_mode():code=model([im],device="cpu")[0]
    print("extracting learned surface",flush=True);master,topology=extract(model,code,args.resolution)
    print("master",len(master.vertices),len(master.faces),topology,flush=True)
    # Retain the original learned geometry even if later stages fail.
    master.export(out/"neural-master.ply")
    chosen=None
    for target in (32000,30000,27000,24000,21000,18000):
        try:
            mesh,method=simplify(master,target);vm,ix,uv=atlas_mesh(mesh,2048)
        except (ValueError,RuntimeError,subprocess.CalledProcessError) as e:
            print("reduction rejected",target,str(e),flush=True);continue
        print("reduction",method,target,"vertices",len(mesh.vertices),"UV vertices",len(vm),flush=True)
        if len(vm)<=18200:
            chosen=method;break
    assert chosen is not None,"No valid watertight mesh within exported vertex budget"
    topology["reductionMethod"]=chosen
    topology["masterEuler"]=int(master.euler_number)
    topology["runtimeEuler"]=int(mesh.euler_number)
    topology["runtimeWatertight"]=bool(mesh.is_watertight)
    print("baking learned field into UV",len(vm),flush=True)
    coverage=bake(model,code,mesh,vm,ix,uv,out,2048)
    world,master_world,orientation=align(mesh,master)
    # xatlas face indices map back to the same unsplit topology.
    f=vm[ix].astype(np.int32)
    np.savez_compressed(out/"neural-mesh.npz",vertices=world.astype(np.float32),faces=f,
      loop_uv=uv[ix].astype(np.float32),master_vertices=master_world.astype(np.float32),master_faces=master.faces.astype(np.int32))
    np.savez_compressed(out/"runtime-mesh.npz",vertices=world.astype(np.float32),faces=f)
    report={"schema":3,"id":"rabbit-v3","category":"creature","state":"neural_geometry_candidate",
      "backend":"TripoSR CPU, learned triplane density and color","model":{"repo":"VAST-AI-Research/TripoSR","codeRevision":CODE_REV,"checkpoint":MODEL,"checkpointRevision":MODEL_REV,"checkpointSHA256":WEIGHT_SHA,"license":"MIT"},
      "sourceReferences":manifest["references"],"conditioning":"approved hero, isolated silhouette, whisker strokes removed",
      "masterVertices":len(master.vertices),"masterTriangles":len(master.faces),"bodyVertices":len(mesh.vertices),
      "bodyTriangles":len(mesh.faces),"atlasVertices":len(vm),"atlasSize":2048,"atlasCoverage":coverage,
      "orientation":orientation,"topology":topology,"elapsedCPUSeconds":round(time.monotonic()-start,2),
      "artisticApproval":False,"robloxPublished":False,"rigged":False,
      "limitations":["Single-image neural inference estimates hidden anatomy; compare all original multiview references.","Neural colors are candidate albedo, not final material or painted correction.","Runtime reduction is not final animation retopology."]}
    (out/"neural-report.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report),flush=True)
if __name__=="__main__":main()
