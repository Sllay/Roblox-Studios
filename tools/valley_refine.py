"""Scoped valley v10 migration: native river, horizon, physical boundary, gameplay."""
import argparse,json,os,sys
from pathlib import Path
from deploy import load_all,resolve,WorkspaceError
from scene_sync import ROOT,task,require_current,read,write,require,capture,sha
SRC=ROOT/"games/maps/mapa-principal/game/places/main/src"
def main():
    a=argparse.ArgumentParser();a.add_argument("mode",choices=["preview","apply","verify"]);a.add_argument("--baseline",type=Path);a.add_argument("--receipt",type=Path);a.add_argument("--confirm-staging",action="store_true");p=a.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    require(target["placeId"]=="93428341652658","Wrong target")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];out=ROOT/"dist/valley-refine";out.mkdir(parents=True,exist_ok=True)
    source="do\n"+(ROOT/"tools/sync/valley_refine.luau").read_text().replace("-- __RS_SUPPORT__",(ROOT/"tools/sync/prop_support.luau").read_text())+"\nend"
    opts=dict(environment="staging",runtime=(SRC/"ServerScriptService/RSCentralSpawnSafety.server.luau").read_text(),client=(SRC/"StarterPlayer/StarterPlayerScripts/RSQualityPanel.client.luau").read_text(),grid=(SRC/"StarterPlayer/StarterPlayerScripts/RSBoundaryGrid.client.luau").read_text())
    if p.mode in ("preview","apply"):
        base=require_current(target,key,9)
        r=task(target,key,source,mode="preview",**opts);write(out/"preview.json",r)
        from PIL import Image,ImageDraw
        m=r["map"];im=Image.new("RGB",(len(m)*6,len(m[0])*6));draw=ImageDraw.Draw(im)
        for i,col in enumerate(m):
            for j,(h,w,mat) in enumerate(col):
                c=(40,133,194) if w else (216,196,145) if mat=="Sand" else (135,104,76) if mat=="Ground" else (int(55+h),int(100+h),65)
                draw.rectangle((i*6,j*6,i*6+5,j*6+5),fill=c)
        im.save(out/"river.png")
        print("VALLEY_PREVIEW",json.dumps({k:v for k,v in r.items() if k not in ("map","moves")}|{"moves":len(r["moves"])}),flush=True)
        if p.mode=="preview":return
        require(p.confirm_staging and p.baseline and read(p.baseline)==r,"Reviewed preview mismatch")
        # no large map in remote configuration
        result=task(target,key,source,mode="apply",preview={k:v for k,v in r.items() if k!="map"},**opts)
        write(out/"receipt.json",result);require(result["saved"],"Save unconfirmed")
    else:
        require(p.receipt is not None,"Receipt required");result=read(p.receipt)
    v=task(target,key,source,mode="verify",expected=result,**opts);write(out/"verification.json",v)
    require(v["verified"] and v["loadedVersion"]==10,"Persistence unconfirmed")
    print("VALLEY_VERIFIED",json.dumps({k:v for k,v in v.items() if k!="hashes"}),flush=True)
if __name__=="__main__":
    try:main()
    except (WorkspaceError,ValueError,KeyError,OSError) as e:print("ERROR:",e,file=sys.stderr);raise SystemExit(1)
