"""Shared Open Cloud task transport. Only callers' checked-in Luau is executed."""
from __future__ import annotations
import json
import re
import time
from scene_inspector import request_api
from workspace import WorkspaceError

def run_task(universe, place, key, source):
    if not all(re.fullmatch(r"[1-9][0-9]*", str(x)) for x in (universe, place)):
        raise WorkspaceError("Invalid Universe/Place ID")
    prefix = f"universes/{universe}/places/{place}/"
    task = request_api(prefix + "luau-execution-session-tasks", key,
                       payload={"script": source, "timeout": "90s"})
    path = task.get("path")
    if not isinstance(path, str) or not path.startswith(prefix):
        raise WorkspaceError("Unexpected task path")
    print(f"Cloud task: {path}", flush=True)
    for _ in range(45):
        task = request_api(path, key)
        state = task.get("state")
        if state == "COMPLETE":
            if task.get("error"):
                raise WorkspaceError(str(task["error"]))
            results = (task.get("output") or {}).get("results")
            if not isinstance(results, list) or len(results) != 1 or not isinstance(results[0], str):
                raise WorkspaceError("Expected exactly one JSON return value")
            try:
                data = json.loads(results[0])
            except ValueError as exc:
                raise WorkspaceError("Invalid task JSON") from exc
            if not isinstance(data, dict) or data.get("universeId") != universe or data.get("placeId") != place:
                raise WorkspaceError("Cloud result target mismatch")
            match = re.search(r"/versions/([0-9]+)/", task.get("path", path))
            if not match:
                raise WorkspaceError("Cloud task did not report a versioned path")
            data["loadedVersion"] = int(match.group(1))
            return data
        if state not in ("QUEUED", "PROCESSING", "PENDING"):
            raise WorkspaceError(f"Cloud task failed: {task.get('error', state)}")
        time.sleep(3)
    raise WorkspaceError("Cloud task timed out; do not retry a write without verifying its outcome")
