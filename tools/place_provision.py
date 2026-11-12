"""Provision Roblox Places with documented APIs. Never consume a session cookie."""
from __future__ import annotations
import argparse,json,os,re,sys
from pathlib import Path
from deploy import load_all,resolve,WorkspaceError,validate_global_targets
from cloud_tasks import run_task
from scene_sync import ROOT,require,write,require_current,canonical
from scaffold import new_game,add_place,set_ids,check_slug,check_id,ScaffoldError
from workspace import MAPS
SOURCE=ROOT/"tools/sync/provision.luau"
def task(t,key,mode,**extra):
    cfg=dict(universeId=t["universeId"],placeId=t["placeId"],mode=mode,**extra)
    payload=canonical(cfg)
    for n in range(1,16):
        eq="="*n
        if "]"+eq+"]" not in payload:return run_task(t["universeId"],t["placeId"],key,SOURCE.read_text().replace("__RS_CONFIG__","["+eq+"["+payload+"]"+eq+"]"))
    raise WorkspaceError("Config encoding")
def check_mapping(games,targets,game,place,universe,pid):
    for g,config in targets.items():
        for env,d in config["environments"].items():
            if env=="production" and str(d["universeId"])==universe:raise WorkspaceError("Staging Universe aliases production")
            for p,v in d["placeIds"].items():
                if v is not None and str(v)==pid:
                    require((g,p,env)==(game,place,"staging"),"Place already registered elsewhere")
    if game in games:
        d=targets[game]["environments"]["staging"]
        require(d["universeId"] is None or str(d["universeId"])==universe,"Game already has a different staging universe")
        require(d["placeIds"].get(place) is None or str(d["placeIds"][place])==pid,"Place mapping differs")
    else:require(place=="main","New game must start with main")
def enroll(games,targets,game,place,universe,pid,name,record):
    check_mapping(games,targets,game,place,universe,pid)
    if not record:return
    if game not in games:new_game(MAPS,game,name)
    elif place not in {p["slug"] for p in games[game]["places"]}:add_place(MAPS,game,place)
    set_ids(MAPS,game,place,"staging",universe,pid)
    load_all()
def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument("operation",choices=["inventory","enroll","clone-preview","clone"])
    a.add_argument("--game",default="mapa-principal");a.add_argument("--place",default="main")
    a.add_argument("--template",default="main")
    a.add_argument("--name",default="");a.add_argument("--description",default="Agent-created private staging place")
    a.add_argument("--universe-id");a.add_argument("--place-id")
    a.add_argument("--record",action="store_true");a.add_argument("--confirm-create",action="store_true")
    args=a.parse_args();game=check_slug(args.game);place=check_slug(args.place)
    games,targets=load_all();key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    out=ROOT/"dist/place-provision"
    if args.operation=="enroll":
        u,p=check_id(args.universe_id),check_id(args.place_id)
        check_mapping(games,targets,game,place,u,p)
        t={"universeId":u,"placeId":p}
        r=task(t,key,"identity");write(out/"identity.json",r)
        require(r["verified"],"Remote identity not verified")
        enroll(games,targets,game,place,u,p,args.name or game,args.record)
        print("PLACE_ENROLLED",json.dumps({"verified":True,"recorded":args.record,"universeId":u,"placeId":p,"version":r["loadedVersion"]}))
        return
    t=resolve(games,targets,game,check_slug(args.template),"staging")
    declared=next(p for p in games[game]["places"] if p["slug"]==args.template)
    eligible=declared.get("templateForClone") is True
    if args.operation=="inventory":
        r=task(t,key,"inventory",templateEligible=eligible);write(out/"inventory.json",r);print("PLACE_INVENTORY",json.dumps(r));return
    require(args.name and len(args.name)<=80 and len(args.description)<=1000,"Place name/description")
    require(place!=args.template and place not in {p["slug"] for p in games[game]["places"]},"Destination slug already exists")
    current=require_current(t,key)
    r=task(t,key,"clone-preview",name=args.name,templateEligible=eligible);write(out/"preview.json",r)
    print("PLACE_CLONE_PREVIEW",json.dumps(r),flush=True)
    if args.operation=="clone-preview":return
    require(args.confirm_create and eligible,"Explicit confirmation and a designated owned template are required")
    result=task(t,key,"clone",name=args.name,description=args.description,templateEligible=eligible,confirm=True,expectedVersion=current["loadedVersion"])
    write(out/"creation-receipt.json",result)
    require(result.get("created") is True,"Creation unconfirmed; list existing places before retry")
    pid=check_id(result["newPlaceId"]);u=t["universeId"]
    identity=task({"universeId":u,"placeId":pid},key,"identity")
    write(out/"new-place-identity.json",identity)
    require(identity["verified"] and identity["creatorId"]==r["creatorId"] and identity["creatorType"]==r["creatorType"],"New Place owner/identity mismatch")
    enroll(games,targets,game,place,u,pid,args.name,args.record)
    print("PLACE_CREATED",json.dumps({"placeId":pid,"universeId":u,"recorded":args.record}),flush=True)
if __name__=="__main__":
    try:main()
    except (WorkspaceError,ScaffoldError,ValueError,KeyError,OSError) as e:print("ERROR:",e,file=sys.stderr);raise SystemExit(1)
