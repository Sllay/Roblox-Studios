"""Remove only microscopic marching-cubes faces, with an edge-link check."""
import numpy as np

def mesh_stats(v, f):
    e = np.sort(np.concatenate([f[:, [0, 1]], f[:, [1, 2]], f[:, [2, 0]]]), axis=1)
    unique, counts = np.unique(e, axis=0, return_counts=True)
    assert np.all(counts == 2), 'Surface must remain closed and edge-manifold'
    assert len(np.unique(np.sort(f, axis=1), axis=0)) == len(f), 'Duplicate faces'
    return len(np.unique(f)) - len(unique) + len(f)

def areas(v, f):
    p = v[f]
    return np.linalg.norm(np.cross(p[:, 1]-p[:, 0], p[:, 2]-p[:, 0]), axis=1)

def repair(v, f, uv, floor=1e-9):
    v, f, uv = v.astype(np.float64).copy(), f.copy(), uv.copy()
    euler = mesh_stats(v, f)
    extent = float(np.ptp(v, axis=0).max())
    max_edge = extent * 1e-4
    changes = []
    for _ in range(64):
        a = areas(v, f)
        if float(a.min()) > floor:
            break
        face = f[int(a.argmin())]
        pairs = sorted([(float(np.linalg.norm(v[i]-v[j])), int(i), int(j)) for i,j in zip(face,np.roll(face,1))])
        for length, i, j in pairs:
            if length > max_edge:
                continue
            fi = np.any(f==i, axis=1); fj = np.any(f==j, axis=1)
            edge_faces = fi & fj
            if int(edge_faces.sum()) != 2:
                continue
            ni = set(f[fi].ravel())-{i,j}; nj = set(f[fj].ravel())-{i,j}
            opposite = set(f[edge_faces].ravel())-{i,j}
            if ni & nj != opposite or len(opposite)!=2:
                continue
            q = v.copy(); q[i] = (v[i]+v[j])/2
            g = f.copy(); g[g==j]=i
            keep = ~edge_faces
            affected = (fi|fj)&keep
            old = v[f[affected]]; new = q[g[affected]]
            no = np.cross(old[:,1]-old[:,0],old[:,2]-old[:,0]); nn = np.cross(new[:,1]-new[:,0],new[:,2]-new[:,0])
            if np.any(np.sum(no*nn,axis=1)<=0):
                continue
            if mesh_stats(q,g[keep]) != euler:
                continue
            changes.append({'edgeLength':length,'removedFaces':2,'minDoubleAreaBefore':float(a.min())})
            v,f,uv=q,g[keep],uv[keep]
            break
        else:
            raise RuntimeError('No safe local collapse for microscopic face')
    assert float(areas(v,f).min())>floor, 'Microscopic repair not converged'
    used=np.unique(f);remap=np.full(len(v),-1,dtype=np.int32);remap[used]=np.arange(len(used),dtype=np.int32)
    v,f=v[used],remap[f]
    assert mesh_stats(v,f)==euler
    return v.astype(np.float32),f,uv,{'collapses':changes,'removedFaces':2*len(changes),'euler':euler,'minDoubleAreaAfter':float(areas(v,f).min())}
