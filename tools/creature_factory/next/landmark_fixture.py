"""Independent textured quadruped fixture, deterministic CPU triangle rasterizer.

The exact exported triangle mesh is rasterized, not an implicit ellipsoid.
Texture marker detection is a controlled semantic identity test, not a
learned animal landmark detector. No production assets are touched.
"""
from __future__ import annotations
from pathlib import Path
from dataclasses import asdict
import math,json,sys,struct
import numpy as np
from PIL import Image,ImageDraw
from .contracts import CameraCalibration,AssetManifest,ReferenceView,VIEWS,require
from .audit import write_json,sha256,validate_output,ROOT,REGISTRY,verify_sources
from .cameras import basis
from .hull_alignment import ortho_project
from .landmarks import *

RES=256
DIRECTIONS={"front":(0,-1,0),"back":(0,1,0),"left":(-1,0,0),"right":(1,0,0),"top":(0,0,1),"bottom":(0,0,-1),"three-quarter":(-1,-1,.8)}
# Technical quadruped with distinctly painted coat and asymmetric tail.
# Each landmark is on an actual mesh vertex (longitude/latitude indices).
# Anatomical left is +X for an animal facing -Y; camera view names are separate.
PARTS=[
 ("torso",(0,.15,1.13),(.63,1.05,.57),None),
 ("neck",(0,-.57,1.36),(.38,.49,.51),None),
 ("head",(0,-.98,1.65),(.46,.49,.43),None),
 ("muzzle",(0,-1.36,1.49),(.33,.34,.25),None),
 ("right_ear",(-.29,-1.0,2.12),(.16,.22,.43),None),
 ("left_ear",(.29,-1.0,2.09),(.16,.22,.40),None),
 ("right_foreleg",(-.39,-.55,.53),(.20,.25,.60),None),
 ("left_foreleg",(.39,-.55,.53),(.20,.25,.60),None),
 ("right_hindleg",(-.42,.75,.53),(.25,.30,.60),None),
 ("left_hindleg",(.42,.75,.53),(.25,.30,.60),None),
 ("right_paw",(-.39,-.65,.12),(.23,.35,.15),None),
 ("left_paw",(.39,-.65,.12),(.23,.35,.15),None),
 ("right_hindpaw",(-.42,.66,.12),(.27,.34,.15),None),
 ("left_hindpaw",(.42,.66,.12),(.27,.34,.15),None),
 ("tail",(.23,1.22,1.42),(.26,.44,.28),None)]
# Longitude u=0 along +X, u=.25 along +Y; latitude v=0 north.
# Deliberately use surface points rather than internal joint centers.
MARKS=[
 ("right_brow","head","right",20,6,(245,25,35)),
 ("left_brow","head","left",28,6,(25,235,50)),
 ("nose_tip","muzzle","midline",24,7,(35,80,245)),
 ("right_ear_outer","right_ear","right",20,4,(245,225,20)),
 ("left_ear_outer","left_ear","left",28,4,(225,30,235)),
 ("right_shoulder_surface","torso","right",19,6,(25,235,235)),
 ("left_shoulder_surface","torso","left",29,6,(245,110,20)),
 ("right_forepaw_outer","right_paw","right",20,5,(115,35,245)),
 ("left_forepaw_outer","left_paw","left",28,5,(35,245,140)),
 ("right_hip_surface","torso","right",12,6,(245,35,135)),
 ("left_hip_surface","torso","left",4,6,(140,245,35)),
 ("tail_outer","tail","left",4,5,(35,150,245))]
NU=32;NV=16;TEX=128
def sphere(center,radii):
    u=np.arange(NU+1)/NU;v=np.arange(NV+1)/NV
    uu,vv=np.meshgrid(u,v)
    theta=2*np.pi*uu;phi=np.pi*vv
    p=np.stack([np.sin(phi)*np.cos(theta),np.sin(phi)*np.sin(theta),np.cos(phi)],-1)
    xyz=p*np.asarray(radii)+np.asarray(center);norm=p/np.asarray(radii);norm/=np.linalg.norm(norm,axis=-1,keepdims=True)
    uv=np.stack([uu,vv],-1);faces=[]
    for j in range(NV):
        for i in range(NU):
            a=j*(NU+1)+i;b=a+1;c=a+NU+1;d=c+1
            if j>0:faces.append((a,c,b))
            if j<NV-1:faces.append((b,c,d))
    return xyz.reshape(-1,3),norm.reshape(-1,3),uv.reshape(-1,2),np.asarray(faces,np.int32)
