"""C4-A adaptive mesh reduction with independent surface/normal/topology gates.

All ratios are search probes, not target asset budgets. A failed reduction
never replaces the immutable master. No artistic or runtime approval implied.
"""
from __future__ import annotations
import numpy as np
from .contracts import require,CameraCalibration
from .rigid_alignment import render_mask,iou
from .master_candidate import inspect_mesh

DEFAULT_LIMITS={"mean_distance":.0015,"p95_distance":.0035,"max_distance":.015,"normal_mean_deg":8.,"normal_p95_deg":20.,"silhouette_min_iou":.985,"area_relative":.02,"protected_max_distance":.008}
def mesh_topology(mesh):
    import trimesh
    comps=mesh.split(only_watertight=False)
    return {"components":len(comps),"euler":int(mesh.euler_number),"watertight":bool(mesh.is_watertight),"winding_consistent":bool(mesh.is_winding_consistent),
            "component_signature":sorted([(int(x.euler_number),bool(x.is_watertight)) for x in comps]),"component_area_fractions":sorted([float(x.area/mesh.area) for x in comps]),"area":float(mesh.area)}
def topology_compatible(a,b):
    return (a["components"]==b["components"] and a["euler"]==b["euler"] and a["watertight"]==b["watertight"] and b["winding_consistent"]
      and a["component_signature"]==b["component_signature"] and all(abs(x-y)<=max(.002,.1*x) for x,y in zip(a["component_area_fractions"],b["component_area_fractions"])))
def sample_surface(v,f,count,seed):
    rng=np.random.default_rng(seed);p=v[f];area=np.linalg.norm(np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]),axis=1)
    require(area.sum()>0,"Empty surface area")
    ids=rng.choice(len(f),count,p=area/area.sum());q=p[ids];u=np.sqrt(rng.random(count));b=rng.random(count)
    return q[:,0]*(1-u[:,None])+q[:,1]*(u*(1-b))[:,None]+q[:,2]*(u*b)[:,None],ids
def nearest(mesh,points):
    import trimesh
    q=trimesh.proximity.ProximityQuery(mesh);dist=[];tri=[]
    for i in range(0,len(points),1024):
        _,d,t=q.on_surface(points[i:i+1024]);dist.append(d);tri.append(t)
    return np.concatenate(dist),np.concatenate(tri)
def cameras(v):
    center=(v.min(0)+v.max(0))/2;diag=float(np.linalg.norm(np.ptp(v,axis=0)));result={}
    for name,d in (("front",(0,-1,0)),("back",(0,1,0)),("left",(-1,0,0)),("right",(1,0,0)),("top",(0,0,1)),("bottom",(0,0,-1)),("three-quarter",(-1,-1,.8))):
        b=np.asarray(d,float);b/=np.linalg.norm(b);up=np.array([0,0,1.]) if abs(b[2])<.95 else np.array([0,1.,0]);r=np.cross(up,b);r/=np.linalg.norm(r);u=np.cross(b,r);t=center+b*2*diag
        result[name]=CameraCalibration("known","orthographic",np.column_stack([r,u,b,t]).tolist()+[[0,0,0,1]],diag*1.06,confidence=1)
    return result
def protective_points(mesh,explicit=None):
    v=np.asarray(mesh.vertices);edges=mesh.face_adjacency_edges;angles=mesh.face_adjacency_angles
    ids=np.unique(edges[angles>np.deg2rad(30)])
    if len(ids)>4000:ids=ids[np.linspace(0,len(ids)-1,4000,dtype=int)]
    result=v[ids]
    if explicit is not None:
        e=np.asarray(explicit,float);require(e.ndim==2 and e.shape[1]==3 and np.isfinite(e).all(),"Invalid explicit protected points")
        result=np.concatenate([result,e])
    return result
def prepare(v,f,protected=None,sample_count=8000,resolution=192):
    import trimesh
    v=np.asarray(v,np.float64);f=np.asarray(f,np.int32);mesh=trimesh.Trimesh(vertices=v,faces=f,process=False)
    topology=mesh_topology(mesh);require(topology["watertight"] and topology["winding_consistent"],"Master must be closed and consistently oriented")
    diag=float(np.linalg.norm(np.ptp(v,axis=0)));require(diag>0,"Degenerate master")
    points,ids=sample_surface(v,f,sample_count,17);cams=cameras(v)
    masks={k:render_mask(v,f,c,(resolution,resolution)) for k,c in cams.items()}
    return {"mesh":mesh,"topology":topology,"diag":diag,"points":points,"sample_ids":ids,"protected":protective_points(mesh,protected),"cameras":cams,"masks":masks,"resolution":resolution,"sample_count":sample_count}
