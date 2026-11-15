"""Anatomical UV atlas, independent unmirrored charts, fixed labeled regions.
Generates one 4096 atlas with 2048 guides and a clean paint-ready base color.
"""
import sys,json,hashlib
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy import ndimage as ndi
import xatlas
out=Path(sys.argv[1]);size=4096
meta=json.loads((out/"atlas-input.json").read_text());a=np.load(out/"atlas-input.npz")
# Rectangles are UV-space (origin lower-left). Keep head and body largest;
# individual limbs and ears are deliberately separate, not mirrored UVs.
slots={
 "Torso":(0,0,2048,2048),"Head":(0,2048,2048,2048),
 "Ear_L":(2048,3072,1024,1024),"Ear_R":(3072,3072,1024,1024),
 "FrontArm_L":(2048,1792,1024,1280),"FrontArm_R":(3072,1792,1024,1280),
 "HindPaw_L":(2048,768,1024,1024),"HindPaw_R":(3072,768,1024,1024),
 "Tail":(2048,0,768,768),"Whiskers":(2816,0,1280,768)}
palette=[(208,163,102),(130,195,237),(232,150,182),(212,154,224),(135,201,174),(111,179,183),(243,188,111),(237,152,116),(185,196,119),(179,184,199)]
def region(name,p):
    if name.startswith("Whisker"):return "Whiskers"
    if name.startswith("FrontArm"):return name
    x,y,z=p;tag="L" if x<0 else "R"
    if z>2.63:return "Ear_"+tag
    if z>1.92:return "Head"
    if z<.32:return "HindPaw_"+tag
    if y>.65 and .49<z<1.28:return "Tail"
    return "Torso"
groups={k:[] for k in slots}
for m in meta:
    i=m["index"];v=a[f"v{i}"];f=a[f"f{i}"];cent=v[f].mean(axis=1)
    for k,p in enumerate(cent):groups[region(m["name"],p)].append((i,k))
