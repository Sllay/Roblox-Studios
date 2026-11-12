
"""Deterministic terrain-aware forest pilot. Preview, audit, apply, verify; staging only."""
from __future__ import annotations
import argparse,hashlib,json,math,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools/assets"))
from pack_import import inspect_blob,validate_evidence,equivalent,validate_selector
from placement import validate_profile
from cloud_tasks import run_task
from deploy import load_all,resolve,WorkspaceError
from scene_snapshot import canonical,capture,compare
from terrain_builder import require,save

def validate(p):
    require(p["schemaVersion"]==1 and p["assetId"]=="79689531752352","Pilot pack")
    require(p["bounds"]==[96,0,-128,352,64,128],"Pilot terrain bounds")
    require(p["terrainDigest"]=="+9jG2LoEvoHDF4Ux6xX9R5w77c96xo21r22RIJsp5Bk=","Terrain baseline")
    require(type(p["seed"]) is int and 0<=p["seed"]<=100000,"Seed")
    require(1<=len(p["species"])<=4 and 1<=p["maxModels"]<=40,"Budget")
    require(4<=p["minSpacing"]<=24 and 0.65<=p["canopySpacing"]<=1.2,"Spacing")
    require(len({s["name"] for s in p["species"]})==len(p["species"]),"Duplicate species")
    registry=json.loads((ROOT/"games/maps/mapa-principal/game/assets/visual-reviews/79689531752352.json").read_text())
    for s in p["species"]:
        validate_selector(s["selector"]);validate_profile(s["profile"])
        rows=[r for r in registry["reviews"] if r["name"]==s["name"] and r["selector"]==s["selector"]]
        require(len(rows)==1 and s["biome"] in rows[0]["visual"]["inferred"]["suitableBiomes"],"Visual review")
        require(type(s["count"]) is int and 1<=s["minCount"]<=s["count"]<=20,"Species count")
        require(len(s["scale"])==2 and 0.45<=s["scale"][0]<=s["scale"][1]<=1.2 and 4<=s["clearance"]<=24,"Scale/clearance")
        if s["collision"]:
            require(0.5<=s["collision"]["radius"]<=3 and 3<=s["collision"]["height"]<=12,"Collision budget")
    require(sum(s["count"] for s in p["species"])<=p["maxModels"],"Total budget")
    return p

def task(t,key,p,mode,**opts):
    require(t["environment"]=="staging","Staging only")
    cfg=dict(universeId=t["universeId"],placeId=t["placeId"],environment="staging",assetId=p["assetId"],plan=p,mode=mode,**opts)
    payload=canonical(cfg)
    # Reuse exact P1 audit functions, without its task dispatch.
    shared=(ROOT/"tools/assets/pack_import.luau").read_text().split("-- __RS_PLACEMENT__",1)[0]
    shared+=(ROOT/"tools/assets/placement.luau").read_text()
    source=(ROOT/"tools/scene_builder.luau").read_text().replace("-- __RS_SHARED__",shared)
    for n in range(1,16):
        eq="="*n
        if "]"+eq+"]" not in payload:return run_task(t["universeId"],t["placeId"],key,source.replace("__RS_CONFIG__","["+eq+"["+payload+"]"+eq+"]"))
    raise WorkspaceError("Config encoding")

def digest(p):return hashlib.sha256(canonical(p).encode()).hexdigest()

def check_rows(p,r):
    specs={s["name"]:s for s in p["species"]}
    require(r["terrainDigest"]==p["terrainDigest"] and 0<len(r["rows"])<=p["maxModels"],"Terrain/model budget")
    require(set(r["sources"])==set(specs),"Source set mismatch")
    ids=set();counts={k:0 for k in specs}
    for a in r["rows"]:
        s=specs[a["species"]];counts[a["species"]]+=1
        require(a["id"] not in ids and a["id"].startswith("forest-"),"Duplicate identity");ids.add(a["id"])
        require(len(a["position"])==3 and all(type(x) in (int,float) and math.isfinite(x) for x in a["position"]),"Position")
        require(s["scale"][0]<=a["scale"]<=s["scale"][1] and 0<=a["yaw"]<360,"Transform")
        require(abs(a["buriedDepth"]-s["profile"]["buryDepthStuds"]*a["scale"])<0.01,"Scaled burial")
    for k,n in counts.items():require(specs[k]["minCount"]<=n<=specs[k]["count"],"Species count")
    for i,a in enumerate(r["rows"]):
        for b in r["rows"][:i]:
            d=math.hypot(a["position"][0]-b["position"][0],a["position"][2]-b["position"][2])
            require(d+0.001>=max(p["minSpacing"],(a["radius"]+b["radius"])*p["canopySpacing"]),"Spacing")
    return r

