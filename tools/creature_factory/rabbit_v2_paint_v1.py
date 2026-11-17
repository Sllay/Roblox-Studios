import os, json,struct,hashlib,math
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy import ndimage as ndi
from numba import njit
from pathlib import Path
S=Path('/mnt/data/rabbit_src'); O=Path('/mnt/data/rabbit_paint'); raw=(S/'asset.glb').read_bytes(); n,t=struct.unpack_from('<II',raw,12); j=json.loads(raw[20:20+n]); binraw=raw[28+n:];
def accessor(i):
 a=j['accessors'][i]; v=j['bufferViews'][a['bufferView']]; typ={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]; k={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]; return np.ndarray((a['count'],k),dtype=typ,buffer=binraw,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',np.dtype(typ).itemsize*k),np.dtype(typ).itemsize)).copy()
vs=[];ns=[];uvs=[];fs=[]; ids=[]; offset=0
for mi,m in enumerate(j['meshes']):
 p=m['primitives'][0]; a=p['attributes']; v=accessor(a['POSITION']); vs.append(v); ns.append(accessor(a['NORMAL'])); uvs.append(accessor(a['TEXCOORD_0'])); f=accessor(p['indices']).reshape(-1,3)+offset;fs.append(f);ids.extend([mi]*len(f));offset+=len(v)
v=np.concatenate(vs);norm=np.concatenate(ns);uv=np.concatenate(uvs);f=np.concatenate(fs).astype(np.int32); ids=np.array(ids,np.int32)
# glTF is Y-up and rabbit faces +Z. Image UV origin top left.
@njit
def smooth(a,b,x):
 t=min(1.,max(0.,(x-a)/(b-a)));return t*t*(3.-2.*t)
@njit
def bake(v,norm,uv,f,ids,old,out,mask):
 size=out.shape[0]
 for k in range(len(f)):
  i0,i1,i2=f[k]; a=uv[i0]*size; b=uv[i1]*size; c=uv[i2]*size
  den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1]);
  if abs(den)<1e-10:continue
  x0=max(0,int(np.floor(min(a[0],b[0],c[0]))));x1=min(size-1,int(np.ceil(max(a[0],b[0],c[0])))); y0=max(0,int(np.floor(min(a[1],b[1],c[1]))));y1=min(size-1,int(np.ceil(max(a[1],b[1],c[1]))));
  for yy in range(y0,y1+1):
   for xx in range(x0,x1+1):
    p=((b[1]-c[1])*(xx+.5-c[0])+(c[0]-b[0])*(yy+.5-c[1]))/den;q=((c[1]-a[1])*(xx+.5-c[0])+(a[0]-c[0])*(yy+.5-c[1]))/den;r=1-p-q
    if min(p,q,r)<-1e-6:continue
    x,y,z=p*v[i0]+q*v[i1]+r*v[i2]; R,G,B=old[yy,xx].astype(np.float32); mask[yy,xx]=True
    # Preserve semantic markings from original atlas, then repaint with a restrained palette.
    cream=smooth(0.58,.83,G/max(R,1.))*smooth(95.,165.,R); pink=smooth(.55,.85,B/max(G,1.))*smooth(17.,45.,R-G)*smooth(105.,175.,R)
    eye=(1-smooth(48.,100.,R))* (1-smooth(60.,110.,G));
    # Body color varies spatially, not by chart. Subtle broad painterly variation.
    wave=2.5*math.sin(9*x+4*y+3*z)+1.6*math.sin(14*z-7*y+2*x)+.9*math.sin(25*x+18*y+10*z)
    light=6*smooth(.2,1.1,z)+5*smooth(.3,2.5,y)-6*smooth(.1,.8,-z)
    # warm caramel with a gentle, brighter cheek and forehead
    cheek=math.exp(-((abs(x)-.36)**2/.12+(y-2.18)**2/.16+(z-.55)**2/.25))*5
    base=np.array([184.+light+wave+cheek,133.+light+wave+cheek,85.+light+wave*.7+cheek*.65]);
    # Cream markings: warm ivory, slight gradient in same spatial field.
    ivory=np.array([240.+wave*.45,218.+wave*.55,180.+wave*.6]);
    # original neutral grey is never a semantic marking; keep default color for tiny source raster gaps.
    if abs(R-G)<2 and abs(G-B)<2 and 120<R<136:cream=0;pink=0;eye=0
    if y>2.64:
      # rose interior based on original color, do not add a hard seam at ear boundary
      pink=0
      cream=0;eye=0
    elif y>1.9:
      # nose is small central pink marking; eye mask confined to face
      pink*=math.exp(-(x*x/.07+(y-2.10)**2/.06))
      eye*=smooth(.15,.35,abs(x))*smooth(1.95,2.13,y)
    else: pink=0;eye=0
    # Rebuild broad body markings in model space: softly shaped bib, not a rectangular stripe.
    if y<1.92 and ids[k]==2:
      if y>.33 and z>-.05:
        width=.24+.10*math.exp(-((y-1.28)/.53)**2)
        bib=smooth(-.05,.30,z)*(1-smooth(width-.045,width+.085,abs(x)))*smooth(.27,.70,y)
        cream=bib
      elif y<.34:
        cream=smooth(.12,.44,z)
      elif z<-.55:
        cream=max(cream,smooth(.58,.83,-z)*smooth(.45,.64,y)*(1-smooth(1.11,1.31,y))*(1-smooth(.20,.36,abs(x))))
    if ids[k]<2:
      cream=max(cream*.25,(1-smooth(1.00,1.31,y))*smooth(.05,.38,z))
    if y>1.92 and y<2.64:
      # Muzzle has a continuous, rounded cream mask across seams.
      muzzle=smooth(.35,.67,z)*(1-smooth(2.19,2.34,y))*(1-smooth(.36,.53,abs(x)))
      cream=max(cream*.73,muzzle)
    c0=base*(1-cream)+ivory*cream
    rose=np.array([215.+wave*.4,149.+wave*.5,145.+wave*.45]);c0=c0*(1-pink)+rose*pink
    if y>2.64:
      # preserve inner-ear marking while giving it a pastel rose center
      nz=p*norm[i0,2]+q*norm[i1,2]+r*norm[i2,2]
      ep=smooth(.67,.87,B/max(G,1.))*smooth(18.,40.,R-G)*smooth(2.67,2.85,y)*smooth(-.08,.35,nz)
      c0=c0*(1-ep)+rose*ep
    if 2.16<y<2.60 and z>.23 and abs(x)>.15:
      # Elliptical eye painted in the surface's tangent plane, mirrored across the face.
      dx=abs(x)-.3514;dy=y-2.3633;dz=z-.4954
      eu=-.6703*dx+.7215*dy+.1737*dz;ev=-.3724*dx-.5295*dy+.7622*dz;en=.6418*dx+.4463*dy+.6236*dz
      rho=math.sqrt((eu/.134)**2+(ev/.188)**2)
      valid=(1-smooth(.07,.15,abs(en)))
      rim=(1-smooth(.97,1.17,rho))*valid
      c0=c0*(1-rim)+np.array([225.,188.,141.])*rim
      eye2=(1-smooth(.86,.99,rho))*valid
      iris=1-smooth(.20,.95,rho); dark=np.array([51.+12*iris,32.+8*iris,26.+5*iris]);
      # two soft hand-painted glints, stable under game lighting
      glint=math.exp(-((eu-.046)**2/.00058+(ev+.025)**2/.00083))*0.88
      glint2=math.exp(-((eu+.040)**2/.00013+(ev-.048)**2/.00017))*0.56
      glint=min(1.,glint+glint2)
      dark=dark*(1-glint)+np.array([246.,232.,204.])*glint
      c0=c0*(1-eye2)+dark*eye2
    if 2.04<y<2.25 and abs(x)<.12 and z>.76:
      nr=math.sqrt((x/.079)**2+((y-2.147)/.060)**2)
      nm=(1-smooth(.72,1.13,nr))*smooth(.77,.84,z)
      nose=np.array([163.+16*smooth(2.10,2.19,y),95.+17*smooth(2.10,2.19,y),92.+16*smooth(2.10,2.19,y)])
      c0=c0*(1-nm)+nose*nm
    if ids[k]>=3:c0=np.array([241.,221.,190.])
    for ch in range(3):out[yy,xx,ch]=np.uint8(min(255.,max(0.,c0[ch])))
