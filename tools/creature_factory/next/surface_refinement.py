"""C4-B bounded Taubin smoothing with rollback on measured quality loss."""
import numpy as np
from .contracts import require
from .mesh_optimization import prepare,measure,DEFAULT_LIMITS
from .rigid_alignment import render_mask,iou,resized

def smooth_vertices(v,f,iterations,max_displacement):
    from scipy.sparse import coo_matrix,diags
    v=np.asarray(v,np.float64);edges=np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]);edges=np.unique(np.sort(edges,axis=1),axis=0)
    a=np.r_[edges[:,0],edges[:,1]];b=np.r_[edges[:,1],edges[:,0]]
    A=coo_matrix((np.ones(len(a)),(a,b)),shape=(len(v),len(v))).tocsr()
    W=diags(1/np.maximum(np.asarray(A.sum(1)).ravel(),1))@A
    q=v.copy()
    for _ in range(iterations):
        for factor in (.5,-.53):
            q+=factor*(W@q-q)
            delta=q-v;norm=np.linalg.norm(delta,axis=1);q=v+delta*np.minimum(1,max_displacement/np.maximum(norm,1e-15))[:,None]
    return q

def roughness(v,f):
    import trimesh
    m=trimesh.Trimesh(vertices=v,faces=f,process=False)
    a=m.face_adjacency_angles
    return float(np.degrees(a.mean())) if len(a) else 0.

def refine(v,f,views=None,iterations=(4,8,16)):
    v=np.asarray(v,np.float64);f=np.asarray(f,np.int32);p=prepare(v,f,sample_count=4000,resolution=160)
    diag=p["diag"];original=roughness(v,f);best=v.copy();best_r=original;attempts=[]
    limits={**DEFAULT_LIMITS,"mean_distance":.003,"p95_distance":.007,"max_distance":.018,"normal_mean_deg":25.,"normal_p95_deg":65.,"silhouette_min_iou":.98,"area_relative":.06,"protected_max_distance":.012}
    vs=resized(views,160) if views else {}
    def refscore(x):return {k:iou(render_mask(x,f,c,m.shape),m) for k,(m,c) in vs.items()}
    baseline=refscore(v)
    for n in iterations:
        q=smooth_vertices(v,f,n,.012*diag)
        # Reject inverted or collapsed faces, not just edge connectivity.
        x=v[f];y=q[f];nx=np.cross(x[:,1]-x[:,0],x[:,2]-x[:,0]);ny=np.cross(y[:,1]-y[:,0],y[:,2]-y[:,0])
        valid=np.linalg.norm(nx,axis=1)>1e-10
        if np.any((nx[valid]*ny[valid]).sum(1)<=0):
            attempts.append({"iterations":n,"passed":False,"reason":"face_flip_or_collapse"});continue
        r=measure(p,q,f,limits);r["iterations"]=n;r["roughness_deg"]=roughness(q,f);r["reference_iou"]=refscore(q)
        if any(r["reference_iou"][k]<baseline[k]-.012 for k in baseline):r["passed"]=False;r["reason"]="reference_silhouette_regression"
        attempts.append(r)
        if r["passed"] and r["roughness_deg"]<best_r*.98:best=q;best_r=r["roughness_deg"]
    return best,f.copy(),{"schema":1,"status":"bounded_refinement_accepted" if best_r<original else "original_retained","roughness_before_deg":original,"roughness_after_deg":best_r,"attempts":attempts,"limits":limits,"geometry_artistic_approval":False}