def preview_image(p,r,path):
    from PIL import Image,ImageDraw
    grid=r["grid"];im=Image.new("RGB",(640,680),"#26313a");d=ImageDraw.Draw(im)
    colors={"Grass":"#78a65d","Ground":"#a4774c","Sand":"#e3c68d"}
    for x,col in enumerate(grid):
        for z,c in enumerate(col):
            d.rectangle((x*10,z*10,x*10+9,z*10+9),fill="#4b9bc3" if c["wet"] else colors.get(c["material"],"#777777"))
    for a in r["rows"]:
        x=(a["position"][0]-p["bounds"][0])*2.5;z=(a["position"][2]-p["bounds"][2])*2.5
        radius=a["radius"]*2.5
        d.ellipse((x-radius,z-radius,x+radius,z+radius),outline="#24592c" if a["species"]!="Bush_01" else "#b8e16b",width=2)
        d.ellipse((x-2,z-2,x+2,z+2),fill="#172d20")
    d.text((8,650),"Scene Builder | actual terrain materials + planned canopy bounds",fill="white")
    im.save(path)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("operation",choices=["preview","apply","verify"])
    ap.add_argument("--plan",type=Path,required=True);ap.add_argument("--baseline",type=Path)
    ap.add_argument("--expected-version",type=int,default=5);ap.add_argument("--confirm-staging",action="store_true")
    ap.add_argument("--output",type=Path,default=ROOT/"dist/scene-builder")
    a=ap.parse_args();p=validate(json.loads(a.plan.read_text()))
    games,targets=load_all();t=resolve(games,targets,"mapa-principal","main","staging")
    require((t["universeId"],t["placeId"])==("10769712441","93428341652658"),"Pilot target")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];out=a.output;out.mkdir(parents=True,exist_ok=True)
    if a.operation=="preview":
        r=task(t,key,p,"preview",expectedVersion=a.expected_version)
        for name,s in r["sources"].items():
            s["offlinePbr"]=inspect_blob(s);validate_evidence(s)
        print("PLACEMENT_DIAGNOSTIC",json.dumps(r["stats"]),flush=True)
        check_rows(p,r);r["plan"]=p;r["planDigest"]=digest({"plan":p,"rows":r["rows"],"sources":r["sources"]})
        save(out/"preview.json",r);preview_image(p,r,out/"preview.png")
        print("SCENE_PREVIEW",json.dumps({"stats":r["stats"],"models":len(r["rows"]),"planDigest":r["planDigest"],"terrain":r["counts"]}),flush=True);return
    require(a.baseline is not None,"Reviewed preview required")
    r=json.loads(a.baseline.read_text());check_rows(p,r)
    require(r["plan"]==p and r["universeId"]==t["universeId"] and r["placeId"]==t["placeId"] and r["planDigest"]==digest({"plan":p,"rows":r["rows"],"sources":r["sources"]}),"Preview identity")
    for s in r["sources"].values():validate_evidence(s)
    opts=dict(rows=r["rows"],sources=r["sources"],planDigest=r["planDigest"])
    if a.operation=="apply":
        require(a.confirm_staging,"Explicit confirmation")
        before=capture(t,key);save(out/"before.json",before)
        require(before["loadedVersion"]==r["loadedVersion"]==a.expected_version,"Version changed")
        result=task(t,key,p,"apply",expectedVersion=a.expected_version,**opts);save(out/"save.json",result)
        require(result.get("saved") is True,"Save not confirmed")
    v=task(t,key,p,"verify",**opts)
    for name,report in v.pop("serializedSamples").items():
        actual=inspect_blob(report)
        require(sorted(actual,key=lambda x:x["name"])==sorted(r["sources"][name]["offlinePbr"],key=lambda x:x["name"]),"Persisted PBR mismatch")
    v["offlinePbrVerified"]=True
    save(out/"verification.json",v)
    require(v["verified"] is True and v["loadedVersion"]>r["loadedVersion"],"Persistence not confirmed")
    if a.operation=="apply":
        after=capture(t,key);save(out/"after.json",after);delta=compare(before,after);save(out/"diff.json",delta)
        require(not delta["removed"] and all(x["path"].startswith("Workspace.RSSceneBuilder") for x in delta["added"]) and after["loadedVersion"]==v["loadedVersion"],"Unexpected scene changes")
    print("SCENE_VERIFIED",json.dumps(v),flush=True)
if __name__=="__main__":
    try:main()
    except (WorkspaceError,ValueError,KeyError,OSError) as exc:
        print(f"ERROR: {exc}",file=sys.stderr);raise SystemExit(1)
