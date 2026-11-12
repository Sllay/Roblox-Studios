"""Validate/update model contact and coupled colliders after native terrain edits."""
from __future__ import annotations
import argparse,json,os,sys
from pathlib import Path
from deploy import load_all,resolve,WorkspaceError
from scene_sync import ROOT,task,regions,require_current,read,write,require
def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument("operation",choices=["preview","apply"])
    a.add_argument("--game",default="mapa-principal");a.add_argument("--place",default="main")
    a.add_argument("--region",required=True);a.add_argument("--intent",choices=["paint","sculpt"],default="sculpt")
    a.add_argument("--baseline",type=Path);a.add_argument("--confirm-staging",action="store_true")
    a.add_argument("--output",type=Path,default=ROOT/"dist/prop-reconcile")
    p=a.parse_args();games,targets=load_all();t=resolve(games,targets,p.game,p.place,"staging")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];base=require_current(t,key)
    matches=[r for r in regions(t) if r["id"]==p.region];require(len(matches)==1,"Unknown region")
    reg=matches[0];digest=base["records"]["terrain:"+p.region]["digest"]
    source="do\n"+(ROOT/"tools/sync/prop_reconcile.luau").read_text().replace("-- __RS_SUPPORT__",(ROOT/"tools/sync/prop_support.luau").read_text())+"\nend"
    opts=dict(region=reg,terrainDigest=digest,intent=p.intent,environment="staging",expectedVersion=base["loadedVersion"])
    r=task(t,key,source,mode="preview",**opts);write(p.output/"preview.json",r)
    print("PROP_RECONCILE_PREVIEW",json.dumps({"version":r["loadedVersion"],"region":p.region,"counts":r["counts"],"intent":p.intent}),flush=True)
    if p.operation=="preview":return
    require(p.confirm_staging and p.intent=="sculpt" and p.baseline is not None,"Reviewed sculpt plan required")
    require(read(p.baseline)==r and r["loadedVersion"]==base["loadedVersion"],"Preview stale")
    require(r["counts"]["review"]==r["counts"]["unmanaged"]==0 and r["counts"]["move"]>0,"No safe moves or unresolved supports")
    from script_quality import main as quality
    require(quality([])==0,"Luau gate")
    result=task(t,key,source,mode="apply",expectedRows=r["rows"],**opts);write(p.output/"save.json",result)
    require(result["saved"],"Save unconfirmed")
    v=task(t,key,source,mode="verify",expectedRows=r["rows"],**opts);write(p.output/"verification.json",v)
    require(v["verified"] and v["loadedVersion"]>r["loadedVersion"],"Move not persisted")
    print("PROP_RECONCILE_VERIFIED",json.dumps(v),flush=True)
if __name__=="__main__":
    try:main()
    except (WorkspaceError,ValueError,KeyError,OSError) as e:print("ERROR:",e,file=sys.stderr);raise SystemExit(1)