def texture(name,marks):
    y,x=np.mgrid[:TEX,:TEX];u=(x+.5)/TEX;v=(y+.5)/TEX
    wave=.5+.5*np.sin(2*np.pi*(3*u+1.6*v))
    coat=np.stack([135+32*wave,83+22*wave,48+15*wave],-1)
    if "paw" in name or name=="muzzle":coat=coat*.5+np.array([105,100,88])
    natural=np.rint(coat).astype(np.uint8);marked=natural.copy()
    for _,part,_,i,j,color in marks:
        if part!=name:continue
        du=np.minimum(abs(u-i/NU),1-abs(u-i/NU));dv=abs(v-j/NV)
        # Small painted UV patch centered on the actual semantic vertex.
        patch=(du/.037)**2+(dv/.047)**2<=1
        marked[patch]=color
    return natural,marked
def camera(direction):
    b=np.asarray(direction,float);b/=np.linalg.norm(b);up=np.array([0,0,1.]) if abs(b[2])<.95 else np.array([0,1.,0])
    r=np.cross(up,b);r/=np.linalg.norm(r);u=np.cross(b,r);t=np.array([0,0,1.15])+b*8
    return CameraCalibration("known","orthographic",np.column_stack([r,u,b,t]).tolist()+[[0,0,0,1]],4.6,confidence=1)
def raster(parts,c,marked=True):
    depth=np.full((RES,RES),np.inf);rgb=np.zeros((RES,RES,4),np.uint8);ids=np.full((RES,RES),-1,np.int16)
    normal=np.zeros((RES,RES,3),np.float32);light=np.array([-.5,-.7,.8]);light/=np.linalg.norm(light)
    for pi,p in enumerate(parts):
        xyz,n,uv,f,natural,paint=p
        x,y,z=ortho_project(xyz,c,(RES,RES));xy=np.column_stack([x,y])
        for tri in f:
            a,b,d=xy[tri];lo=np.maximum(np.floor(np.min([a,b,d],axis=0)).astype(int),0);hi=np.minimum(np.ceil(np.max([a,b,d],axis=0)).astype(int),RES-1)
            if (hi<lo).any():continue
            det=(b[0]-a[0])*(d[1]-a[1])-(b[1]-a[1])*(d[0]-a[0])
            if abs(det)<1e-9:continue
            yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];px=xx+.5-a[0];py=yy+.5-a[1]
            s=(px*(d[1]-a[1])-py*(d[0]-a[0]))/det;t=((b[0]-a[0])*py-(b[1]-a[1])*px)/det
            weights=np.stack([1-s-t,s,t],-1);zz=weights@z[tri]
            valid=(weights>=-1e-7).all(-1)&(zz<depth[yy,xx])
            if not valid.any():continue
            iy,ix=yy[valid],xx[valid];w=weights[valid];depth[iy,ix]=zz[valid];ids[iy,ix]=pi
            tuv=w@uv[tri];tx=np.minimum((tuv[:,0]*TEX).astype(int),TEX-1);ty=np.minimum((tuv[:,1]*TEX).astype(int),TEX-1)
            nn=w@n[tri];nn/=np.maximum(np.linalg.norm(nn,axis=-1,keepdims=True),1e-9);normal[iy,ix]=nn
            colors=(paint if marked else natural)[ty,tx].astype(float)
            if not marked:colors*=np.clip(.55+.45*(nn@light),.35,1)[:,None]
            rgb[iy,ix,:3]=np.rint(colors).clip(0,255).astype(np.uint8);rgb[iy,ix,3]=255
    mask=np.isfinite(depth);depth[~mask]=0
    return rgb,depth.astype(np.float32),mask,normal,ids

