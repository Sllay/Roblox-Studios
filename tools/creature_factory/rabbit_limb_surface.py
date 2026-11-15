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

def close(v,f,c,loops,limb):
    V=list(v);F=list(f);C=list(c)
    for L in loops:
        p=v[L];center=p.mean(axis=0);sign=np.sign(center[0]);assert sign!=0
        # Recess the torso underneath the forelimb. The forelimb's back surface
        # is shallower, leaving clearance except at the shoulder insertion.
        depth=.065 if limb else .16
        center[1]+=depth;center[0]-=sign*(.045 if limb else .09)
        prev=list(L);n=len(L)
        for t in (.26,.52,.78):
            ring=p*(1-t)+center*t
            ring[:,1]+=depth*.22*np.sin(np.pi*t)
            ids=list(range(len(V),len(V)+n));V.extend(ring)
            C.extend(c[L]*(1-t)+c[L].mean(axis=0)*t)
            for k in range(n):
                j=(k+1)%n
                F.extend([[prev[k],prev[j],ids[j]],[prev[k],ids[j],ids[k]]])
            prev=ids
        i=len(V);V.append(center);C.append(c[L].mean(axis=0))
        for k in range(n):F.append([prev[k],prev[(k+1)%n],i])
    V=np.asarray(V);F=np.asarray(F,dtype=np.int32);C=np.asarray(C)
    # Open a slight clearance under the arm, taper to zero at the shoulder.
    if limb:
        t=np.clip((1.77-V[:,2])/.65,0,1);t=t*t*(3-2*t)
        V[:,1]-=.055*t
        V[:,0]+=np.sign(V[:,0])*.012*t
    e=np.sort(np.concatenate([F[:,[0,1]],F[:,[1,2]],F[:,[2,0]]]),axis=1)
    _,n=np.unique(e,axis=0,return_counts=True)
    assert np.all(n==2),"Closed joint surface expected"
    assert np.all(np.isfinite(V))
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
    return result,stats
