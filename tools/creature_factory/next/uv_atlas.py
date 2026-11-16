"""C5-A UV candidate generation with geometry preservation and sampled overlap gates."""
from pathlib import Path
import numpy as np
from .contracts import require
from .audit import write_json,glb_metadata,sha256

PROFILES=(("default",{}),("balanced",{"max_cost":4.,"max_iterations":2,"normal_deviation_weight":1.2,"straightness_weight":4.,"normal_seam_weight":2.}),("fewer_charts",{"max_cost":6.,"max_iterations":2,"normal_deviation_weight":.7,"straightness_weight":2.5,"normal_seam_weight":1.}))
def weighted_quantile(x,w,q):
    order=np.argsort(x);x=x[order];w=w[order];c=np.cumsum(w);return float(x[min(np.searchsorted(c,q*c[-1]),len(x)-1)])
def metrics(v,f,vm,ix,uv,resolution=1024):
    import trimesh
    require(vm.ndim==1 and ix.shape==f.shape and uv.shape==(len(vm),2),"Atlas dimensions")
    require(np.isfinite(uv).all() and ix.min()>=0 and ix.max()<len(vm) and vm.min()>=0 and vm.max()<len(v),"Invalid UV indices")
    # Xatlas can reorder faces; verify exact oriented vertex triples by
    # canonical cyclic rotation, not merely triangle count.
    def canonical(a):
        j=np.argmin(a,axis=1);return a[np.arange(len(a))[:,None],(j[:,None]+np.arange(3))%3]
    a=canonical(vm[ix]);b=canonical(f)
    aa=a[np.lexsort(a.T[::-1])];bb=b[np.lexsort(b.T[::-1])]
    require(np.array_equal(aa,bb),"UV changed source topology/winding")
    require(uv.min()>=-1e-6 and uv.max()<=1+1e-6,"UV outside unit square")
    tri=v[vm[ix]];q=uv[ix];e=tri[:,1]-tri[:,0];g=tri[:,2]-tri[:,0];l=np.linalg.norm(e,axis=1);area3=np.linalg.norm(np.cross(e,g),axis=1)*.5
    du=q[:,1]-q[:,0];dv=q[:,2]-q[:,0];area2=abs(du[:,0]*dv[:,1]-du[:,1]*dv[:,0])*.5
    valid=area3>1e-12;good=valid&(area2>1e-14)&(l>1e-10)
    require(good.any(),"No nondegenerate UV faces")
    # Local 3D tangent frame -> UV Jacobian, singular-value stretch.
    gx=(e*g).sum(1)/np.maximum(l,1e-12);gy=2*area3/np.maximum(l,1e-12)
    J=np.empty((good.sum(),2,2));J[:,:,0]=du[good]/l[good,None];J[:,:,1]=(dv[good]-gx[good,None]*J[:,:,0])/gy[good,None]
    sv=np.linalg.svd(J,compute_uv=False);stretch=sv[:,0]/np.maximum(sv[:,1],1e-15);density=area2[good]/area3[good]
    adj=trimesh.graph.face_adjacency(faces=ix)
    comps=trimesh.graph.connected_components(adj,nodes=np.arange(len(ix)),min_len=1)
    chart_ids=np.zeros(len(ix),np.int32)
    for i,c in enumerate(comps):chart_ids[c]=i
    counts=np.array([len(c) for c in comps]);areas=np.array([area3[c].sum() for c in comps])
    # Strict interior sample raster; shared edges are not overlapping faces.
    # This is a finite-resolution overlap test, not exact continuous proof.
    counter=np.zeros((resolution,resolution),np.uint16);q=q*resolution
    for t in q:
        lo=np.maximum(np.floor(t.min(0)).astype(int),0);hi=np.minimum(np.ceil(t.max(0)).astype(int),resolution-1)
        a,b,c=t;d=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(d)<1e-12 or (hi<lo).any():continue
        yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];x=xx+.5;y=yy+.5
        w0=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/d
        w1=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/d;w2=1-w0-w1
        hit=(w0>1e-5)&(w1>1e-5)&(w2>1e-5)
        counter[yy[hit],xx[hit]]+=1
    filled=counter>0;overlap=int((counter>1).sum());w=area3[good]
    report={"charts":len(comps),"tiny_charts_lt4_faces":int((counts<4).sum()),"largest_chart_area_fraction":float(areas.max()/areas.sum()),"uv_vertices":len(vm),"triangles":len(ix),"degenerate_nonzero_geometry_faces":int((valid&~good).sum()),"source_near_zero_faces":int((~valid).sum()),"coverage":float(filled.mean()),"overlap_pixels":overlap,"overlap_fraction":float(overlap/max(1,filled.sum())),"validation_resolution":resolution,"stretch_p95":weighted_quantile(stretch,w,.95),"density_p95_p05":weighted_quantile(density,w,.95)/max(weighted_quantile(density,w,.05),1e-15)}
    return report,chart_ids

