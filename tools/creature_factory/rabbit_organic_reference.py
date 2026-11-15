"""Rabbit V2: pixel-conditioned silhouette reconstruction, anatomical relief, audit.
The approved sheet is an illustration, not calibrated photographs. This is a
reference-constrained sculpt candidate, not a claim of exact 3D reconstruction.
Coordinates in the landmark map are on a 1000x1000 copy of the original sheet.
"""
import argparse, hashlib, json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from skimage.measure import marching_cubes

ROOT=Path(__file__).resolve().parents[2]
REF=ROOT/"asset-library/references/rabbit-v1"
HEIGHT=3.6
PANELS={"front":(0,0,250,475),"right":(250,0,500,475),
        "left":(500,0,750,475),"back":(750,0,1000,475)}
# "right" = camera +X (nose left); "left" = camera -X (nose right).
SIGN={"front":1,"back":-1,"right":1,"left":-1}
AXIS={"front":0,"back":0,"right":1,"left":1}
def disk(n):
    y,x=np.ogrid[-n:n+1,-n:n+1];return x*x+y*y<=n*n
def checked():
    manifest=json.loads((REF/"manifest.json").read_text())
    for r in manifest["references"].values():
        assert hashlib.sha256((REF/r["path"]).read_bytes()).hexdigest()==r["sha256"]
    assert manifest["status"]=="approved-design-references-verified"
    return manifest
def panel_data():
    checked()
    im=Image.open(REF/"views.png").convert("RGBA").resize((1000,1000),Image.Resampling.LANCZOS)
    masks={}; colors={}; maps={}; raw={}
    for k,box in PANELS.items():
        a=np.array(im.crop(box)); raw[k]=a
        m=ndi.binary_opening(a[:,:,3]>110,structure=disk(2))
        m=ndi.binary_fill_holes(ndi.binary_closing(m,structure=disk(2)))
        labels,n=ndi.label(m)
        sizes=np.bincount(labels.ravel());sizes[0]=0
        assert n and sizes.max()>10000,(k,sizes.max())
        m=labels==sizes.argmax()
        yy,xx=np.where(m); low,high=int(yy.min()),int(yy.max())
        scale=HEIGHT/(high-low)
        maps[k]={"box":list(box),"center":float((xx.min()+xx.max())/2),
                 "bottom":high,"top":low,"scale":scale,"axis":AXIS[k],"sign":SIGN[k]}
        near=ndi.distance_transform_edt(~m,return_distances=False,return_indices=True)
        colors[k]=a[near[0],near[1],:3]
        masks[k]=m
    return masks,colors,maps,raw
def poly_map(key,regions):
    box=PANELS[key]; w=box[2]-box[0];h=box[3]-box[1]
    d=np.zeros((h,w),np.float32)
    for points,depth,sigma in regions:
        im=Image.new("L",(w,h));ImageDraw.Draw(im).polygon([(x-box[0],y-box[1]) for x,y in points],fill=255)
        d+=depth*ndi.gaussian_filter(np.asarray(im,dtype=np.float32)/255,sigma)
    return d
