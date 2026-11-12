"""Versioned read-only structural snapshots and conservative diffs."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
from cloud_tasks import run_task
from deploy import load_all, resolve, WorkspaceError

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools" / "scene_snapshot.luau"

def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"), allow_nan=False)

def snapshot(data):
    if data.get("schemaVersion") != 1 or not isinstance(data.get("objects"), list):
        raise WorkspaceError("Invalid snapshot")
    if data.get("truncated"):
        raise WorkspaceError("Snapshot truncated; cannot establish a complete baseline")
    if not isinstance(data.get("loadedVersion"), int):
        raise WorkspaceError("Snapshot missing loaded version")
    # Stable IDs exist only on explicitly managed objects. For unmanaged
    # objects compare a multiset of structural records, not name identity.
    records = sorted(canonical(obj) for obj in data["objects"])
    normalized = {**data, "objects": [json.loads(x) for x in records]}
    normalized["structuralSha256"] = hashlib.sha256(canonical(normalized["objects"]).encode()).hexdigest()
    return normalized

def compare(before, after):
    from collections import Counter
    if (before.get("universeId"), before.get("placeId")) != (after.get("universeId"), after.get("placeId")):
        raise WorkspaceError("Cannot compare different Places")
    a, b = snapshot(before), snapshot(after)
    x, y = Counter(map(canonical,a["objects"])), Counter(map(canonical,b["objects"]))
    return {"schemaVersion":1, "beforeVersion":a["loadedVersion"], "afterVersion":b["loadedVersion"],
            "sameStructure":a["structuralSha256"]==b["structuralSha256"],
            "added":[json.loads(k) for k in (y-x).elements()],
            "removed":[json.loads(k) for k in (x-y).elements()],
            "note":"Structural Workspace comparison only, not a full backup or script-source diff."}

def capture(target,key):
    return snapshot(run_task(target["universeId"],target["placeId"],key,SOURCE.read_text()))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game",default="mapa-principal")
    p.add_argument("--place",default="main")
    p.add_argument("--environment",default="production",choices=["staging","production"])
    p.add_argument("--output",type=Path,default=ROOT/"dist"/"snapshot")
    p.add_argument("--before",type=Path)
    p.add_argument("--after",type=Path)
    args=p.parse_args()
    try:
        if args.before or args.after:
            if not args.before or not args.after: raise WorkspaceError("Provide both snapshots")
            data=compare(json.loads(args.before.read_text()),json.loads(args.after.read_text()))
        else:
            games,targets=load_all()
            t=resolve(games,targets,args.game,args.place,args.environment)
            key=os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY","")
            if not key: raise WorkspaceError("Missing Open Cloud key")
            data=capture(t,key)
        args.output.mkdir(parents=True,exist_ok=True)
        path=args.output/("diff.json" if args.before else "snapshot.json")
        path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
        print(f"Snapshot artifact: {path}; version={data.get('loadedVersion')}; objects={len(data.get('objects',[]))}")
        return 0
    except (WorkspaceError,OSError,ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1
if __name__=="__main__":
    raise SystemExit(main())
