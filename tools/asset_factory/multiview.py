"""Orthographic silhouette intersection; coordinates x right, y depth, z up.
Masks are aligned square images, white foreground, black background.
"""
import numpy as np
def reconstruct(masks):
    if set(masks)!={"front","right","top"}: raise ValueError("three aligned orthographic masks required")
    f,r,t=(np.asarray(masks[k],dtype=bool) for k in ("front","right","top"))
    if f.ndim!=2 or f.shape!=r.shape or f.shape!=t.shape or f.shape[0]!=f.shape[1]: raise ValueError("square matching masks")
    # Array axes x,y,z. Image rows run from high to low.
    v=f[::-1,:].T[:,None,:] & r[::-1,:].T[None,:,:] & t[::-1,:].T[:,:,None]
    if not v.any(): raise ValueError("empty intersection")
    return v
def projections(v):
    return {"front":v.any(axis=1).T[::-1,:],"right":v.any(axis=0).T[::-1,:],"top":v.any(axis=2).T[::-1,:]}
def iou(a,b):
    u=np.logical_or(a,b).sum()
    return float(np.logical_and(a,b).sum()/u) if u else 1.
def surface(v):
    verts=[];faces=[];lookup={}
    directions=[((-1,0,0),[(0,0,0),(0,0,1),(0,1,1),(0,1,0)]),((1,0,0),[(1,0,0),(1,1,0),(1,1,1),(1,0,1)]),((0,-1,0),[(0,0,0),(1,0,0),(1,0,1),(0,0,1)]),((0,1,0),[(0,1,0),(0,1,1),(1,1,1),(1,1,0)]),((0,0,-1),[(0,0,0),(0,1,0),(1,1,0),(1,0,0)]),((0,0,1),[(0,0,1),(1,0,1),(1,1,1),(0,1,1)])]
    n=v.shape[0]
    for p in np.argwhere(v):
        for d,corners in directions:
            q=p+np.array(d)
            if np.all(q>=0) and np.all(q<n) and v[tuple(q)]:continue
            face=[]
            for c in corners:
                k=tuple(int(x) for x in p+np.array(c))
                if k not in lookup:lookup[k]=len(verts);verts.append(tuple((x/n-.5)*2 for x in k))
                face.append(lookup[k])
            faces.append(face)
    return verts,faces
