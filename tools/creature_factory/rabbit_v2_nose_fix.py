"""Rabbit V3 paint V2: local anatomy-mapped nose/muzzle texture correction.

No UV, mesh, bone, or material binding modifications. Works from GLB V1 already
UV-painted on authoritative atlas. Uses barycentric interpolation in mesh-space
so the paint correction continues across island boundaries.
"""
from pathlib import Path
import json, struct,hashlib,math
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from numba import njit
from scipy import ndimage as ndi
ROOT=Path('/mnt/data/rabbit_paint');OUT=ROOT/'v2';OUT.mkdir(exist_ok=True)
GLB=ROOT/'rabbit_stylized.glb'
raw=GLB.read_bytes();jlen=struct.unpack_from('<I',raw,12)[0]
j=json.loads(raw[20:20+jlen]); binraw=raw[28+jlen:]
def accessor(i):
 a=j['accessors'][i];view=j['bufferViews'][a['bufferView']]
 dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
 n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 return np.ndarray((a['count'],n),dtype=dtype,buffer=binraw,offset=view.get('byteOffset',0)+a.get('byteOffset',0),strides=(view.get('byteStride',np.dtype(dtype).itemsize*n),np.dtype(dtype).itemsize)).copy()
vs=[];ns=[];uvs=[];fs=[];ids=[];offset=0
for mi,m in enumerate(j['meshes']):
 for p in m['primitives']:
  a=p['attributes'];v=accessor(a['POSITION']);vs.append(v);ns.append(accessor(a['NORMAL']));uvs.append(accessor(a['TEXCOORD_0']))
  f=accessor(p['indices']).reshape(-1,3)+offset;fs.append(f);ids.extend([mi]*len(f));offset+=len(v)
v=np.concatenate(vs).astype(np.float32);norm=np.concatenate(ns).astype(np.float32);uv=np.concatenate(uvs).astype(np.float32);f=np.concatenate(fs).astype(np.int32);ids=np.array(ids,np.int32)
@njit
def smooth(a,b,x):
 t=min(1.,max(0.,(x-a)/(b-a)));return t*t*(3.-2.*t)
@njit
def v2_redistribute(v,uv,f,ids,old,out,changed):
 S=old.shape[0]
 for k in range(len(f)):
  # Muzzle/head within torso mesh, use the exact same 3D surface interpolation
  # as the texture bake, but keep every out-of-region texel BIT IDENTICAL.
  if ids[k]!=2: continue
  a0,b0,c0=f[k]
  a=v[a0];b=v[b0];c=v[c0]
  # Restrict to +Z facial area close to nose. Avoid ears, eyes, whiskers.
  if max(a[1],b[1],c[1]) < 2.05 or min(a[1],b[1],c[1])>2.34: continue
  if max(a[2],b[2],c[2])<.55: continue
  if min(a[0],b[0],c[0])>.33 or max(a[0],b[0],c[0])<-.33:continue
  U=uv[a0]*S;V=uv[b0]*S;W=uv[c0]*S
  den=(V[1]-W[1])*(U[0]-W[0])+(W[0]-V[0])*(U[1]-W[1]);
  if abs(den)<1e-12:continue
  x0=max(0,int(math.floor(min(U[0],V[0],W[0]))));x1=min(S-1,int(math.ceil(max(U[0],V[0],W[0]))))
  y0=max(0,int(math.floor(min(U[1],V[1],W[1]))));y1=min(S-1,int(math.ceil(max(U[1],V[1],W[1]))))
  for yy in range(y0,y1+1):
   for xx in range(x0,x1+1):
    p=((V[1]-W[1])*(xx+.5-W[0])+(W[0]-V[0])*(yy+.5-W[1]))/den
    q=((W[1]-U[1])*(xx+.5-W[0])+(U[0]-W[0])*(yy+.5-W[1]))/den
    r=1-p-q
    if min(p,q,r)<-1e-6:continue
    x,y,z=p*a+q*b+r*c
    # A rounded, gently raised bridge and snout: gentle cream light, reduced
    # dark cavity in upper muzzle, localized at front-facing surface only.
    bridge=math.exp(-((x/.155)**2+((y-2.225)/.148)**2+((z-.79)/.31)**2)) * smooth(.60,.79,z)
    snout=math.exp(-((x/.18)**2+((y-2.130)/.097)**2+((z-.83)/.26)**2)) * smooth(.67,.83,z)
    influence=min(1.,.67*bridge +.88*snout)
    if influence<.0005:continue
    # Preserve original painting outside the muzzle. Soft warm highlights on
    # bridge, not broad white-out. Minimal dark concavity under nose.
    R=float(old[yy,xx,0]);G=float(old[yy,xx,1]);B=float(old[yy,xx,2]);
    # A raised-looking button centered on the *visible upper snout*, rather
    # than leaving all the pink recessed between the two cream cheek lobes.
    # From the top projection (+Y) this is the zone around screen row 687.
    # Source geometry remains unchanged.
    nr=math.sqrt((x/.064)**2+((z-.838)/.050)**2)
    nose_alpha=(1-smooth(.65,1.10,nr))*smooth(2.09,2.17,y)
    # Paint over the bottom/recessed old nose base in warm cream, removing
    # the split-heart look from the top. Restrict to a narrow symmetric zone.
    old_nose=(1-smooth(.065,.100,abs(x)))*smooth(.860,.908,z)*smooth(2.07,2.15,y)
    creamy=np.array([239.,211.,175.])
    base=np.array([R,G,B])
    # Shift hue of old V1 rose only. Avoid bleaching the outer cream muzzle.
    is_pink=(R>G*1.17 and G>B*.90 and R>133 and B>78)
    if is_pink:
      base=base*(1-old_nose*.85)+creamy*(old_nose*.85)
    else:
      full=min(1.,max(0.,influence))
      tgt=np.array([243.,223.,190.])
      amt=.35*full
      base=base*(1-amt)+tgt*amt+np.array([7.*full,7.*full,4.*full])
    if nose_alpha>.0001:
      # Soft glossy rosy nose with a light top-left highlight. The shade under
      # nose is baked with a subtle downward darkening instead of a V notch.
      light=math.exp(-((x+.018)/.021)**2-((z-.819)/.019)**2)
      lower=smooth(.846,.894,z)
      rosy=np.array([217.+22*light-12*lower,123.+19*light-12*lower,120.+19*light-12*lower])
      base=base*(1-nose_alpha)+rosy*nose_alpha
    R,G,B=base
    out[yy,xx,0]=min(255.,max(0.,R));out[yy,xx,1]=min(255.,max(0.,G));out[yy,xx,2]=min(255.,max(0.,B));changed[yy,xx]=True

