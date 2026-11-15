"""Extract articulated forelimbs from the approved-for-refinement neural surface.
Surface patches are traced in two orthographic views, clipped on shared mesh
edges, and closed with recessed organic joint surfaces. No primitive limbs.
"""
import numpy as np
from collections import defaultdict

def sdpoly(p,poly):
    poly=np.asarray(poly);d=np.full(len(p),1e9);inside=np.zeros(len(p),bool)
    for a,b in zip(poly,np.roll(poly,-1,axis=0)):
        q=b-a;t=np.clip((p-a)@q/(q@q),0,1)
        d=np.minimum(d,np.linalg.norm(p-a-t[:,None]*q,axis=1))
        inside^=((a[1]>p[:,1])!=(b[1]>p[:,1]))&(p[:,0]<(b[0]-a[0])*(p[:,1]-a[1])/(b[1]-a[1]+1e-12)+a[0])
    return np.where(inside,d,-d)

FRONT=[(518,425),(548,430),(568,467),(586,526),(575,576),(551,600),(534,634),(501,648),(469,640),(463,616),(468,581),(487,555),(505,522),(502,478),(507,446)]
SIDE=[(368,427),(420,419),(455,443),(455,487),(436,527),(411,553),(390,574),(364,609),(351,645),(320,647),(301,621),(305,588),(324,550),(337,508),(344,468)]

def edges(f):
    return np.unique(np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1),axis=0)

def components(mask,e):
    adj=defaultdict(list)
    for i,j in e[mask[e].all(axis=1)]:adj[int(i)].append(int(j));adj[int(j)].append(int(i))
    seen=set();out=[]
    for i in np.flatnonzero(mask):
        i=int(i)
        if i in seen:continue
        stack=[i];seen.add(i);group=[]
        while stack:
            j=stack.pop();group.append(j)
            for k in adj[j]:
                if k not in seen:seen.add(k);stack.append(k)
        out.append(group)
    return sorted(out,key=len,reverse=True)

def arm_field(v,f,sign):
    py=450-(v[:,2]-1.8)*900/4.15
    q=np.minimum(sdpoly(np.c_[450+sign*v[:,0]*900/4.15,py],FRONT),
                 sdpoly(np.c_[450+v[:,1]*900/4.15,py],SIDE))
    e=edges(f)
    for g in components(q>0,e)[1:]:q[g]=-.5
    for g in components(q<=0,e)[1:]:q[g]=.5
    q[np.abs(q)<1e-7]=1e-7
    return q

def clip(v,f,c,q,positive):
    q=q*(1 if positive else -1)
    V=list(v);C=list(c);F=[];cache={}
    def intersection(i,j):
        k=tuple(sorted((int(i),int(j))))
        if k not in cache:
            t=q[i]/(q[i]-q[j]);cache[k]=len(V)
            V.append(v[i]+t*(v[j]-v[i]));C.append(c[i]+t*(c[j]-c[i]))
        return cache[k]
    for face in f:
        ids=[]
        for i,j in zip(face,np.roll(face,-1)):
            if q[i]>0:ids.append(i)
            if (q[i]>0)!=(q[j]>0):ids.append(intersection(i,j))
        for k in range(1,len(ids)-1):F.append([ids[0],ids[k],ids[k+1]])
    F=np.asarray(F,dtype=np.int32);V=np.asarray(V);C=np.asarray(C)
    used,inv=np.unique(F,return_inverse=True);V=V[used];C=C[used];F=inv.reshape(-1,3)
    e=np.sort(np.concatenate([F[:,[0,1]],F[:,[1,2]],F[:,[2,0]]]),axis=1)
    E,count=np.unique(e,axis=0,return_counts=True);bd=E[count==1]
    adj=defaultdict(list)
    for i,j in bd:adj[int(i)].append(int(j));adj[int(j)].append(int(i))
    assert all(len(x)==2 for x in adj.values()),"Non-manifold cut contour"
    loops=[];seen=set()
    for st in adj:
        if st in seen:continue
        L=[st];prev=-1;cur=st
        while True:
            nxt=next(x for x in adj[cur] if x!=prev)
            if nxt==st:break
            L.append(nxt);prev,cur=cur,nxt
            assert len(L)<=len(bd)
        seen.update(L);loops.append(L)
    return V,F,C,loops