size=4096;old=np.asarray(Image.open(S/'rabbit_basecolor_4096.png').convert('RGB')); out=np.zeros_like(old); mask=np.zeros((size,size),np.bool_);bake(v,norm,uv,f,ids,old,out,mask)
print('coverage',mask.mean(),flush=True)
# same nearest-pixel gutter method as existing rabbit_final_atlas.py
D,I=ndi.distance_transform_edt(~mask,return_indices=True); fill=(~mask)&(D<=12);out[fill]=out[I[0][fill],I[1][fill]];out[(~mask)&(~fill)]=[128,128,128]; del D,I
Image.fromarray(out).save(O/'rabbit_stylized_4096.png');Image.fromarray(out).resize((2048,2048),Image.Resampling.LANCZOS).save(O/'rabbit_stylized_2048.png')
# replace GLB image only, append image data (all existing mesh/UV/skin accessor bytes remain unchanged)
png=(O/'rabbit_stylized_4096.png').read_bytes(); nb=bytearray(binraw);nb.extend(b'\0'*((-len(nb))%4)); offset=len(nb);nb.extend(png);nb.extend(b'\0'*((-len(nb))%4));j['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(png)});j['images'][0]['bufferView']=len(j['bufferViews'])-1;j['images'][0]['name']='rabbit_stylized_4096';j['buffers'][0]['byteLength']=len(nb);j['materials'][0]['name']='Rabbit_Stylized_Caramel';js=json.dumps(j,separators=(',',':')).encode();js+=b' '*((-len(js))%4);(O/'rabbit_stylized.glb').write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(nb))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(nb),0x004e4942)+nb)
# Orthographic CPU rasterization using original mesh, normals and UVs. 
@njit
def render(pos,norm,uv,f,tex,im,depth,view):
 h,w=im.shape[:2];ts=tex.shape[0]
 for k in range(len(f)):
  i0,i1,i2=f[k];a=pos[i0];b=pos[i1];c=pos[i2];den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1]);
  if abs(den)<1e-8:continue
  x0=max(0,int(np.floor(min(a[0],b[0],c[0]))));x1=min(w-1,int(np.ceil(max(a[0],b[0],c[0]))));y0=max(0,int(np.floor(min(a[1],b[1],c[1]))));y1=min(h-1,int(np.ceil(max(a[1],b[1],c[1]))));
  for yy in range(y0,y1+1):
   for xx in range(x0,x1+1):
    p=((b[1]-c[1])*(xx+.5-c[0])+(c[0]-b[0])*(yy+.5-c[1]))/den;q=((c[1]-a[1])*(xx+.5-c[0])+(a[0]-c[0])*(yy+.5-c[1]))/den;r=1-p-q
    if min(p,q,r)<-1e-6:continue
    z=p*a[2]+q*b[2]+r*c[2]
    if z<=depth[yy,xx]:continue
    depth[yy,xx]=z;u=(p*uv[i0]+q*uv[i1]+r*uv[i2])*ts-.5;tx=min(ts-2,max(0,int(u[0])));ty=min(ts-2,max(0,int(u[1])));fx=min(1.,max(0.,u[0]-tx));fy=min(1.,max(0.,u[1]-ty));rgb=(1-fy)*((1-fx)*tex[ty,tx]+fx*tex[ty,tx+1])+fy*((1-fx)*tex[ty+1,tx]+fx*tex[ty+1,tx+1]); N=p*norm[i0]+q*norm[i1]+r*norm[i2];N=N/max(1e-6,np.sqrt((N*N).sum()));
    # key from camera upper left, fill from sky; preserve soft stylized appearance
    lit=max(0.,N[0]*-.45+N[1]*.75+N[2]*.48); fill=max(0.,N[2]);shade=.72+.22*lit+.10*fill; rim=.035*max(0.,N[1]);
    for ch in range(3):im[yy,xx,ch]=np.uint8(min(255.,rgb[ch]*shade+255*rim))