def unwrap(v,f,out,resolution=2048):
    import xatlas,trimesh
    from PIL import Image,ImageDraw
    require(type(resolution)==int and resolution in (1024,2048,4096),"Supported UV resolution")
    v=np.asarray(v,np.float64);f=np.asarray(f,np.int32);attempts=[];accepted=[]
    for name,opts in PROFILES:
        try:
            atlas=xatlas.Atlas();atlas.add_mesh(np.ascontiguousarray(v,np.float32),np.ascontiguousarray(f,np.uint32))
            chart=xatlas.ChartOptions()
            for k,x in opts.items():setattr(chart,k,x)
            pack=xatlas.PackOptions();pack.resolution=resolution;pack.padding=8;pack.bilinear=True
            atlas.generate(chart_options=chart,pack_options=pack)
            require(atlas.atlas_count==1,"Multi-atlas candidate not supported")
            vm,ix,uv=atlas[0];vm=np.asarray(vm,dtype=np.int32);ix=np.asarray(ix,dtype=np.int32);uv=np.asarray(uv,dtype=np.float64)
            r,ids=metrics(v,f,vm,ix,uv,1024)
            failures=[]
            if r["degenerate_nonzero_geometry_faces"]:failures.append("degenerate_uv")
            if r["overlap_fraction"]>.0001:failures.append("sampled_overlap")
            if r["coverage"]<.20:failures.append("packing_coverage")
            if r["stretch_p95"]>8:failures.append("stretch")
            if r["density_p95_p05"]>12:failures.append("texel_density")
            r.update(profile=name,options=opts,passed=not failures,failed_metrics=failures)
            attempts.append(r)
            if r["passed"]:accepted.append((r["charts"]+2*r["tiny_charts_lt4_faces"],r["stretch_p95"],vm,ix,uv,ids,r))
        except (ValueError,RuntimeError) as exc:attempts.append({"profile":name,"passed":False,"reason":str(exc)})
    write_json(out/"uv-attempts.json",{"schema":1,"attempts":attempts})
    require(bool(accepted),"No UV candidate passed; attempts preserved")
    _,_,vm,ix,uv,ids,r=min(accepted,key=lambda x:x[:2])
    np.savez_compressed(out/"uv.npz",vertex_map=vm,faces=ix,uv=uv,chart_ids=ids)
    # Actual texture-space layout, no generated artistic albedo.
    layout=Image.new("RGBA",(resolution,resolution),(255,255,255,0));draw=ImageDraw.Draw(layout)
    xy=uv*np.array([resolution-1,-(resolution-1)])+np.array([0,resolution-1])
    for face,chart_id in zip(ix,ids):
        col=(40+(int(chart_id)*53)%150,40+(int(chart_id)*97)%150,40+(int(chart_id)*139)%150,220)
        draw.line([tuple(x) for x in xy[np.r_[face,face[0]]]],fill=col,width=1)
    layout.save(out/"uv-layout.png")
    yy,xx=np.indices((512,512));check=((xx//32+yy//32)%2).astype(np.uint8)
    colors=np.where(check[...,None]>0,np.array([220,225,230]),np.array([105,120,135])).astype(np.uint8);image=Image.fromarray(colors)
    image.save(out/"checker.png")
    # Source world Z-up -> GLB Y-up. UV unchanged, seam duplication explicit.
    positions=v[vm][:,[0,2,1]].copy();positions[:,2]*=-1
    visual=trimesh.visual.texture.TextureVisuals(uv=uv,image=image)
    mesh=trimesh.Trimesh(vertices=positions,faces=ix,visual=visual,process=False);mesh.export(out/"uv-review.glb")
    require(glb_metadata(out/"uv-review.glb")["triangles"]==len(f),"UV export triangle count changed")
    result={"schema":1,"status":"uv_candidate_validated","selected":r,"attempts":attempts,"glb_sha256":sha256(out/"uv-review.glb"),"layout_resolution":resolution,"artistic_texture_ready":False,"rigged":False,"limitations":["Sampled overlap and distortion validation; not an exact continuous overlap proof.","UV chart optimization is not anatomy-aware seam placement.","Checker only; final painted texture is not generated."]}
    write_json(out/"uv-report.json",result);return result