def fill_patch(p,colors,limb):
    """Constrained planar triangulation and harmonic curved surface.
    
    The cut boundary stays exactly on the source mesh. The interior is a
    two-dimensional grid, not concentric rings collapsing to a central fan.
    Project onto a local tangent plane, triangulate the actual nonconvex
    contour, and recover its third coordinate and colors harmonically.
    """
    from mathutils import Vector
    from mathutils.geometry import delaunay_2d_cdt
    n=len(p);origin=p.mean(axis=0)
    _,_,basis=np.linalg.svd(p-origin,full_matrices=False)
    normal=basis[2].copy()
    outward=np.array([np.sign(origin[0]),-1.,0.])
    if normal@outward<0:normal=-normal
    q=(p-origin)@basis[:2].T
    h=(p-origin)@normal
    spacing=.024
    xs=np.arange(q[:,0].min()+spacing,q[:,0].max(),spacing)
    ys=np.arange(q[:,1].min()+spacing,q[:,1].max(),spacing*.8660254)
    grid=np.array([(x+(spacing*.5 if j%2 else 0),y) for j,y in enumerate(ys) for x in xs])
    dist=sdpoly(grid,q)
    grid=grid[dist>spacing*.65]
    xy=np.concatenate([q,grid],axis=0)
    area=np.sum(q[:,0]*np.roll(q[:,1],-1)-q[:,1]*np.roll(q[:,0],-1))
    loop=list(range(n)) if area>0 else list(reversed(range(n)))
    boundary=[(i,(i+1)%n) for i in range(n)]
    pts,_,faces,orig,_,_=delaunay_2d_cdt([Vector(x) for x in xy],boundary,[loop],1,1e-8)
    # No seam vertices may be merged or dropped. Input indices from CDT map
    # its reordered output to the original vertices, keeping the weld exact.
    mapping={}
    for j,ids in enumerate(orig):
        assert len(ids)==1,("CDT merged a constraint or inserted a vertex",ids)
        mapping[int(ids[0])]=j
    assert len(mapping)==len(xy) and all(i in mapping for i in range(len(xy)))
    inv=np.array([int(ids[0]) for ids in orig],dtype=np.int32)
    tri=inv[np.array(faces,dtype=np.int32)]
    assert tri.ndim==2 and tri.shape[1]==3 and len(tri)>n
    assert len(np.unique(tri))==len(xy)
    # Use positive edge weights to avoid oscillations on tiny clipped edges.
    E=edges(tri);I=len(xy)-n
    assert I>100,("Insufficient interior sampling",I)
    A=np.zeros((I,I),dtype=np.float64)
    rhs=np.zeros((I,5),dtype=np.float64)
    values=np.column_stack([h,colors])
    for i,j in E:
        w=1.0/max(float(np.linalg.norm(xy[i]-xy[j])),spacing*.15)
        for u,v in ((i,j),(j,i)):
            if u<n:continue
            A[u-n,u-n]+=w
            if v<n:rhs[u-n]+=w*values[v]
            else:A[u-n,v-n]-=w
    inner=np.linalg.solve(A,rhs)
    assert np.all(np.isfinite(inner))
    # A smooth, bounded recess with zero displacement at the cut edge.
    # The torso sits deeper than the arm's inner surface, allowing clearance.
    d=sdpoly(grid,q)
    depth=.042 if limb else .105
    bubble=(1-np.exp(-d/.075))**2
    hh=inner[:,0]-depth*bubble
    pos=origin+grid@basis[:2]+hh[:,None]*normal
    # Diffuse color interpolation is harmonic, with no radial center seam.
    return pos,tri,np.clip(inner[:,1:],0,1)

def close(v,f,c,loops,limb):
    V=list(v);F=list(f);C=list(c)
    for L in loops:
        pos,tri,col=fill_patch(v[L],c[L],limb)
        indices=np.r_[np.asarray(L,dtype=np.int32),np.arange(len(V),len(V)+len(pos),dtype=np.int32)]
        V.extend(pos);C.extend(col);F.extend(indices[tri])
    V=np.asarray(V);F=np.asarray(F,dtype=np.int32);C=np.asarray(C)
    if limb:
        t=np.clip((1.77-V[:,2])/.65,0,1);t=t*t*(3-2*t)
        V[:,1]-=.055*t
        V[:,0]+=np.sign(V[:,0])*.012*t
    e=np.sort(np.concatenate([F[:,[0,1]],F[:,[1,2]],F[:,[2,0]]]),axis=1)
    _,n=np.unique(e,axis=0,return_counts=True)
    assert np.all(n==2),"Closed joint surface expected"
    assert np.all(np.isfinite(V))
    pp=V[F];areas=np.linalg.norm(np.cross(pp[:,1]-pp[:,0],pp[:,2]-pp[:,0]),axis=1)
    assert float(areas.min())>1e-12,"Degenerate joint faces"
    return V,F,C

def separate(v,f,c):
    ql=arm_field(v,f,-1);qr=arm_field(v,f,1)
    assert not np.any((ql>0)&(qr>0))
    result={};stats={}
    for name,q,pos,expected in (("FrontArm_L",ql,True,1),("FrontArm_R",qr,True,1),("Rabbit_Torso",np.maximum(ql,qr),False,2)):
        V,F,C,L=clip(v,f,c,q,pos)
        assert len(L)==expected,(name,[len(x) for x in L])
        stats[name]={"cutLoops":[len(x) for x in L],"sourceSurfaceTriangles":len(F)}
        result[name]=close(V,F,C,L,pos)
        stats[name]["closedTriangles"]=len(result[name][1])
        stats[name]["capMethod"]="constrained Delaunay + harmonic curved interior"
    return result,stats
