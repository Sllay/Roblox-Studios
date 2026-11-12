"""Recover the result of a recorded staging task via GET only.
No SavePlaceAsync, no automatic retry, no baseline promotion.
"""
import argparse,json,os
from pathlib import Path
from cloud_tasks import resume_task,atomic_json
from scene_sync import ROOT,require,read,capture,state_path,reconcile
from deploy import load_all,resolve

def recover(target,key,journal,base,*,get=resume_task,observe=capture):
    require(journal.get("schemaVersion")==1 and journal.get("retryAllowed") is False,"Invalid task journal")
    require(journal.get("universeId")==target["universeId"] and journal.get("placeId")==target["placeId"],"Journal target mismatch")
    require(target["environment"]=="staging","Staging only")
    result=None;status="submission_unknown";error=None
    if journal.get("taskPath"):
        try:
            result=get(target["universeId"],target["placeId"],key,journal["taskPath"],read_version=journal.get("readVersion"))
            status="task_complete"
        except Exception as exc:
            # Do not persist arbitrary API error or external code text.
            status="task_unconfirmed";error=type(exc).__name__
    after=observe(target,key)
    delta=reconcile(base,after)
    return {"schemaVersion":1,"status":status,"taskErrorType":error,"taskPath":journal.get("taskPath"),"taskReportedSaved":result.get("saved") if result else None,"beforeVersion":base["loadedVersion"],"afterVersion":after["loadedVersion"],"beforeDigest":base["stateDigest"],"afterDigest":after["stateDigest"],"sceneUnchanged":base["stateDigest"]==after["stateDigest"] and base["loadedVersion"]==after["loadedVersion"],"delta":delta,"retryAllowed":False,"baselinePromoted":False,"noPlaceWrites":True}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--journal",type=Path,required=True);p.add_argument("--output",type=Path,default=ROOT/"dist/task-reconciliation.json");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    report=recover(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],read(a.journal),base)
    atomic_json(a.output,report)
    print("TASK_RECONCILIATION "+json.dumps({k:v for k,v in report.items() if k!="delta"}),flush=True)
if __name__=="__main__":main()
