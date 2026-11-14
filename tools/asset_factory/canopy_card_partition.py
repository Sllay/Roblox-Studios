"""Partition authorized indexed leaf-card geometry; no mesh edits or asset I/O.

Input: positions, triangle indices. Output: original face indices in two groups.
Fails closed on non-quad, welded, degenerate or nonplanar components. UVs,
normals, winding and vertex positions are never edited. A later importer must
prove original per-corner attributes survive and preserve the original pivot.
"""
from collections import defaultdict
from math import isfinite, dist, sqrt

def cross(a,b):
    return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def dot(a,b): return sum(x*y for x,y in zip(a,b))

def partition_cards(positions, faces):
    pos=tuple(tuple(p) for p in positions)
    tris=tuple(tuple(f) for f in faces)
    if not pos or any(len(p)!=3 or not all(isfinite(x) for x in p) for p in pos):
        raise ValueError("invalid positions")
    if not tris or any(len(f)!=3 or len(set(f))!=3 or any(type(v) is not int or not 0<=v<len(pos) for v in f) for f in tris):
        raise ValueError("invalid triangles")
    by_vertex=defaultdict(list)
    for i,f in enumerate(tris):
        for v in f: by_vertex[v].append(i)
    pending=set(range(len(tris))); cards=[]
    while pending:
        first=min(pending);pending.remove(first);stack=[first];group=[]
        while stack:
            i=stack.pop();group.append(i)
            for v in tris[i]:
                for j in by_vertex[v]:
                    if j in pending: pending.remove(j);stack.append(j)
        ids=set().union(*(set(tris[i]) for i in group))
        if len(group)!=2 or len(ids)!=4:
            raise ValueError("not an independent two-triangle card; source review required")
        if len(set(tris[group[0]]) & set(tris[group[1]]))!=2:
            raise ValueError("card triangles must share exactly one edge")
        p=[pos[v] for v in sorted(ids)]
        span=max(dist(a,b) for a in p for b in p)
        if span<=1e-10 or len(set(p))!=4: raise ValueError("degenerate card")
        normals=[]
        for i in group:
            a,b,c=(pos[v] for v in tris[i])
            n=cross(sub(b,a),sub(c,a));length=sqrt(dot(n,n))
            if length<=span*span*1e-10: raise ValueError("degenerate triangle")
            normals.append(tuple(x/length for x in n))
        if abs(dot(normals[0],normals[1]))<1-1e-6:
            raise ValueError("nonplanar card")
        center=tuple(sum(v[k] for v in p)/4 for k in range(3))
        cards.append((center,tuple(sorted(group))))
    if len(cards)<2: raise ValueError("at least two cards required")
    # Spatial ordering gives deterministic mixed colors with a one-card max imbalance.
    cards.sort()
    light=tuple(i for _,g in cards[::2] for i in g)
    dark=tuple(i for _,g in cards[1::2] for i in g)
    assert set(light).isdisjoint(dark) and sorted(light+dark)==list(range(len(tris)))
    return {"light":light,"dark":dark,"cards":len(cards),"lightCards":len(light)//2,"darkCards":len(dark)//2}