def measure(prepared,v,f,limits=None):
    import trimesh
    limits={**DEFAULT_LIMITS,**(limits or {})};require(set(limits)==set(DEFAULT_LIMITS),"Unknown quality limit")
    mesh=trimesh.Trimesh(vertices=v,faces=f,process=False);top=mesh_topology(mesh)
    if not topology_compatible(prepared["topology"],top):return {"passed":False,"reason":"topology_changed","topology":top}
    diag=prepared["diag"];master=prepared["mesh"];area=abs(top["area"]/prepared["topology"]["area"]-1)
    if area>limits["area_relative"]:return {"passed":False,"reason":"surface_area_changed","area_relative":area,"topology":top}
    # Exact point-to-triangle closest distances, with deterministic surface
    # samples in both directions; no point-cloud nearest-sample bias.
    a=prepared["points"];aid=prepared["sample_ids"];b,bid=sample_surface(v,f,prepared["sample_count"],23)
    da,ta=nearest(mesh,a);db,tb=nearest(master,b);dist=np.r_[da,db]/diag
    def angle(n,m):return np.degrees(np.arccos(np.clip((n*m).sum(1),-1,1)))
    normals=np.r_[angle(master.face_normals[aid],mesh.face_normals[ta]),angle(mesh.face_normals[bid],master.face_normals[tb])]
    protected=prepared["protected"];pd=nearest(mesh,protected)[0]/diag if len(protected) else np.zeros(1)
    s={k:iou(prepared["masks"][k],render_mask(v,f,c,(prepared["resolution"],)*2)) for k,c in prepared["cameras"].items()}
    result={"mean_distance":float(dist.mean()),"p95_distance":float(np.percentile(dist,95)),"max_distance":float(dist.max()),
        "normal_mean_deg":float(normals.mean()),"normal_p95_deg":float(np.percentile(normals,95)),"silhouette_min_iou":min(s.values()),"silhouette_iou":s,
        "area_relative":float(area),"protected_max_distance":float(pd.max()),"topology":top}
    failures=[k for k,t in limits.items() if (result[k]<t if k=="silhouette_min_iou" else result[k]>t)]
    return {**result,"passed":not failures,"failed_metrics":failures,"reason":"passed" if not failures else "quality_gate"}
def optimize(v,f,protected=None,limits=None,ratios=(.85,.65,.5,.35,.25,.15,.08),sample_count=8000,resolution=192):
    import fast_simplification,trimesh
    v=np.asarray(v,np.float64);f=np.asarray(f,np.int32);p=prepare(v,f,protected,sample_count,resolution)
    best=(v.copy(),f.copy());attempts=[];best_ratio=1.
    # Every candidate starts from master; errors do not accumulate.
    for ratio in ratios:
        require(0<ratio<1,"Invalid reduction probe")
        target=max(4,int(len(f)*ratio))
        try:
            a,b=fast_simplification.simplify(np.ascontiguousarray(v.copy()),np.ascontiguousarray(f.copy()),target_count=target)
            m=trimesh.Trimesh(vertices=a,faces=b,process=False);m.fix_normals();a=np.asarray(m.vertices);b=np.asarray(m.faces,dtype=np.int32)
            r=measure(p,a,b,limits);r.update(target=target,triangles=len(b),ratio=ratio)
            if r["passed"] and len(b)<len(best[1]):best=(a.copy(),b.copy());best_ratio=ratio
        except (ValueError,RuntimeError) as exc:r={"passed":False,"target":target,"ratio":ratio,"reason":str(exc)}
        attempts.append(r)
    return *best,{"schema":1,"status":"quality_preserving_reduction" if best_ratio<1 else "master_retained","master_triangles":len(f),"selected_triangles":len(best[1]),"reduction_fraction":1-len(best[1])/len(f),"selected_ratio_probe":best_ratio,"attempts":attempts,"limits":{**DEFAULT_LIMITS,**(limits or {})},"surface_samples_per_direction":sample_count,"silhouette_resolution":resolution,"protected_points":len(p["protected"]),"scope":"sampled geometric preservation; not semantic or artistic approval","artistic_approval":False,"publication_allowed":False}
