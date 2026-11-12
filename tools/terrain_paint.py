
"""Paint native terrain surfaces without changing the terrain or water geometry."""
from __future__ import annotations
import argparse,json,os
from pathlib import Path
from terrain_builder import require,number,save,ROOT
from cloud_tasks import run_task
from deploy import load_all,resolve,WorkspaceError
from scene_snapshot import canonical

MATERIALS={"Grass","Ground","Mud","Sand","Rock","Slate","Snow","Ice","Basalt","LeafyGrass","Asphalt","Sandstone","Limestone","Pavement","Concrete","Cobblestone"}
def validate(p):
    require(p.get("schemaVersion")==1,"Paint schema")
    b=p["bounds"]
    require(len(b)==6 and all(type(x) is int and x%4==0 and abs(x)<=10000 for x in b),"Aligned bounds")
    dx,dy,dz=[b[i+3]-b[i] for i in range(3)]
    require(4<=dx<=512 and 8<=dy<=128 and 4<=dz<=512 and dx*dy*dz//64<=262144,"Paint budget")
    require(p["material"] in MATERIALS and isinstance(p["sourceMaterials"],list) and 0<len(p["sourceMaterials"])<=len(MATERIALS) and set(p["sourceMaterials"])<=MATERIALS,"Solid terrain materials only")
    require(type(p["depthCells"]) is int and 1<=p["depthCells"]<=4 and type(p["allowUnderwater"]) is bool,"Depth/underwater flag")
    m=p["mask"]
    def point(a):return isinstance(a,list) and len(a)==2 and all(number(x,-10000,10000) for x in a)
    require(m["kind"] in ("circle","ring","rectangle","path"),"Unknown mask")
    if m["kind"] in ("circle","ring"):
        require(point(m["center"]) and number(m["radius"],4,512),"Circle")
        if m["kind"]=="ring":require(number(m["innerRadius"],0,m["radius"]-4),"Ring")
    elif m["kind"]=="rectangle":
        require(point(m["min"]) and point(m["max"]) and all(a<c for a,c in zip(m["min"],m["max"])),"Rectangle")
    else:
        pts=m["points"]
        require(2<=len(pts)<=64 and all(point(x) for x in pts) and all(a!=c for a,c in zip(pts,pts[1:])) and number(m["width"],8,64),"Path")
    return p
def task(t,key,p,mode,**extra):
    payload=canonical(dict(universeId=t["universeId"],placeId=t["placeId"],environment="staging",plan=validate(p),mode=mode,**extra))
    source=(ROOT/"tools/terrain/paint.luau").read_text()
    for n in range(1,16):
        eq="="*n
        if "]"+eq+"]" not in payload:return run_task(t["universeId"],t["placeId"],key,source.replace("__RS_CONFIG__","["+eq+"["+payload+"]"+eq+"]"))
    raise WorkspaceError("Config encoding")
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("operation",choices=["preview","apply"]);ap.add_argument("--plan",type=Path,required=True)
    ap.add_argument("--baseline",type=Path);ap.add_argument("--confirm-staging",action="store_true")
    ap.add_argument("--game",default="mapa-principal");ap.add_argument("--place",default="main")
    ap.add_argument("--output",type=Path,default=ROOT/"dist/terrain-paint")
    a=ap.parse_args()
    p=validate(json.loads(a.plan.read_text()))
    games,targets=load_all();t=resolve(games,targets,a.game,a.place,"staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    if a.operation=="preview":
        r=task(t,key,p,"preview");r["plan"]=p;save(a.output/"preview.json",r);print("PAINT_PREVIEW",json.dumps(r));return
    require(a.confirm_staging and a.baseline is not None,"Explicit confirmation and baseline required")
    from script_quality import main as quality
    require(quality([])==0,"Luau quality gate")
    r=json.loads(a.baseline.read_text())
    require(r["plan"]==p and r["universeId"]==t["universeId"] and r["placeId"]==t["placeId"] and r["changedVoxels"]>0,"Baseline mismatch")
    options={k:r[k] for k in ("beforeDigest","geometryDigest","afterDigest")}
    from scene_sync import require_current
    require_current(t,key,r["loadedVersion"])
    result=task(t,key,p,"apply",expectedVersion=r["loadedVersion"],**options);save(a.output/"save.json",result)
    v=task(t,key,p,"verify",geometryDigest=r["geometryDigest"],afterDigest=r["afterDigest"]);save(a.output/"verification.json",v)
    require(v["verified"] is True and v["loadedVersion"]>r["loadedVersion"],"Paint not persisted")
    print("PAINT_VERIFIED",json.dumps(v))
if __name__=="__main__":main()