# These are anatomical landmark regions traced against the approved multiview.
# Positive depth raises the surface, negative depth carves it. No part primitives.
FRONT=[
 ([(55,36),(76,37),(102,79),(118,148),(94,132),(68,98)],-.105,4),
 ([(151,148),(160,85),(188,39),(202,35),(196,101),(171,140)],-.105,4),
 ([(80,162),(95,150),(112,165),(117,189),(103,200),(84,193)],-.050,3),
 ([(145,165),(160,150),(176,162),(180,191),(161,201),(145,190)],-.050,3),
 ([(89,166),(101,163),(110,177),(106,191),(94,192),(87,182)],.085,2),
 ([(151,165),(165,163),(174,176),(169,191),(155,192),(148,180)],.085,2),
 ([(97,198),(120,192),(130,204),(129,226),(112,236),(94,226)],.105,4),
 ([(131,204),(143,193),(164,199),(170,225),(146,237),(132,226)],.105,4),
 ([(119,198),(143,198),(139,209),(131,215),(123,210)],.070,2),
 ([(129,212),(133,212),(135,227),(145,231),(143,234),(130,228),(118,234),(117,231),(128,226)],-.065,1.6),
 ([(68,201),(87,199),(92,213),(80,229),(69,226),(61,219)],.047,3),
 ([(175,199),(190,201),(200,218),(191,230),(177,224),(170,212)],.047,3),
 ([(95,250),(126,245),(164,252),(158,286),(130,315),(108,288)],.052,5),
 ([(78,277),(100,280),(117,310),(123,352),(110,365),(94,350),(77,318)],.155,5),
 ([(161,278),(181,281),(188,313),(169,349),(151,365),(137,353),(145,311)],.155,5),
 ([(118,314),(126,324),(129,359),(123,370),(116,350)],-.063,3),
 ([(134,324),(142,314),(147,351),(139,369),(132,358)],-.063,3),
 ([(40,324),(69,309),(92,336),(92,382),(75,415),(49,402),(34,365)],.082,5),
 ([(171,337),(192,309),(216,326),(224,364),(205,405),(184,415),(168,381)],.082,5),
 ([(53,430),(58,429),(62,458),(56,458)],-.036,1.5),
 ([(75,430),(80,430),(82,459),(76,460)],-.036,1.5),
 ([(174,430),(179,429),(180,459),(174,459)],-.036,1.5),
 ([(196,429),(202,430),(205,458),(199,459)],-.036,1.5),
 ([(104,343),(108,343),(110,362),(105,361)],-.025,1.2),
 ([(150,343),(154,343),(156,361),(151,362)],-.025,1.2),
]
SIDE=[
 ([(339,79),(355,40),(388,24),(400,49),(393,91),(363,154),(346,169)],-.075,5),
 ([(292,160),(310,154),(331,167),(335,188),(320,200),(296,192)],-.048,3),
 ([(300,165),(314,163),(326,173),(324,190),(310,194),(299,185)],.065,2),
 ([(272,199),(302,196),(325,207),(319,228),(293,240),(273,224)],.065,4),
 ([(350,197),(389,192),(407,209),(397,232),(376,244),(347,237)],.055,5),
 ([(300,250),(329,245),(354,260),(358,288),(332,314),(308,306)],.068,5),
 ([(292,302),(314,291),(338,312),(327,346),(302,366),(285,352)],.115,4),
 ([(335,321),(375,307),(414,318),(438,355),(425,394),(396,419),(356,410),(330,377)],.105,7),
 ([(324,335),(331,320),(347,313),(358,315),(337,334),(329,357)],-.047,3),
 ([(341,410),(362,418),(400,414),(419,404),(425,415),(403,428),(351,430)],-.042,3),
 ([(439,322),(458,304),(478,310),(482,345),(470,371),(449,385)],.040,4),
]
BACK=[
 ([(853,310),(881,298),(907,313),(919,345),(908,379),(880,393),(852,376),(840,347)],.16,5),
 ([(835,329),(842,330),(844,373),(854,391),(847,397),(835,376)],-.045,3),
 ([(913,330),(921,329),(924,369),(914,392),(906,394),(915,375)],-.045,3),
]
def runs(row):
    p=np.flatnonzero(np.diff(np.r_[False,row,False].astype(np.int8)))
    return [(a,b-1) for a,b in zip(p[::2],p[1::2]) if b-a>=4]
def world_row(maps,k,z):
    a=maps[k];return int(round(a["bottom"]-z/a["scale"]))
def intervals(masks,maps,k,z):
    a=maps[k];r=world_row(maps,k,z)
    if r<0 or r>=masks[k].shape[0]: return []
    return [tuple(sorted(((u-a["center"])*a["scale"]*a["sign"],(v-a["center"])*a["scale"]*a["sign"]))) for u,v in runs(masks[k][r])]
def sample_line(d,maps,k,z,axis):
    a=maps[k];r=world_row(maps,k,z)
    if r<0 or r>=d.shape[0]:return np.zeros_like(axis)
    u=a["center"]+axis*a["sign"]/a["scale"]
    return np.interp(u,np.arange(d.shape[1]),d[r],left=0,right=0)
