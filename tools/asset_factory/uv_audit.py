"""Audit imported GLB UV triangles, grouped by material or shared atlas.
Positive-area intersections only; touching edges are not overlaps.
"""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
args=sys.argv[sys.argv.index("--")+1:]
src,out=map(Path,args[:2])
shared="--shared" in args
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src.resolve()))
def cross(a,b,c): return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)
def area(p): return abs(sum(a.x*b.y-a.y*b.x for a,b in zip(p,p[1:]+p[:1])))/2 if len(p)>2 else 0
def intersect(p,q):
    if cross(*q)<0:q=q[::-1]
    for a,b in zip(q,q[1:]+q[:1]):
        result=[]
        if not p:return 0
        for s,e in zip(p,p[1:]+p[:1]):
            ds,de=cross(a,b,s),cross(a,b,e)
            if (ds>=0)!=(de>=0):result.append(s+(e-s)*(ds/(ds-de)))
            if de>=0:result.append(e)
        p=result
    return area(p)
groups={};degenerate=0;outside=0;ratios=[];stretch=[]
for o in bpy.context.scene.objects:
    if o.type!="MESH":continue
    m=o.data;m.calc_loop_triangles()
    if not m.uv_layers.active:raise ValueError("Missing UV: "+o.name)
    uv=m.uv_layers[int(args[args.index("--uv-index")+1])].data if "--uv-index" in args else m.uv_layers.active.data
    for t in m.loop_triangles:
        p=[uv[i].uv.copy() for i in t.loops]
        v=[o.matrix_world@m.vertices[i].co for i in t.vertices]
        a=area(p);b=(v[1]-v[0]).cross(v[2]-v[0]).length/2
        if a<1e-12 or b<1e-12:degenerate+=1;continue
        outside+=int(any(not (-1e-6<=c<=1+1e-6) for x in p for c in x))
        ratios.append(math.sqrt(a/b))
        # Singular values of the surface-to-UV Jacobian, independent of triangle orientation.
        e=v[1]-v[0];f=v[2]-v[0];x=e.length;y=f.dot(e)/x;z=2*b/x
        u=p[1]-p[0];w=p[2]-p[0];j=u/x;k=(w-j*y)/z
        tr=j.length_squared+k.length_squared;det=(j.x*k.y-j.y*k.x)**2
        high=(tr+math.sqrt(max(0,tr*tr-4*det)))/2
        stretch.append(high/math.sqrt(det))
        mat=o.material_slots[t.material_index].material if len(o.material_slots)>t.material_index else None
        key="shared" if shared else (mat.name if mat else o.name)
        groups.setdefault(key,[]).append((p,min(x.x for x in p),max(x.x for x in p),min(x.y for x in p),max(x.y for x in p)))
pairs=0;overlap=0
for items in groups.values():
    items.sort(key=lambda x:x[1])
    for i,(p,x0,x1,y0,y1) in enumerate(items):
        for q,a,b,c,d in items[i+1:]:
            if a>=x1:break
            if c>=y1 or d<=y0:continue
            s=intersect(p,q)
            if s>1e-10:pairs+=1;overlap+=s
def percentile(a,p):
    a=sorted(a);return a[round((len(a)-1)*p)] if a else None
report={"source":str(src),"sharedAtlas":shared,"triangles":len(ratios),"degenerate":degenerate,"outsideUnitSquare":outside,"overlapPairs":pairs,"pairwiseOverlapArea":overlap,"stretchP50":percentile(stretch,.5),"stretchP95":percentile(stretch,.95),"stretchMax":max(stretch,default=None),"densityP05":percentile(ratios,.05),"densityP95":percentile(ratios,.95),"scope":"overlap per material unless shared atlas; distortion reported, not artistic approval"}
out.write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
if shared and (pairs or degenerate or outside):raise ValueError("Shared atlas failed UV audit")