def export_glb(parts,out):
    """Exact triangles and PNG textures exported through a real GLB writer."""
    import trimesh
    scene=trimesh.Scene()
    for i,(xyz,n,uv,f,natural,paint) in enumerate(parts):
        # glTF texture coordinates use top-left image origin; trimesh UV is
        # bottom-left, so flip once at the adapter boundary.
        visual=trimesh.visual.texture.TextureVisuals(uv=np.column_stack([uv[:,0],1-uv[:,1]]),image=Image.fromarray(paint))
        mesh=trimesh.Trimesh(vertices=xyz,faces=f,vertex_normals=n,visual=visual,process=False)
        scene.add_geometry(mesh,node_name=PARTS[i][0],geom_name=PARTS[i][0])
    out.write_bytes(scene.export(file_type="glb"))
    check=trimesh.load(out,force="scene",process=False)
    require(sum(len(m.faces) for m in check.geometry.values())==sum(len(p[3]) for p in parts),"GLB face count changed")

def marker_observations(rgb,mask,view,hashes):
    # Exact palette detector on the unlit painted texture pass. Missing
    # marker is unknown, not automatically occluded.
    rows=[]
    for ident,part,side,i,j,color in MARKS:
        hit=mask&(rgb[:,:,:3]==np.asarray(color)).all(-1);y,x=np.where(hit)
        if len(x)<5:
            rows.append(LandmarkObservation(ident,view,"unknown","fixture_marker_detector",0,None,hashes[view]));continue
        # Use the marked pixel closest to centroid, preventing an off-mask
        # centroid in the case of disconnected/partially occluded patches.
        cx,cy=x.mean()+.5,y.mean()+.5;k=np.argmin((x+.5-cx)**2+(y+.5-cy)**2)
        rows.append(LandmarkObservation(ident,view,"visible","fixture_marker_detector",.95,[float(x[k]+.5),float(y[k]+.5)],hashes[view]))
    return rows

