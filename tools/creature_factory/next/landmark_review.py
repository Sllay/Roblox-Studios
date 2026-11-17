"""Generic review of explicit landmark proposals on a prior C2 job.
No semantic detector or camera recalibration is implied."""
from pathlib import Path
import json,sys
import numpy as np
from PIL import Image,ImageDraw
from .contracts import CameraCalibration,path_inside,require
from .audit import sha256,write_json,validate_output
from .landmarks import LandmarkBundle,solve_landmarks
def run(job,bundlepath,out):
    job=Path(job).resolve();out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    state=json.loads((job/"job.json").read_text())
    def files(stage):
        result={}
        for p,h in state["stages"][stage]["outputs"].items():
            q=path_inside(job,p);require(sha256(q)==h,"Evidence changed");result[q.name]=q
        return result
    refs=files("reference_ready");seg=files("segmentation_ready");cal=json.loads(files("calibration_ready")["calibration.json"].read_text())
    bundle=LandmarkBundle.from_dict(json.loads(Path(bundlepath).read_text()))
    require(bundle.asset_id==state["asset_id"],"Asset identity mismatch")
    views={};hashes={};images={}
    for n,r in cal["views"].items():
        p=refs[n+".png"];hashes[n]=sha256(p);images[n]=Image.open(p).convert("RGBA");views[n]=(np.asarray(Image.open(seg[n+"-core-mask.png"]))>0,CameraCalibration(**r["camera"]))
    solved=solve_landmarks(bundle,views,hashes)
    require(not any(r["metric_candidate"] for r in solved.values()),"Unreviewed proposal promoted")
    names=list(images);size=300;height=530
    panel=Image.new("RGB",(size*len(names),height),(237,239,240));draw=ImageDraw.Draw(panel)
    colors=[(25,110,205),(230,77,42),(0,155,95),(133,70,185),(208,143,24),(44,150,160)]
    for i,n in enumerate(names):
        im=images[n].copy();w,h=im.size;im.thumbnail((size-16,height-100));bg=Image.new("RGBA",im.size,(225,229,233,255));bg.alpha_composite(im)
        x=i*size+(size-im.width)//2;y=30;panel.paste(bg.convert("RGB"),(x,y));draw.text((i*size+8,8),n+" / "+views[n][1].status,fill=(20,20,20))
        for j,d in enumerate(bundle.definitions):
            o=next((o for o in bundle.observations if o.landmark_id==d.id and o.view_id==n and o.xy is not None),None)
            if o is None:continue
            xx=x+o.xy[0]*im.width/w;yy=y+o.xy[1]*im.height/h;c=colors[j%len(colors)]
            draw.ellipse((xx-4,yy-4,xx+4,yy+4),outline=c,width=2);draw.text((xx+5,yy-5),str(j+1),fill=c,stroke_width=1,stroke_fill="white")
        for j,d in enumerate(bundle.definitions):
            draw.text((i*size+8,height-90+j*14),str(j+1)+" "+d.id,fill=colors[j%len(colors)])
    panel.save(out/"rabbit-landmark-proposals.png")
    write_json(out/"report.json",{"schema":1,"status":"unreviewed_landmark_diagnostic","asset_id":bundle.asset_id,"solved":solved,"metric_fusion_allowed":False,"limitations":["Coordinates are visual annotation proposals, not automated detection or user-approved semantic identity.","Estimated cameras and drawn contours do not guarantee physical correspondence.","Region landmarks and unknown cameras are not triangulated as surface anchors."]})
    print(json.dumps(solved),flush=True)
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
