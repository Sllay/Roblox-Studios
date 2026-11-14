import json, math, sys, hashlib
from pathlib import Path
import numpy as np
import trimesh
from PIL import Image
from trimesh.visual.material import PBRMaterial
from trimesh.visual.texture import TextureVisuals

OUT=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).parent
OUT.mkdir(parents=True,exist_ok=True)
PARTS=[]
C={'ivory':(250,225,187),'cream':(232,193,145),'light':(255,238,208),'red':(224,57,48),'redshade':(180,42,35),'gold':(246,166,43),'mouth':(105,42,21),'eye':(67,35,22),'iris':(111,58,29),'black':(34,22,18),'white':(255,251,235),'blush':(246,153,120)}
def add(name,v,f,mat):
    m=trimesh.Trimesh(vertices=np.array(v,float),faces=np.array(f,int),process=False)
    m.fix_normals(); assert m.is_watertight and m.volume>0, name
    # Per-object placeholder UV, not the final packed atlas.
    uv=np.asarray(m.vertices)[:,[0,2]].copy(); uv-=uv.min(axis=0); uv/=np.maximum(uv.max(axis=0),1e-6)
    m.visual=TextureVisuals(uv=uv,material=PBRMaterial(name=mat,baseColorFactor=[*C[mat],255],roughnessFactor=.85,metallicFactor=0))
    PARTS.append((name,m,mat));return m