def reconstruct(out):
    masks,colors,maps,_=panel_data()
    front=poly_map("front",FRONT);side=poly_map("right",SIDE);back=poly_map("back",BACK)
    # Reflected side relief is independently mapped to the opposite side.
    step=.016
    xs=np.arange(-1.1,1.101,step);ys=np.arange(-1.25,1.251,step);zs=np.arange(-.08,HEIGHT+.081,step)
    X=xs[:,None];Y=ys[None,:]
    field=np.full((len(zs),len(xs),len(ys)),-4,np.float32)
    for iz,z in enumerate(zs):
        fx=intervals(masks,maps,"front",z);sy=intervals(masks,maps,"right",z)
        if not fx or not sy:continue
        fd=sample_line(front,maps,"front",z,xs)[:,None]
        bd=sample_line(back,maps,"back",z,xs)[:,None]
        sd=sample_line(side,maps,"right",z,ys)[None,:]
        for xa,xb in fx:
            for ya,yb in sy:
                cx=(xa+xb)/2;cy=(ya+yb)/2
                rx=max((xb-xa)/2,step);ry=max((yb-ya)/2,step)
                qx=X-cx;qy=Y-cy
                # The continuous rounded cross-section is derived from pixel intervals.
                # Anatomical relief is local and smoothly fades into the surface.
                xf=qx-np.sign(qx)*sd*np.clip(np.abs(qx)/(rx*.75),0,1)
                yf=qy+fd*np.clip(-qy/(ry*.75),0,1)-bd*np.clip(qy/(ry*.75),0,1)
                v=1-(xf/rx)**2-(yf/ry)**2
                field[iz]=np.maximum(field[iz],v.astype(np.float32))
    field=ndi.gaussian_filter(np.maximum(field,-4),.9)
    labels,n=ndi.label(field>0);sizes=np.bincount(labels.ravel());sizes[0]=0
    assert n and sizes.max()>10000,"No coherent volume"
    field[(labels!=0)&(labels!=sizes.argmax())]=-1
    v,f,_,_=marching_cubes(field,level=0,spacing=(step,step,step),allow_degenerate=False)
    v=v[:,[1,2,0]]+np.array([xs[0],ys[0],zs[0]])
    # Reorient after coordinate permutation; Blender independently recalculates normals.
    out.mkdir(parents=True,exist_ok=True)
    np.savez_compressed(out/"reconstruction.npz",vertices=v.astype(np.float32),faces=f.astype(np.int32),
        **{"color_"+k:colors[k] for k in colors},**{"mask_"+k:masks[k] for k in masks})
    (out/"calibration.json").write_text(json.dumps({"height":HEIGHT,"maps":maps,"source":checked()["references"],
      "method":"pixel intervals + rounded cross-sections + traced anatomical relief","landmarkRegions":len(FRONT)+len(SIDE)+len(BACK),
      "masterVertices":len(v),"masterTriangles":len(f)},indent=2)+"\n")
    print("master",len(v),len(f),flush=True)
def audit(out):
    masks,_,maps,raw=panel_data()
    data=np.load(out/"runtime-mesh.npz");v=data["vertices"];f=data["faces"]
    results={}
    for k,a in maps.items():
        u=a["center"]+a["sign"]*v[:,a["axis"]]/a["scale"]
        p=np.column_stack([u,a["bottom"]-v[:,2]/a["scale"]])
        im=Image.new("1",(250,475));dr=ImageDraw.Draw(im)
        for tri in f:dr.polygon([tuple(q) for q in p[tri]],fill=1)
        pred=np.asarray(im,dtype=bool);ref=masks[k]
        iou=float((pred&ref).sum()/(pred|ref).sum())
        results[k]={"iou":round(iou,5),"referencePixels":int(ref.sum()),"candidatePixels":int(pred.sum())}
        bg=np.full((475,250,3),238,np.uint8)
        alpha=raw[k][:,:,3:4]/255
        bg=(raw[k][:,:,:3]*alpha+bg*(1-alpha)).astype(np.uint8)
        # cyan candidate boundary, red reference boundary; no whiskers in mask comparison
        re=ref^ndi.binary_erosion(ref);pe=pred^ndi.binary_erosion(pred)
        bg[re]=(220,60,50);bg[pe]=(0,185,215);bg[re&pe]=(80,210,90)
        Image.fromarray(bg).save(out/("overlay-"+k+".png"))
    passed=all(results[k]["iou"]>=t for k,t in {"front":.86,"right":.82,"left":.78,"back":.78}.items())
    report=json.loads((out/"report.json").read_text())
    report["silhouetteAudit"]=results;report["silhouetteGatePassed"]=passed
    report["state"]="needs_visual_review" if passed else "needs_geometry_revision"
    (out/"report.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report),flush=True)
    return passed
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("mode",choices=["build","audit"]);p.add_argument("out",type=Path);a=p.parse_args()
    if a.mode=="build":reconstruct(a.out)
    else:raise SystemExit(0 if audit(a.out) else 2)
