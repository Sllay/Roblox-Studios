"""Plan and verify bounded native Roblox terrain. Staging only; never clear Terrain."""
from __future__ import annotations
import argparse,json,math,os,sys
from pathlib import Path
from cloud_tasks import run_task
from deploy import load_all,resolve,WorkspaceError
from scene_snapshot import canonical,capture,compare,ROOT
SOURCE=ROOT/"tools/terrain/builder.luau"

def number(v,lo,hi):
    return type(v) in (int,float) and math.isfinite(v) and lo<=v<=hi

def require(ok,message):
    if not ok:raise WorkspaceError(message)

def validate(p):
    require(p.get("schemaVersion")==1,"Terrain schema version")
    b=p["bounds"]
    require(isinstance(b,list) and len(b)==6 and all(type(x) is int and x%4==0 and abs(x)<=10000 for x in b),"Aligned bounds required")
    dx,dy,dz=[b[i+3]-b[i] for i in range(3)]
    require(16<=dx<=512 and 16<=dy<=128 and 16<=dz<=512 and dx*dy*dz//64<=262144,"Voxel budget exceeded")
    require(type(p["seed"]) is int and 0<=p["seed"]<=100000,"Invalid seed")
    for k,lo,hi in [("baseHeight",b[1]+4,b[4]-4),("edgeHeight",b[1]+4,b[4]-4),("edgeBlend",8,128),("minSolidDepth",4,32),("surfaceDepth",4,16),("soilDepth",8,64)]:
        require(number(p[k],lo,hi),"Invalid "+k)
    require(p["soilDepth"]>=p["surfaceDepth"],"Soil depth")
    layers=p["noiseLayers"]
    require(isinstance(layers,list) and 1<=len(layers)<=6,"Noise layer count")
    for layer in layers:
        for k,lo,hi in [("wavelength",8,2048),("amplitude",0,64),("octaves",1,6),("lacunarity",1,4),("persistence",0,1),("seedOffset",-10000,10000)]:
            require(number(layer[k],lo,hi),"Invalid noise "+k)
        require(type(layer["octaves"]) is int,"Octaves integer")
    w=p["warp"]
    require(number(w["amplitude"],0,32) and number(w["wavelength"],16,1024),"Warp parameters")
    l=p["lake"]
    require(len(l["center"])==2 and all(number(v,-10000,10000) for v in l["center"]),"Lake center")
    for k,lo,hi in [("radius",16,128),("depth",8,64),("level",b[1]+12,b[4]-8),("bankWidth",8,64),("bankRise",4,24),("blendWidth",8,64),("sandWidth",4,32),("irregularity",0,0.2)]:
        require(number(l[k],lo,hi),"Invalid lake "+k)
    require(l["level"]-l["depth"]>=b[1]+p["minSolidDepth"],"Lake bottom lacks solid foundation")
    require(l["level"]+l["bankRise"]<=b[4]-4,"Lake rim exceeds vertical bounds")
    margin=l["radius"]*(1+2*l["irregularity"])+l["bankWidth"]+l["blendWidth"]+4
    x,z=l["center"]
    require(b[0]+margin<=x<=b[3]-margin and b[2]+margin<=z<=b[5]-margin,"Lake too near boundary")
    require(l["sandWidth"]<=l["bankWidth"],"Sand outside bank")
    path=p["path"]
    require(path["material"] in ("Ground","Mud","Sand","Rock") and number(path["width"],8,32),"Path material/width")
    pts=path["points"]
    require(2<=len(pts)<=64 and all(len(a)==2 and number(a[0],b[0],b[3]) and number(a[1],b[2],b[5]) for a in pts),"Path points")
    require(all(a!=c for a,c in zip(pts,pts[1:])),"Duplicate path points")
    require(type(p["cleanupLightingLab"]) is bool,"Cleanup flag")
    return p

def task(t,key,p,mode,**kwargs):
    cfg=dict(universeId=t["universeId"],placeId=t["placeId"],environment="staging",plan=validate(p),mode=mode,**kwargs)
    payload=canonical(cfg)
    for n in range(1,16):
        eq="="*n
        if "]"+eq+"]" not in payload:
            return run_task(t["universeId"],t["placeId"],key,SOURCE.read_text().replace("__RS_CONFIG__","["+eq+"["+payload+"]"+eq+"]"))
    raise WorkspaceError("Config encoding")

def save(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n")

def preview_image(p,r,path):
    from PIL import Image,ImageDraw
    grid=r["grid"];nx=len(grid);nz=len(grid[0]);scale=8
    im=Image.new("RGB",(nx*scale,nz*scale+32),"#202a34");d=ImageDraw.Draw(im)
    colors={"Grass":(83,139,70),"Ground":(139,98,61),"Mud":(107,78,49),"Sand":(224,196,130),"Rock":(130,130,130)}
    for x,col in enumerate(grid):
        for z,(height,water,material) in enumerate(col):
            color=(53,135,190) if water is not False else colors[material]
            shade=0.72+0.28*(height-r["minHeight"])/max(1,r["maxHeight"]-r["minHeight"])
            d.rectangle((x*scale,z*scale,(x+1)*scale-1,(z+1)*scale-1),fill=tuple(int(c*shade) for c in color))
    d.text((6,nz*scale+8),"Native Terrain plan | top-down height/material preview, not game render",fill="white")
    im.save(path)

def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument("operation",choices=["preview","apply","verify"])
    a.add_argument("--plan",type=Path,required=True)
    a.add_argument("--game",default="mapa-principal");a.add_argument("--place",default="main")
    a.add_argument("--expected-version",type=int)
    a.add_argument("--digest");a.add_argument("--confirm-staging",action="store_true")
    a.add_argument("--output",type=Path,default=ROOT/"dist/terrain")
    args=a.parse_args()
    p=validate(json.loads(args.plan.read_text()))
    games,targets=load_all();t=resolve(games,targets,args.game,args.place,"staging")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    out=args.output;out.mkdir(parents=True,exist_ok=True)
    if args.operation=="preview":
        r=task(t,key,p,"preview");save(out/"preview.json",r);preview_image(p,r,out/"preview.png")
        print("TERRAIN_PREVIEW",json.dumps({k:v for k,v in r.items() if k!="grid"}),flush=True);return
    if args.operation=="verify":
        require(bool(args.digest),"Digest required")
        r=task(t,key,p,"verify",expectedDigest=args.digest);save(out/"verification.json",r);preview_image(p,r,out/"preview.png")
        print("TERRAIN_VERIFIED",json.dumps({k:v for k,v in r.items() if k!="grid"}),flush=True);return
    require(args.confirm_staging and args.expected_version is not None,"Explicit staging confirmation and version required")
    from script_quality import main as quality
    require(quality([])==0,"Luau gate failed")
    before=capture(t,key);save(out/"before.json",before)
    require(before["loadedVersion"]==args.expected_version,"Staging version changed")
    r=task(t,key,p,"apply",expectedVersion=args.expected_version);save(out/"save.json",r)
    require(r.get("saved") is True,"Save unconfirmed")
    v=task(t,key,p,"verify",expectedDigest=r["digest"]);save(out/"verification.json",v);preview_image(p,v,out/"preview.png")
    require(v["loadedVersion"]>before["loadedVersion"] and v.get("verified") is True,"Persistence unconfirmed")
    after=capture(t,key);save(out/"after.json",after);delta=compare(before,after);save(out/"workspace-diff.json",delta)
    require(delta["sameStructure"] and after["loadedVersion"]==v["loadedVersion"],"Unexpected Workspace object changes")
    print("TERRAIN_VERIFIED",json.dumps({k:v for k,v in v.items() if k!="grid"}),flush=True)
    print("PAINT_INVARIANTS",json.dumps(r["paintCheck"]),flush=True)
if __name__=="__main__":
    try:main()
    except (WorkspaceError,ValueError,KeyError,OSError) as exc:
        print(f"ERROR: {exc}",file=sys.stderr);raise SystemExit(1)