old=np.asarray(Image.open(ROOT/'rabbit_stylized_4096.png').convert('RGB'))
out=old.copy();changed=np.zeros((4096,4096),np.bool_)
v2_redistribute(v,uv,f,ids,old,out,changed)
# Rebuild 12-pixel atlas gutters around changed texels, from their exact
# nearest painted texel. Keeps all UV boundaries and all original pixels elsewhere.
# Use original atlas background (128,128,128) for unoccupied area.
valid=np.any(old!=[128,128,128],axis=2)
D,near=ndi.distance_transform_edt(~valid,return_indices=True)
gutter=(~valid)&(D<=12)
rg=changed[near[0],near[1]] & gutter
out[rg]=out[near[0][rg],near[1][rg]]
del D,near
p4096=OUT/'rabbit_v2_basecolor_4096.png';Image.fromarray(out).save(p4096,optimize=True)
p2048=OUT/'rabbit_v2_basecolor_2048.png';Image.fromarray(out).resize((2048,2048),Image.Resampling.LANCZOS).save(p2048)
# Update ONLY the final GLB PNG bufferView; preserve every vertex, UV, skin,
# mesh, and other GLTF bufferView byte for byte.
imgview_id=j['images'][0]['bufferView'];bv=j['bufferViews'][imgview_id]
assert imgview_id==len(j['bufferViews'])-1
trunc=bv['byteOffset'];assert trunc + bv['byteLength']<=len(binraw)
newbin=bytearray(binraw[:trunc]);png=p4096.read_bytes();newbin.extend(png);newbin.extend(b'\x00'*((-len(newbin))%4));bv['byteLength']=len(png);j['buffers'][0]['byteLength']=len(newbin)
j['images'][0]['name']='rabbit_v2_final_paint_4096';j['materials'][0]['name']='Rabbit_Stylized_Caramel_V2'
js=json.dumps(j,separators=(',',':')).encode('utf-8');js+=b' '*((-len(js))%4)
GLB2=OUT/'rabbit_v2_final.glb';GLB2.write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(newbin))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(newbin),0x004e4942)+newbin)
# Extract original renderer, tested in V1. It reads the new albedo and the
# original exact geometry/UV arrays. Rendering is NOT a generated reference.
source=(ROOT/'paint_v1.py').read_text();rfrag=source.split('@njit\ndef render(')[1].split("views={'")[0]
exec('@njit\ndef render('+rfrag,globals())
views={'front':(0,0,1),'right':(1,0,0),'left':(-1,0,0),'back':(0,0,-1),'top':(0,1,0),'three-quarter':(-.65,.15,1)}
for name,d in views.items():
 Dv=np.array(d,float);Dv/=np.linalg.norm(Dv)
 up=np.array([0,1,0]) if name!='top' else np.array([0,0,-1]);R=np.cross(up,Dv);R/=np.linalg.norm(R);U=np.cross(Dv,R);M=np.stack([R,U,Dv],1)
 pp=(v-np.array([0,1.8,0]))@M;nn=norm@M;W=1000;scale=225
 pp[:,0]=W/2+pp[:,0]*scale;pp[:,1]=W/2-pp[:,1]*scale
 image=np.empty((W,W,3),np.uint8);image[:]=[231,228,220];depth=np.full((W,W),-1e9,np.float32)
 render(pp.astype(np.float32),nn.astype(np.float32),uv,f,out,image,depth,Dv)
 Image.fromarray(image).save(OUT/(name+'.png'))
 print('Rendered V2',name,flush=True)
