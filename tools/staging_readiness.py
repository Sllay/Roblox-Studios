"""Check staging mapping and actual remote identity, read-only."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
from deploy import load_all,resolve,WorkspaceError
from cloud_tasks import run_task
ROOT=Path(__file__).resolve().parents[1]
SOURCE='''local Http = game:GetService("HttpService")
return Http:JSONEncode({universeId=tostring(game.GameId),placeId=tostring(game.PlaceId),placeVersion=game.PlaceVersion})
'''
def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game",default="mapa-principal")
    p.add_argument("--place",default="main")
    p.add_argument("--output",type=Path,default=ROOT/"dist"/"staging-readiness.json")
    args=p.parse_args(argv)
    report={"schemaVersion":1,"game":args.game,"place":args.place,"ready":False}
    try:
        games,targets=load_all()
        target=resolve(games,targets,args.game,args.place,"staging")
        # Block aliases across ALL configured production targets, not only same game.
        for config in targets.values():
            prod=config["environments"]["production"]
            if str(prod["universeId"])==target["universeId"] or target["placeId"] in {str(x) for x in prod["placeIds"].values()}:
                raise WorkspaceError("Staging aliases a configured production target")
        key=os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY","")
        if not key: raise WorkspaceError("Missing Open Cloud key")
        remote=run_task(target["universeId"],target["placeId"],key,SOURCE)
        report.update(ready=True,status="identity_verified",universeId=target["universeId"],
                      placeId=target["placeId"],loadedVersion=remote["loadedVersion"],
                      note="Read access only; save permission not tested")
    except (WorkspaceError,OSError,ValueError) as exc:
        report.update(status="blocked",diagnostic=str(exc))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))
    return 0 if report["ready"] else 2
if __name__=="__main__":
    raise SystemExit(main())