views={'front':(0,0,1),'left':(-1,0,0),'right':(1,0,0),'back':(0,0,-1),'top':(0,1,0),'three-quarter':(-.65,.15,1)}
for name,d in views.items():
 D=np.array(d,float);D/=np.linalg.norm(D);up=np.array([0,1,0]) if name!='top' else np.array([0,0,-1]);R=np.cross(up,D);R/=np.linalg.norm(R);U=np.cross(D,R);M=np.stack([R,U,D],1);pp=(v-np.array([0,1.8,0]))@M; nn=norm@M; W=1000; sc=225; pp[:,0]=W/2+pp[:,0]*sc;pp[:,1]=W/2-pp[:,1]*sc
 im=np.empty((W,W,3),np.uint8);im[:]=[231,228,220]; depth=np.full((W,W),-1e9,np.float32);render(pp.astype(np.float32),nn.astype(np.float32),uv,f,out,im,depth,D);Image.fromarray(im).save(O/(name+'.png'));print(name,flush=True)
# UV guide with white background for readability, exact original boundaries
islands=Image.open(S/'rabbit_uv_islands_4096.png').convert('RGBA'); bg=Image.new('RGBA',islands.size,'white');bg.alpha_composite(islands);bg.convert('RGB').save(O/'rabbit_uv_clean_4096.png')
# package sheet: actual views not generated approximations
sheet=Image.new('RGB',(1800,1200),(248,246,241));dr=ImageDraw.Draw(sheet);font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',30)
for i,name in enumerate(views):
 x=(i%3)*600;y=(i//3)*600; im=Image.open(O/(name+'.png')).resize((560,560),Image.Resampling.LANCZOS);sheet.paste(im,(x+20,y+10));dr.text((x+30,y+565),{'front':'FRENTE','left':'ESQUERDA','right':'DIREITA','back':'COSTAS','top':'TOPO','three-quarter':'3/4'}[name],font=font,fill=(65,52,40))
sheet.save(O/'rabbit_views.png')
print('done',flush=True)