"""C2-A: alpha-derived foreground evidence, preserving holes and thin parts.
No learned anatomy, depth or calibrated probability is claimed.
"""
from __future__ import annotations
from pathlib import Path
import json, math
from PIL import Image,ImageDraw
from .audit import write_json,sha256
from .contracts import require,path_inside,VIEWS

def components(mask):
    """4-connected run-length union-find; retain every component."""
    w,h=mask.size;data=mask.tobytes();parent=[];areas=[];previous=[]
    def root(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    def union(i,j):
        i,j=root(i),root(j)
        if i!=j:parent[j]=i;areas[i]+=areas[j]
    for y in range(h):
        row=data[y*w:(y+1)*w];runs=[];x=0
        while x<w:
            if not row[x]:x+=1;continue
            start=x
            while x<w and row[x]:x+=1
            i=len(parent);parent.append(i);areas.append(x-start);runs.append((start,x,i))
        j=0
        for a,b,i in runs:
            while j<len(previous) and previous[j][1]<=a:j+=1
            k=j
            while k<len(previous) and previous[k][0]<b:
                union(i,previous[k][2]);k+=1
        previous=runs
    return sorted((areas[i] for i in range(len(parent)) if parent[i]==i),reverse=True)

def analyze_alpha(im,threshold=16):
    require(im.mode=="RGBA","RGBA input required")
    require(type(threshold)==int and 1<=threshold<=254,"Alpha threshold must be 1..254")
    alpha=im.getchannel("A");w,h=im.size
    require(w*h<=16_777_216,"View exceeds C2 pixel resource guardrail")
    mask=alpha.point(lambda a:255 if a>=threshold else 0)
    bbox=mask.getbbox();require(bbox is not None,"Empty foreground")
    count=mask.histogram()[255];require(count<w*h,"No transparent background")
    sizes=components(mask);require(sum(sizes)==count,"Component accounting mismatch")
    counts={str(t):sum(alpha.histogram()[t:]) for t in (1,16,64,128,192,254)}
    # Alpha is source coverage, not an empirically calibrated probability.
    # Preserve exact pixels and record uncertainty from partial opacity.
    partial=sum(alpha.histogram()[1:255])
    x0,y0,x1,y1=bbox
    return mask,alpha,{"size":[w,h],"bbox":list(bbox),"foreground_pixels":count,"components":len(sizes),"component_pixels":sizes,
        "touches_edge":x0==0 or y0==0 or x1==w or y1==h,"partial_alpha_pixels":partial,"threshold_counts":counts,
        "threshold":threshold,"coverage_semantics":"source alpha coverage; not learned or calibrated confidence"}

def segment(m,source,out,cfg,inputs):
    src=inputs["reference_ready"];threshold=cfg.get("alpha_threshold",16)
    reports={};tiles=[]
    for v in m.views:
        p=src[v.id+".png"]
        with Image.open(p) as original:im=original.convert("RGBA")
        mask,alpha,r=analyze_alpha(im,threshold);r["source_sha256"]=sha256(p)
        mask.save(out/(v.id+"-mask.png"));alpha.save(out/(v.id+"-alpha.png"))
        reports[v.id]=r
        thumb=im.copy();thumb.thumbnail((180,180));tile=Image.new("RGB",(360,210),(225,230,235));draw=ImageDraw.Draw(tile);draw.text((5,4),v.id,fill=(15,15,15))
        tile.paste(thumb,((180-thumb.width)//2,22+(180-thumb.height)//2),thumb.getchannel("A"))
        mt=mask.copy();mt.thumbnail((180,180),Image.Resampling.NEAREST);tile.paste(mt.convert("RGB"),(180+(180-mt.width)//2,22+(180-mt.height)//2))
        tiles.append(tile)
    sheet=Image.new("RGB",(720,210*((len(tiles)+1)//2)),(242,242,242))
    for i,t in enumerate(tiles):sheet.paste(t,(360*(i%2),210*(i//2)))
    sheet.save(out/"segmentation-review.png")
    report={"schema":1,"status":"segmented","views":reports,"limitations":["Only source alpha used; no learned part segmentation or depth.","All connected components retained; touching edges and alpha sensitivity require review."]}
    write_json(out/"segmentation.json",report)
    return {"views":len(reports),"edge_touches":sum(r["touches_edge"] for r in reports.values()),"scope":"foreground evidence only"}