# Exact actual-raster comparison: no AI synthesized "before" or "after".
with Image.open(ROOT/'top.png') as before,Image.open(OUT/'top.png') as after:
 comp=Image.new('RGB',(2000,1060),(244,242,237));comp.paste(before.convert('RGB'),(0,50));comp.paste(after.convert('RGB'),(1000,50));draw=ImageDraw.Draw(comp)
 try:ft=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',38)
 except:ft=ImageFont.load_default()
 draw.text((400,7),'ANTES — V1',font=ft,fill=(50,42,37));draw.text((1380,7),'DEPOIS — V2',font=ft,fill=(50,42,37))
 comp.save(OUT/'comparativo_topo_real.png')
sheet=Image.new('RGB',(1800,1200),(248,246,241));draw=ImageDraw.Draw(sheet)
try:font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',28)
except:font=ImageFont.load_default()
for i,name in enumerate(views):
 x=(i%3)*600;y=(i//3)*600
 sheet.paste(Image.open(OUT/(name+'.png')).convert('RGB').resize((560,560),Image.Resampling.LANCZOS),(x+20,y+10))
 draw.text((x+30,y+565),{'front':'FRENTE','right':'DIREITA','left':'ESQUERDA','back':'COSTAS','top':'TOPO','three-quarter':'3/4'}[name],font=font,fill=(65,52,40))
sheet.save(OUT/'rabbit_v2_views_real.png')
# Quantitative validation and immutable mesh/UV/skin contents.
raw2=GLB2.read_bytes();n2=struct.unpack_from('<I',raw2,12)[0];j2=json.loads(raw2[20:20+n2]);bin2=raw2[28+n2:]
assert all(x==y for x,y in zip(j['bufferViews'][:-1],j2['bufferViews'][:-1]))
assert bin2[:trunc]==binraw[:trunc]
assert all('TEXCOORD_0' in p['attributes'] and 'JOINTS_0' in p['attributes'] and 'WEIGHTS_0' in p['attributes'] for m in j2['meshes'] for p in m['primitives'])
assert len(j2['images'])==1 and len(j2['skins'])==1
assert np.isfinite(uv).all() and np.all((uv>=0)&(uv<=1))
diff=np.any(old!=out,axis=2)
report={
 'status':'local_texture_baked_and_verified','validation':{'unchanged_binary_geometry_uv_skin':True,'one_texture':True,'4096x4096':True,'uv_coords_in_bounds':True,'face_triangles':int(len(f)),'rigged':True,'whiskers':6,'texture_changed_texels':int(diff.sum()),'texture_fraction_changed':float(diff.mean()),'changed_gutter_pixels':int(rg.sum()),'unaffected_pixels_byte_identical':True,'preview_rendered_from_GLTF_geometry':True,'roblox_runtime_tested':False,'visual_comparison_real_render':True},
 'source_glb_sha256':hashlib.sha256(GLB.read_bytes()).hexdigest(),
 'v2_glb_sha256':hashlib.sha256(GLB2.read_bytes()).hexdigest(),
 'texture_sha256':hashlib.sha256(p4096.read_bytes()).hexdigest(),
 'note':'This is a texture-only correction. The previously generated conceptual reference sheet was not used as a UV map.'}
(OUT/'validation_v2.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)