"""Shared Open Cloud transport; resume a known task by GET, never replay POST."""
from __future__ import annotations
import json,re,time,hashlib,os,tempfile
from pathlib import Path
from scene_inspector import request_api
from workspace import WorkspaceError

def atomic_json(path,data):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    fd,tmp=tempfile.mkstemp(dir=path.parent,prefix=".receipt-")
    try:
        with os.fdopen(fd,"w",encoding="utf-8") as out:
            json.dump(data,out,sort_keys=True);out.write("\n");out.flush();os.fsync(out.fileno())
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)

def target_prefix(universe,place):
    if not all(re.fullmatch(r"[1-9][0-9]*",str(x)) for x in (universe,place)):
        raise WorkspaceError("Invalid Universe/Place ID")
    return f"universes/{universe}/places/{place}/"

def validate_path(path,universe,place,version=None):
    prefix=target_prefix(universe,place)
    match=re.fullmatch(re.escape(prefix)+r"versions/([1-9][0-9]*)/luau-execution-sessions/[A-Za-z0-9_-]+/tasks/[A-Za-z0-9_-]+",path if isinstance(path,str) else "")
    if not match or (version is not None and int(match.group(1))!=version):
        raise WorkspaceError("Unexpected task path or version")
    return int(match.group(1))

def poll_task(path,key):
    """Retry only idempotent reads; never resubmit a task."""
    for delay in (8,16,32,None):
        try:return request_api(path,key)
        except WorkspaceError as exc:
            if "HTTP 429" not in str(exc) or delay is None:raise
            print(f"Rate-limited reading task; retry GET in {delay}s",flush=True)
            time.sleep(delay)

def resume_task(universe,place,key,path,*,read_version=None):
    version=validate_path(path,universe,place,read_version)
    for _ in range(45):
        task=poll_task(path,key)
        if task.get("path",path)!=path:raise WorkspaceError("Poll task identity mismatch")
        state=task.get("state")
        if state=="COMPLETE":
            if task.get("error"):raise WorkspaceError(str(task["error"]))
            results=(task.get("output") or {}).get("results")
            if not isinstance(results,list) or len(results)!=1 or not isinstance(results[0],str):
                raise WorkspaceError("Expected exactly one JSON return value")
            try:data=json.loads(results[0])
            except ValueError as exc:raise WorkspaceError("Invalid task JSON") from exc
            if not isinstance(data,dict) or data.get("universeId")!=universe or data.get("placeId")!=place:
                raise WorkspaceError("Cloud result target mismatch")
            data["loadedVersion"]=version
            return data
        if state not in ("QUEUED","PROCESSING","PENDING"):
            raise WorkspaceError(f"Cloud task failed: {task.get('error',state)}")
        time.sleep(3)
    raise WorkspaceError("Cloud task timed out; do not retry a write without verifying its outcome")

def run_task(universe,place,key,source,*,read_version=None,journal=None):
    prefix=target_prefix(universe,place)
    if read_version is not None and (type(read_version) is not int or read_version<1):
        raise WorkspaceError("Invalid historical read version")
    endpoint=prefix+(f"versions/{read_version}/" if read_version is not None else "")+"luau-execution-session-tasks"
    receipt={"schemaVersion":1,"universeId":universe,"placeId":place,"sourceSha256":hashlib.sha256(source.encode()).hexdigest(),"readVersion":read_version,"status":"submission_unknown","retryAllowed":False}
    if journal is not None:
        journal=Path(journal);journal.parent.mkdir(parents=True,exist_ok=True)
        # Exclusive creation: an interrupted or finished attempt is never overwritten.
        try:
            with journal.open("x",encoding="utf-8") as out:
                json.dump(receipt,out,sort_keys=True);out.flush();os.fsync(out.fileno())
        except FileExistsError as exc:raise WorkspaceError("Existing task journal; reconcile before new submission") from exc
    task=request_api(endpoint,key,payload={"script":source,"timeout":"90s"})
    path=task.get("path")
    validate_path(path,universe,place,read_version)
    receipt.update(status="submitted",taskPath=path)
    if journal is not None:atomic_json(journal,receipt)
    print(f"Cloud task: {path}",flush=True)
    result=resume_task(universe,place,key,path,read_version=read_version)
    receipt.update(status="task_complete",loadedVersion=result["loadedVersion"],resultSha256=hashlib.sha256(json.dumps(result,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest())
    if journal is not None:atomic_json(journal,receipt)
    return result