def run(out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preserve=verify_sources(ROOT,json.loads(REGISTRY.read_text()))
    parts=[]
    for name,center,radii,_ in PARTS:
        xyz,n,uv,f=sphere(center,radii);natural,paint=texture(name,MARKS)
        parts.append((xyz,n,uv,f,natural,paint))
        Image.fromarray(paint).save(out/(name+"-texture.png"))
    export_glb(parts,out/"fixture.glb")
    points={i:parts[[p[0] for p in PARTS].index(part)][0][j*(NU+1)+u] for i,part,side,u,j,color in MARKS}
    defs=[LandmarkDefinition(i,part,side,description="Fixed painted surface vertex in technical quadruped") for i,part,side,u,j,c in MARKS]
    views={};hashes={};obs=[];truth=[];metrics={};images={};plain={}
    for name,d in DIRECTIONS.items():
        c=camera(d);rgb,depth,mask,norm,ids=raster(parts,c,True);natural,_,_,_,_=raster(parts,c,False)
        Image.fromarray(rgb).save(out/(name+"-painted.png"));Image.fromarray(natural).save(out/(name+"-natural.png"))
        hashes[name]=sha256(out/(name+"-painted.png"));views[name]=(mask,c);images[name]=rgb;plain[name]=natural
        np.savez_compressed(out/(name+"-geometry.npz"),depth=depth,mask=mask,normals=norm)
        rows=marker_observations(rgb,mask,name,hashes);obs.extend(rows)
        for o in rows:
            p=points[o.landmark_id];x,y,z=ortho_project(p,c,mask.shape);ix,iy=int(x),int(y)
            # Exact triangle z-buffer + one-pixel discretization allowance.
            visible=0<=ix<RES and 0<=iy<RES and mask[iy,ix] and abs(float(depth[iy,ix])-z)<.055
            truth.append({"landmark_id":o.landmark_id,"view_id":name,"visible":bool(visible),"xy":[float(x),float(y)] if visible else None,"depth":float(z) if visible else None})
            if o.xy is not None:
                err=float(np.hypot(o.xy[0]-x,o.xy[1]-y));metrics[o.landmark_id+"/"+name]={"pixel_error":err,"center_visible":bool(visible)}
    bundle=LandmarkBundle("technical-quadruped",defs,obs);solved=solve_landmarks(bundle,views,hashes,3.0)
    # Ground truth is separate from detector/solver inputs. Compare actual
    # triangulated positions only after the solve.
    for ident,r in solved.items():
        if "point" in r:r["world_error"]=float(np.linalg.norm(np.asarray(r["point"])-points[ident]))
    accepted=[r for r in solved.values() if r["status"]=="heldout_consistent"]
    require(len(accepted)>=3,"Marker identity/held-out triangulation did not pass")
    require(max(r["world_error"] for r in accepted)<.12,"Triangulated marker world error")
    require(not any(r["metric_candidate"] for r in solved.values()),"Fixture marker must not be promoted to reviewed production")
    # Explicit wrong-identity test: replace one held-out observation with
    # another visible landmark in same view; fit remains unchanged.
    probes=[]
    for ident,r in solved.items():
        if r["status"]!="heldout_consistent":continue
        target=next(iter(r["heldout_reprojection"]));original=next(o for o in obs if o.landmark_id==ident and o.view_id==target)
        options=[o for o in obs if o.view_id==target and o.landmark_id!=ident and o.xy and np.linalg.norm(np.asarray(o.xy)-original.xy)>12]
        if not options:continue
        other=options[0];modified=[LandmarkObservation(o.landmark_id,o.view_id,o.visibility,o.source,o.confidence,other.xy,o.reference_sha256) if o is original else o for o in obs]
        result=solve_landmarks(LandmarkBundle(bundle.asset_id,defs,modified),views,hashes,3.0)[ident]
        probes.append({"landmark":ident,"replaced_with":other.landmark_id,"view":target,"status":result["status"]})
    require(probes and all(p["status"]=="heldout_rejected" for p in probes),"Wrong-identity control not rejected")
    write_json(out/"landmarks.json",asdict(bundle));write_json(out/"truth.json",{"points":{k:v.tolist() for k,v in points.items()},"observations":truth})
    # One seven-view reference sheet, with hash bound to actual PNG.
    sheet=Image.new("RGBA",(RES*4,RES*2));review=Image.new("RGB",(RES*4,RES*2+48),(235,235,235));draw=ImageDraw.Draw(review)
    for k,name in enumerate(VIEWS):
        x,y=(k%4)*RES,(k//4)*RES;sheet.paste(Image.fromarray(images[name]),(x,y))
        bg=Image.new("RGBA",(RES,RES),(228,232,235,255));bg.alpha_composite(Image.fromarray(plain[name]));review.paste(bg.convert("RGB"),(x,y+24*(k//4+1)));draw.text((x+5,y+24*(k//4)+4),name,fill=(20,20,20))
        for o in obs:
            if o.view_id==name and o.xy:
                px,py=o.xy;px+=x;py+=y+24*(k//4+1);draw.ellipse((px-3,py-3,px+3,py+3),outline=(30,80,220),width=2)
    sheet.save(out/"references.png");review.save(out/"landmark-review.png")
    manifest=AssetManifest("technical-quadruped","creature",[ReferenceView(n,"references.png",sha256(out/"references.png"),[(k%4)*RES,(k//4)*RES,RES,RES],views[n][1]) for k,n in enumerate(VIEWS)],units="unit",symmetry="intentional_asymmetry",parts=[{"id":p[0]} for p in PARTS],landmarks=[asdict(d) for d in defs],identity={"fixture":True,"not_artistic":True})
    write_json(out/"manifest.json",asdict(manifest))
    report={"schema":1,"status":"fixture_landmarks_validated","definitions":len(defs),"views":len(views),"observations":len(obs),"detected":sum(o.xy is not None for o in obs),"accepted":len(accepted),"max_accepted_world_error":max(r["world_error"] for r in accepted),"solved":solved,"wrong_identity_probes":probes,"detection_metrics":metrics,"triangles":sum(len(p[3]) for p in parts),"preservation":preserve,"limitations":["Technical ellipsoid-part quadruped, not a production model.","Marker detector reads explicit painted IDs, not natural anatomical features.","No learned semantic inference or rabbit calibration claimed.","Surface visibility scoring uses raster depth tolerance; no hidden joints treated as observed."]}
    write_json(out/"report.json",report);print(json.dumps({k:report[k] for k in ("status","definitions","views","detected","accepted","max_accepted_world_error","wrong_identity_probes")}),flush=True)
if __name__=="__main__":run(Path(sys.argv[1]))