uvs={m["index"]:np.full((m["loops"],2),np.nan,np.float32) for m in meta}
raster=np.zeros((size,size),np.int16);base=np.zeros((size,size,3),np.uint8)
wire=Image.new("RGBA",(size,size),(0,0,0,0));dw=ImageDraw.Draw(wire)
islands=Image.new("RGBA",(size,size),(0,0,0,0));di=ImageDraw.Draw(islands)
guide=Image.new("RGB",(size,size),(245,245,245));dg=ImageDraw.Draw(guide)
try:font=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",44)
except:font=ImageFont.load_default()
stats={};overlap=0;all_area=0;all_tri=0
for rid,(name,slot) in enumerate(slots.items(),1):
    pairs=groups[name];assert pairs,name
    # Each region is packed independently; disconnected pieces are allowed.
    # Original vertex IDs are tracked by object to prevent cross-object welds.
    vertmap={};verts=[];faces=[];colors=[]
    for i,k in pairs:
        ids=a[f"f{i}"][k];row=[]
        for j in ids:
            key=(i,int(j))
            if key not in vertmap:
                vertmap[key]=len(verts);verts.append(a[f"v{i}"][j]);colors.append(a[f"c{i}"][j,:3])
            row.append(vertmap[key])
        faces.append(row)
    v=np.asarray(verts,np.float32);f=np.asarray(faces,np.uint32);col=np.asarray(colors)
    at=xatlas.Atlas();at.add_mesh(v,f)
    co=xatlas.ChartOptions();co.max_iterations=4
    po=xatlas.PackOptions();po.resolution=max(slot[2:]);po.padding=12;po.bilinear=True
    at.generate(chart_options=co,pack_options=po)
    vm,ix,uv=at[0];assert np.array_equal(vm[ix],f),"Atlas changed face correspondence"
    # Preserve chart aspect ratio and reserve a 20px region margin at 4K.
    x,y,w,h=slot;pad=20
    scale=min((w-2*pad)/at.width,(h-2*pad)/at.height)
    xy=uv*np.array([at.width,at.height])*scale
    xy+=np.array([x+(w-at.width*scale)/2,y+(h-at.height*scale)/2])
    assert np.all(xy[:,0]>x) and np.all(xy[:,0]<x+w) and np.all(xy[:,1]>y) and np.all(xy[:,1]<y+h)
    q=xy[ix];facecol=col[f]
    geo=v[f];area3=np.linalg.norm(np.cross(geo[:,1]-geo[:,0],geo[:,2]-geo[:,0]),axis=1)*.5
    area2=np.abs((q[:,1,0]-q[:,0,0])*(q[:,2,1]-q[:,0,1])-(q[:,1,1]-q[:,0,1])*(q[:,2,0]-q[:,0,0]))*.5
    assert np.all(np.isfinite(q)) and np.all(area2>1e-10),"Degenerate UV"
    valid=(area3>1e-9)&(area2>1e-5)
    dens=np.sqrt(area2[valid]/area3[valid])
    stats[name]={"triangles":len(f),"charts":int(at.chart_count),"slot":list(slot),"pixelArea":float(area2.sum()),"texelsPerStudMedian":float(np.median(dens)),"texelsPerStudP10":float(np.percentile(dens,10)),"texelsPerStudP90":float(np.percentile(dens,90))}
    all_area+=area2.sum();all_tri+=len(f)
    for j,(i,k) in enumerate(pairs):uvs[i][a[f"l{i}"][k]]=q[j]/size
    # True chart boundary: UV vertex split indices, not mesh topology.
    ed=np.sort(np.concatenate([ix[:,[0,1]],ix[:,[1,2]],ix[:,[2,0]]]),axis=1)
    e,cnt=np.unique(ed,axis=0,return_counts=True)
    coords=xy.copy();coords[:,1]=size-coords[:,1]
    for e0,e1 in e[cnt==1]:
        di.line([tuple(coords[e0]),tuple(coords[e1])],fill=(15,15,15,255),width=3)
        dg.line([tuple(coords[e0]),tuple(coords[e1])],fill=(45,45,45),width=2)
    # Rasterize texel centers with a strict interior test. Adjacent triangle
    # boundaries are excluded, so only genuine interior overlaps count.
    for k,t in enumerate(q):
        lo=np.maximum(np.floor(t.min(0)).astype(int),0);hi=np.minimum(np.ceil(t.max(0)).astype(int),size-1)
        if np.any(hi<lo):continue
        X,Y=np.meshgrid(np.arange(lo[0],hi[0]+1)+.5,np.arange(lo[1],hi[1]+1)+.5)
        A,B,C=t;den=(B[1]-C[1])*(A[0]-C[0])+(C[0]-B[0])*(A[1]-C[1])
        if abs(den)<1e-12:continue
        b0=((B[1]-C[1])*(X-C[0])+(C[0]-B[0])*(Y-C[1]))/den
        b1=((C[1]-A[1])*(X-C[0])+(A[0]-C[0])*(Y-C[1]))/den;b2=1-b0-b1
        mask=(b0>1e-6)&(b1>1e-6)&(b2>1e-6)
        if mask.any():
            xx=(X[mask]-.5).astype(int);yy=(Y[mask]-.5).astype(int)
            overlap+=int(np.count_nonzero(raster[yy,xx]));raster[yy,xx]=rid
            wts=np.column_stack([b0[mask],b1[mask],b2[mask]])
            rgb=np.clip(wts@facecol[k],0,1)
            rgb=np.where(rgb<=.0031308,12.92*rgb,1.055*rgb**(1/2.4)-.055)
            base[yy,xx]=np.rint(rgb*255).astype(np.uint8)
        pts=[(float(p[0]),float(size-p[1])) for p in t]
        dw.line(pts+[pts[0]],fill=(25,25,25,150),width=1)
        dg.polygon(pts,fill=palette[rid-1])
    dg.rectangle((x,size-y-h,x+w-1,size-y-1),outline=(95,95,95),width=4)
    dg.text((x+28,size-y-h+24),name,fill=(15,15,15),font=font,stroke_width=2,stroke_fill=(245,245,245))
    print(name,stats[name],flush=True)
assert all(np.isfinite(u).all() for u in uvs.values())
assert overlap==0,("Interior UV texel overlap",overlap)
# Nearest-pixel gutter, restricted to 12 texels. Neutral background for painting.
mask=raster>0;dist,near=ndi.distance_transform_edt(~mask,return_indices=True)
fill=(~mask)&(dist<=12)
base[fill]=base[near[0][fill],near[1][fill]];base[(~mask)&(~fill)]=[128,128,128]
Image.fromarray(base[::-1]).save(out/"rabbit_basecolor_4096.png")
wire.save(out/"rabbit_uv_wire_4096.png");islands.save(out/"rabbit_uv_islands_4096.png")
guide.save(out/"rabbit_uv_regions_4096.png")
for name in ("rabbit_uv_wire","rabbit_uv_islands","rabbit_uv_regions","rabbit_basecolor"):
    im=Image.open(out/(name+"_4096.png"));im.resize((2048,2048),Image.Resampling.LANCZOS).save(out/(name+"_2048.png"))
np.savez_compressed(out/"atlas-output.npz",**{f"uv{i}":uv for i,uv in uvs.items()})
report={"schema":1,"resolution":size,"regions":stats,"triangles":all_tri,"coverage":float(mask.mean()),"interiorOverlappingTexels":overlap,"paddingPixels":12,"uniqueUVs":True,"uvHash":hashlib.sha256((out/"atlas-output.npz").read_bytes()).hexdigest(),"paintingStatus":"provisional base color, artistic painting pending"}
(out/"uv-report.json").write_text(json.dumps(report,indent=2)+"\n");print(json.dumps(report),flush=True)
