"""P4 world test migration. Preview/compare/apply once/independent verification."""
from __future__ import annotations
import argparse,json,os,sys
from pathlib import Path
from scene_sync import ROOT,task,require_current,read,write,state_path,require,capture,reconcile,sha
from deploy import load_all,resolve,WorkspaceError
PLAN=ROOT/"games/maps/mapa-principal/game/terrain/world-test-v8.json"
SRC=ROOT/"games/maps/mapa-principal/game/places/main/src"
def validate(p):
    require(p["schemaVersion"]==1 and p["expectedVersion"]==7 and p["chunkSize"]==256 and p["playableRadiusChunks"]==1 and p["horizonRadiusChunks"]==2,"World schema")
    require(p["yMin"]==-32 and p["yMax"]==112 and p["maxModels"]<=145 and 80<=p["spawnRadius"]<=112,"Budget")
    require(p["river"]["sourceLevel"]>p["river"]["lakeLevel"] and p["river"]["lakeLevel"]==20 and 3<=p["river"]["depth"]<=8,"River levels")
    return p
def source():
    p=ROOT/"tools/sync"
    return "do\n"+(p/"world_test.luau").read_text().replace("-- __RS_SUPPORT__",(p/"prop_support.luau").read_text())+"\nend"
def image(p,r,path):
    from PIL import Image,ImageDraw
    a=r["map"];n=len(a);im=Image.new("RGB",(n*5,n*5+42),"#202a31");d=ImageDraw.Draw(im)
    colors={"Grass":(85,135,72),"Ground":(137,105,74),"Sand":(222,196,132),"Rock":(125,125,125)}
    for x,col in enumerate(a):
        for z,(h,w,m) in enumerate(col):
            color=(47,134,191) if w else colors.get(m,(95,110,85))
            sh=.68+.32*min(1,h/70)
            d.rectangle((x*5,z*5,x*5+4,z*5+4),fill=tuple(int(c*sh) for c in color))
    for v in r["props"]:
        x,z=v["position"][0],v["position"][2];x=(x+640)/8*5;z=(z+640)/8*5
        d.ellipse((x-2,z-2,x+2,z+2),fill="#143d23")
    for x,y,z in r["spawns"]:
        x=(x+640)/8*5;z=(z+640)/8*5;d.ellipse((x-2,z-2,x+2,z+2),fill="#fff")
    d.rectangle((160,160,640,640),outline="#f4f4f4",width=2)
    d.text((8,n*5+9),"World preview | white: playable boundary/spawn; blue: river/lake; green: vegetation",fill="white")
    im.save(path)
def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument("mode",choices=["preview","apply","verify"])
    a.add_argument("--baseline",type=Path);a.add_argument("--receipt",type=Path)
    a.add_argument("--confirm-staging",action="store_true")
    args=a.parse_args();p=validate(read(PLAN))
    games,targets=load_all();t=resolve(games,targets,"mapa-principal","main","staging")
    require((t["universeId"],t["placeId"])==("10769712441","93428341652658"),"Wrong target")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];out=ROOT/"dist/world-test";out.mkdir(parents=True,exist_ok=True)
    opts=dict(plan=p,environment="staging",runtimeSource=(SRC/"ServerScriptService/RSCentralSpawnSafety.server.luau").read_text(),clientSource=(SRC/"StarterPlayer/StarterPlayerScripts/RSQualityPanel.client.luau").read_text())
    if args.mode in ("preview","apply"):
        base=require_current(t,key,7)
        require(base["stateDigest"]==p["baselineDigest"],"World baseline changed")
        r=task(t,key,source(),mode="preview",**opts)
        require(r["preview"] and r["loadedVersion"]==7 and len(r["tiles"])==25 and len(r["props"])<=p["maxModels"] and len(r["spawns"])>=20,"Preview contract")
        write(out/"preview.json",r);image(p,r,out/"preview.png")
        print("WORLD_PREVIEW",json.dumps({k:v for k,v in r.items() if k not in ("map","props","tiles","spawns")} | {"spawns":len(r["spawns"]),"props":len(r["props"]),"tiles":len(r["tiles"])}),flush=True)
        if args.mode=="preview":return
        require(args.confirm_staging and args.baseline is not None,"Reviewed preview and confirmation required")
        prior=read(args.baseline)
        require(prior==r,"Preview changed")
        result=task(t,key,source(),mode="apply",expectedPlants=r["plants"],expectedColliders=r["colliders"],expectedSpawns=len(r["spawns"]),expectedProps=r["props"],**opts)
        write(out/"save.json",result)
        require(result.get("saved") is True,"Save unconfirmed")
        write(out/"receipt.json",{"result":result,"previewDigest":sha(r),"baselineVersion":7})
    else:
        require(args.receipt is not None,"Receipt required");result=read(args.receipt)["result"]
    v=task(t,key,source(),mode="verify",expectedTiles=result["tiles"],expectedPlants=result["plants"],expectedColliders=result["colliders"],expectedSpawns=result["spawns"],expectedProps=result["props"],**opts)
    write(out/"verification.json",v)
    require(v["verified"] and v["loadedVersion"]>7,"Persistence unconfirmed")
    print("WORLD_VERIFIED",json.dumps({k:v for k,v in v.items() if k!="tiles"}),flush=True)
if __name__=="__main__":
    try:main()
    except (WorkspaceError,ValueError,KeyError,OSError) as exc:print("ERROR:",exc,file=sys.stderr);raise SystemExit(1)