def loft(name,rings,mat,n=16):
    # Each horizontal section is artist-defined, including asymmetric front/back taper.
    v=[];f=[]
    for j,(z,cy,rx,ry) in enumerate(rings):
        for i in range(n):
            a=2*math.pi*(i+(j%2)*.5)/n
            v.append((rx*math.cos(a),cy+ry*math.sin(a),z))
    for j in range(len(rings)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;c=b+n;d=a+n
            f.extend([(a,b,d),(b,c,d)] if (i+j)%2 else [(a,b,c),(a,c,d)])
    for j in (0,len(rings)-1):
        k=len(v);v.append((0,rings[j][1],rings[j][0]))
        for i in range(n):f.append((k,j*n+i,j*n+(i+1)%n))
    return add(name,v,f,mat)

def sweep(name,points,widths,depths,mat,axis=(1,0,0),n=8):
    # Closed, tapered, curved feather/limb with custom cross sections.
    p=np.array(points,float); v=[];f=[];axis=np.array(axis,float)
    for j,c in enumerate(p):
        t=p[min(j+1,len(p)-1)]-p[max(j-1,0)];t/=np.linalg.norm(t)
        u=axis-t*np.dot(axis,t);u/=np.linalg.norm(u);w=np.cross(t,u)
        for i in range(n):
            a=i*2*math.pi/n;v.append(c+u*widths[j]*math.cos(a)+w*depths[j]*math.sin(a))
    for j in range(len(p)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;c=b+n;d=a+n;f.extend([(a,b,c),(a,c,d)])
    for j in (0,len(p)-1):
        k=len(v);v.append(p[j]);f.extend((k,j*n+i,j*n+(i+1)%n) for i in range(n))
    return add(name,v,f,mat)

def plate(name,outline,center,depth,mat,axis=(0,-1,0)):
    # Sculpted convex polygon plate with tapered edges and a raised center.
    q=np.array(outline,float);c=np.array(center,float);a=np.array(axis,float);a/=np.linalg.norm(a)
    n=len(q);v=list(q)+[c+a*depth,c-a*depth*.65];f=[]
    for i in range(n):f.extend([(i,(i+1)%n,n),(i,n+1,(i+1)%n)])
    return add(name,v,f,mat)

# Continuous connected head/neck/torso, designed as a single silhouette.
loft('Body_Head',[(.38,.04,.18,.24),(.47,.04,.41,.43),(.62,.06,.57,.61),(.83,.06,.66,.69),(1.05,.025,.65,.65),(1.23,-.045,.54,.54),(1.38,-.19,.38,.40),(1.49,-.30,.31,.32),(1.60,-.39,.40,.36),(1.76,-.42,.46,.40),(1.96,-.40,.43,.37),(2.12,-.35,.32,.29),(2.22,-.32,.12,.13)],'ivory',24)
# Collar feathers are thin, tapered plates which follow the body surface.
for i,a in enumerate(np.linspace(-2.8,-.34,7)):
    x=.34*math.cos(a);y=-.18+.39*math.sin(a)
    end=(.54*math.cos(a),-.07+.60*math.sin(a),1.08+.13*abs(math.cos(a)))
    sweep('Collar_%02d'%i,[(x,y,1.50),(x*1.24,y-.055,1.36),end],[.09,.15,.008],[.045,.075,.008],'light',axis=(math.sin(a),-math.cos(a),0),n=6)
# Three main curved tail blades and two side feathers. Root embedded in torso.
for i,(x,dy,dz,w) in enumerate([(0,.0,.13,.20),(-.24,.02,-.01,.19),(.24,.02,-.01,.19),(-.39,.11,-.20,.15),(.39,.11,-.20,.15)]):
    sweep('Tail_%02d'%i,[(x*.25,.40,1.0),(x*.70,.67,1.35),(x,.86+dy,1.60+dz),(x*1.05,1.06+dy,1.82+dz),(x*1.04,1.24+dy,1.86+dz),(x*1.03,1.38+dy,1.75+dz)],[.065,w*.83,w,w*.90,w*.55,.012],[.055,.105,.115,.10,.06,.008],'light' if i<3 else 'cream',n=8)
# Comb silhouette built as one connected profile, rather than three overlapping balls.
q=[(0,-.59,2.08),(0,-.66,2.30),(0,-.59,2.57),(0,-.43,2.65),(0,-.31,2.53),(0,-.29,2.38),(0,-.13,2.48),(0,.01,2.46),(0,.08,2.34),(0,.03,2.22),(0,.17,2.25),(0,.25,2.15),(0,.19,2.04),(0,-.06,2.02)]
# outline is concave; triangulate each side with ear clipping instead of a center fan.
def extrude_outline(name,q,axis,depth,mat,bevel=0):
    q=np.array(q,float);a=np.array(axis,float);a/=np.linalg.norm(a);n=len(q)
    # Project to the plane; triangulate simple outline via ear clipping.
    dims=np.argsort(np.abs(a))[:2];xy=q[:,dims];idx=list(range(n));faces=[]
    signed=sum(xy[i,0]*xy[(i+1)%n,1]-xy[(i+1)%n,0]*xy[i,1] for i in range(n));sgn=1 if signed>0 else -1
    def cross(p,q,r):return (q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
    while len(idx)>3:
        for j,b in enumerate(idx):
            aa=idx[j-1];cc=idx[(j+1)%len(idx)];p,r,t=xy[aa],xy[b],xy[cc]
            if sgn*cross(p,r,t)<=1e-8:continue
            if any(all(sgn*k>=-1e-8 for k in (cross(p,r,xy[k]),cross(r,t,xy[k]),cross(t,p,xy[k]))) for k in idx if k not in (aa,b,cc)):continue
            faces.append((aa,b,cc));idx.pop(j);break
        else:raise RuntimeError('outline triangulation')
    faces.append(tuple(idx))
    if bevel:
        mid=q.mean(0);inset=mid+(q-mid)*(1-bevel)
        v=list(inset+a*depth)+list(q+a*depth*.45)+list(q-a*depth*.45)+list(inset-a*depth)
        f=faces+[(i+3*n,k+3*n,j+3*n) for i,j,k in faces]
        for ring in range(3):
            for i in range(n):
                j=(i+1)%n;aa=ring*n+i;bb=ring*n+j;f.extend([(aa,bb,bb+n),(aa,bb+n,aa+n)])
    else:
        v=list(q+a*depth)+list(q-a*depth)
        f=faces+[(a+n,c+n,b+n) for a,b,c in faces]
        for i in range(n):j=(i+1)%n;f.extend([(i,j,j+n),(i,j+n,i+n)])
    return add(name,v,f,mat)
extrude_outline('Comb',q,(1,0,0),.13,'red',bevel=.19)
# Curved wing silhouette and layered sculpted feathers. Individual surfaces do not
# weave through each other: distinct outer lateral layers with fixed depth.
for side,L in [(-1,'L'),(1,'R')]:
    def wing_shape(name,yz,x,depth,mat,bevel):
        return extrude_outline(name,[(side*x,y,z) for y,z in yz],(side,0,0),depth,mat,bevel)
    wing_shape('Wing_'+L,[(-.35,1.22),(-.23,1.35),(-.04,1.39),(.19,1.34),(.43,1.21),(.61,1.03),(.48,.87),(.24,.79),(.0,.79),(-.20,.91),(-.34,1.06)],.59,.135,'cream',.19)
    # Feather tips are broad pointed leaf silhouettes; their roots overlap the wing.
    wing_shape('WingFeather_'+L+'2',[(-.21,1.08),(-.04,1.14),(.17,1.10),(.36,.99),(.51,.83),(.25,.84),(.04,.89),(-.15,.98)],.705,.066,'ivory',.20)
    wing_shape('WingFeather_'+L+'1',[(-.25,1.18),(-.06,1.26),(.15,1.22),(.37,1.10),(.54,.96),(.29,.97),(.05,1.04),(-.16,1.10)],.743,.069,'cream',.19)
    wing_shape('WingFeather_'+L+'0',[(-.27,1.27),(-.08,1.36),(.13,1.33),(.34,1.24),(.50,1.12),(.25,1.12),(.04,1.18),(-.17,1.20)],.773,.071,'light',.21)
# Facial features conform to actual head triangles (not floating balls).
body=PARTS[0][1]; bodytris=body.vertices[body.faces]
def surface_y(x,z):
    hits=[]
    for t in bodytris:
        a,b,c=t[:,[0,2]];den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(den)<1e-10:continue
        u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(z-c[1]))/den;v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(z-c[1]))/den;w=1-u-v
        if min(u,v,w)>=-1e-7:hits.append(u*t[0,1]+v*t[1,1]+w*t[2,1])
    if not hits:raise ValueError((x,z))
    return min(hits)
def patch(name,x,z,rx,rz,mat,offset):
    n=16;points=[(x+rx*math.cos(i*math.tau/n),z+rz*math.sin(i*math.tau/n)) for i in range(n)]
    v=[(px,surface_y(px,pz)-offset,pz) for px,pz in points]+[(px,surface_y(px,pz)-offset+.008,pz) for px,pz in points]
    v.extend([(x,surface_y(x,z)-offset-.006,z),(x,surface_y(x,z)-offset+.008,z)])
    f=[]
    for i in range(n):
        j=(i+1)%n;f.extend([(2*n,i,j),(2*n+1,j+n,i+n),(i,i+n,j+n),(i,j+n,j)])
    return add(name,v,f,mat)
for s,L in [(-1,'L'),(1,'R')]:
    x=s*.215
    patch('Eye_'+L,x,1.91,.124,.157,'eye',.023)
    patch('Iris_'+L,x+s*.008,1.875,.087,.108,'iris',.038)
    patch('Pupil_'+L,x+s*.009,1.91,.059,.082,'black',.05)
    patch('Glint_'+L,x-.035,1.968,.027,.031,'white',.065)
    patch('Cheek_'+L,s*.27,1.72,.095,.047,'blush',.018)
    # wattle tapers from beak base, broad middle and pointed lower end.
    sweep('Wattle_'+L,[(s*.085,-.75,1.65),(s*.12,-.81,1.54),(s*.13,-.79,1.41),(s*.11,-.72,1.36)],[.035,.095,.082,.012],[.03,.07,.06,.01],'red',n=8)
# Beak profile, upper and lower lip, slight open neutral expression.
plate('BeakUpper',[(-.18,-.74,1.79),(0,-1.04,1.78),(.18,-.74,1.79),(.13,-.735,1.88),(0,-.75,1.96),(-.13,-.735,1.88)],(0,-.86,1.84),.085,'gold',axis=(0,-1,.2))
plate('BeakLower',[(-.15,-.75,1.76),(0,-1.0,1.67),(.15,-.75,1.76),(.10,-.74,1.67),(0,-.76,1.62),(-.10,-.74,1.67)],(0,-.86,1.70),.065,'gold',axis=(0,-1,-.2))
plate('Mouth',[(-.135,-.785,1.765),(0,-1.015,1.755),(.135,-.785,1.765),(0,-.87,1.67)],(0,-.92,1.73),.012,'mouth',axis=(0,-1,0))
# Leg and foot as designed tapered anatomy, not straight cylinders. Foot outline has 3 toes.
for s,L in [(-1,'L'),(1,'R')]:
    x=s*.24
    sweep('Leg_'+L,[(x,.045,.52),(x,.03,.34),(x,-.015,.17),(x,-.055,.075)],[.12,.072,.059,.083],[.10,.062,.055,.075],'gold',n=8)
    outline=[(-.105,.065),(-.13,-.12),(-.22,-.31),(-.12,-.34),(-.025,-.18),(0,-.39),(.075,-.38),(.08,-.19),(.20,-.32),(.25,-.26),(.14,-.10),(.095,.085),(0,.12)]
    q=[(x+u,v,.04) for u,v in outline];extrude_outline('Foot_'+L,q,(0,0,1),.04,'gold',bevel=.18)
# glTF coordinate Y-up, convert from authored Z-up; preserve named components.
scene=trimesh.Scene()
rot=trimesh.transformations.rotation_matrix(-math.pi/2,[1,0,0])
for name,m,mat in PARTS:
    g=m.copy();g.apply_transform(rot);scene.add_geometry(g,node_name=name,geom_name=name)
path=OUT/'chicken-v2.glb';path.write_bytes(scene.export(file_type='glb'))
loaded=trimesh.load(path,force='scene');ntri=sum(len(m.faces) for _,m,_ in PARTS);assert sum(len(m.faces) for m in loaded.geometry.values())==ntri
assert len(loaded.geometry)==len(PARTS) and ntri<5000
# Actual mesh render: orthographic z-buffer, faceted studio illumination.
from numba import njit
@njit
def raster(img,depth,pts,ds,colors):
    H,W=depth.shape
    for i in range(len(pts)):
        x0,y0=pts[i,0];x1,y1=pts[i,1];x2,y2=pts[i,2];den=(y1-y2)*(x0-x2)+(x2-x1)*(y0-y2)
        if abs(den)<1e-9:continue
        for y in range(max(0,int(min(y0,y1,y2))),min(H-1,int(max(y0,y1,y2))+1)+1):
            for x in range(max(0,int(min(x0,x1,x2))),min(W-1,int(max(x0,x1,x2))+1)+1):
                a=((y1-y2)*(x+.5-x2)+(x2-x1)*(y+.5-y2))/den;b=((y2-y0)*(x+.5-x2)+(x0-x2)*(y+.5-y2))/den;c=1-a-b
                if a>=-1e-6 and b>=-1e-6 and c>=-1e-6:
                    d=a*ds[i,0]+b*ds[i,1]+c*ds[i,2]
                    if d>depth[y,x]:
                        depth[y,x]=d
                        for k in range(3):img[y,x,k]=colors[i,k]
                        img[y,x,3]=255

def render(name,d):
    d=np.array(d,float);d/=np.linalg.norm(d);r=np.cross([0,0,1],d);r/=np.linalg.norm(r);u=np.cross(d,r)
    # Camera right is chosen so front view reads naturally.
    allv=np.concatenate([m.vertices for _,m,_ in PARTS]);p=np.column_stack((allv@r,allv@u));center=(p.min(0)+p.max(0))/2
    size=1000;scale=800/max((p.max(0)-p.min(0)).max(),2.65)
    points=[];depths=[];colors=[];light=np.array([-.4,-.7,1.2]);light/=np.linalg.norm(light)
    for _,m,mat in PARTS:
        v=m.vertices;p=np.column_stack((v@r,v@u));p=(p-center)*scale;p[:,0]+=size/2;p[:,1]=size/2-p[:,1]
        for i,f in enumerate(m.faces):
            normal=m.face_normals[i];diff=max(0,float(normal@light));shade=.66+.37*diff
            colors.append(np.clip(np.array(C[mat])*shade,0,255).astype(np.uint8));points.append(p[f]);depths.append(v[f]@d)
    img=np.zeros((size,size,4),np.uint8);depth=np.full((size,size),-1e10);raster(img,depth,np.array(points),np.array(depths),np.array(colors))
    Image.fromarray(img).resize((750,750),Image.Resampling.LANCZOS).save(OUT/(name+'.png'))
for name,d in [('three-quarter',(3,-5,2)),('front',(0,-1,0)),('left',(1,0,0)),('back',(0,1,0))]:render(name,d)
report={'state':'review_ready','triangles':ntri,'meshObjects':len(PARTS),'watertightComponents':True,'roundtripTriangleCount':True,'roundtripMeshCount':True,'uv':'per-component placeholder; final atlas pending','rigged':False,'robloxPublished':False,'heightAuthoringUnits':2.65,'glbBytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'views':['three-quarter','front','left','back'],'method':'authored silhouette lofts, sculpted swept feather sections and custom polygon plates; not image reconstruction','conceptApproval':'user-approved transparent hero + multi-view; artistic match pending', 'referenceSha256':{'hero':'3fa375e57f1e179595af6c748641c792754ee3dcffe4167f4529daea86836c33','turnaround':'47fc384eb798fc88d33db69cce585e4124b23bbf71fd0bfb93e5c74c38e36b79'}}
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
