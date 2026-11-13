"""Layered orthographic visual hull. All masks share one calibrated cube."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, gaussian_filter
from skimage.measure import marching_cubes

def field(masks):
    if set(masks)!={"front","right","top"}: raise ValueError("three calibrated views required per layer")
    a=[np.asarray(masks[k],bool) for k in ("front","right","top")]
    n=a[0].shape[0]
    if not 16<=n<=256 or any(x.shape!=(n,n) or not x.any() or x.all() for x in a): raise ValueError("invalid masks")
    f,r,t=[(distance_transform_edt(x)-distance_transform_edt(~x))[::-1,:].T for x in a]
    return np.minimum(np.minimum(f[:,None,:],r[None,:,:]),t[:,:,None])

def compose(layers,sigma=.65):
    if not layers or layers[0][0]!="union": raise ValueError("first layer must be union")
    result=None
    for op,masks in layers:
        v=field(masks)
        if result is not None and v.shape!=result.shape: raise ValueError("layer grids differ")
        if op=="union": result=v if result is None else np.maximum(result,v)
        elif op=="subtract": result=np.minimum(result,-v)
        else: raise ValueError("unknown operation")
    if not np.isfinite(sigma) or not 0<=sigma<=2: raise ValueError("invalid smoothing")
    result=gaussian_filter(result,sigma)
    if not (result>0).any(): raise ValueError("empty composite")
    n=result.shape[0]
    verts,faces,_,_=marching_cubes(np.pad(result,1,constant_values=-2),0,gradient_direction="ascent")
    return ((verts-.5)/n*2-1),faces

def main():
    p=argparse.ArgumentParser();p.add_argument("--job",type=Path,required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    d=json.loads(a.job.read_text())
    if d.get("schema")!=1 or d.get("mode")!="layered_multi_view": raise ValueError("invalid layered job")
    root=a.job.parent.resolve(); layers=[]
    for layer in d["layers"]:
        masks={}
        for k,name in layer["references"].items():
            q=(root/name).resolve()
            if not q.is_relative_to(root): raise ValueError("reference escapes job directory")
            with Image.open(q) as im: masks[k]=np.asarray(im.convert("L"))>=128
        layers.append((layer["operation"],masks))
    v,f=compose(layers,d.get("sigma",.65))
    budget=d["triangle_budget"]
    if not isinstance(budget,int) or not 1<=budget<=100000 or len(f)>budget: raise ValueError("triangle budget exceeded")
    a.out.mkdir(parents=True,exist_ok=True)
    with (a.out/"geometry.obj").open("w") as o:
        for x,y,z in v:o.write(f"v {x} {y} {z}\n")
        for i,j,k in f:o.write(f"f {i+1} {j+1} {k+1}\n")
    (a.out/"report.json").write_text(json.dumps({"state":"geometry_ready","triangles":len(f),"vertices":len(v),"layers":len(layers),"uv":False},indent=2))
if __name__=="__main__":main()
