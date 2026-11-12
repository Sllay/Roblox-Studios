"""One-time P4.3 staging orchestration. No production target."""
import argparse, json, subprocess, sys
from pathlib import Path
from scene_sync import ROOT,read,write,sha,require,reconcile
from environment_layout import SPEC,dispatch,verify_layout
from default_clone_delta import split_default_clones
from scene_sync import capture,task
from deploy import load_all,resolve
import os
from pack_import import inspect_blob,validate_evidence
GAME=ROOT/"games/maps/mapa-principal"
SYNC=GAME/"docs/sync/main"
def run(*args):
    subprocess.run([sys.executable,*map(str,args)],cwd=ROOT,check=True)
def main():
    p=argparse.ArgumentParser()
    p.add_argument("phase",choices=["layout","recover-layout","scripts"])
    a=p.parse_args()
    base=read(SYNC/"staging.json")
    if a.phase in ("layout","recover-layout"):
        require(base["loadedVersion"]==10,"One-time v10 layout baseline required")
        old=read(SYNC/"patches/p4-environment-layout-v10.json")
        require(old["baselineDigest"]==base["stateDigest"],"Baseline mismatch")
        require(sha({k:v for k,v in old.items() if k!="planDigest"})==old["planDigest"],"Preview hash mismatch")
        plan=read(SPEC)
        for x,y in zip(old["plan"]["assets"],plan["assets"]):
            require(all(x[k]==y[k] for k in ("name","assetId","selector","sourceDigest","profile","count")),"Reviewed source/placement changed")
        require(old["plan"]["seed"]==plan["seed"] and old["plan"]["placement"]["regionIds"]==plan["placement"]["regionIds"],"Reviewed layout changed")
        old.pop("planDigest");old["plan"]=plan;old["planDigest"]=sha(old)
        reviewed=SYNC/"patches/p4-environment-layout-approved-v10.json"
        write(reviewed,old)
        if a.phase=="layout":
            run("tools/environment_layout.py","apply","--reviewed",reviewed,"--confirm-staging")
        else:
            games,targets=load_all();t=resolve(games,targets,"mapa-principal","main","staging")
            key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];after=capture(t,key)
            require(after["loadedVersion"]==11,"Recovery expects already saved v11")
            out=ROOT/"dist/p4-layout";write(out/"after.json",after)
            delta=reconcile(base,after)
            scoped,defaults=split_default_clones(base,after,delta["external"])
            require(len(defaults)==164,"Unexpected default-module delta; inspect before proceeding")
            for change in scoped:
                rec=after["records"].get(change["key"])
                require(change["change"]=="added" and rec and rec.get("service")=="Workspace" and rec.get("path",[{}])[0]["name"]=="RSEnvironmentP4","Unrelated scene change")
            require(len(scoped)==108,"Unexpected environment addition count")
            write(out/"default-clone-delta.json",defaults);write(out/"changes.json",delta)
            verify_layout(plan,old["rows"])
            verification=task(t,key,dispatch(),mode="verify",environment="staging",plan=plan,expectedVersion=11,terrainExpected=old["terrainExpected"],layoutRows=old["rows"],planDigest=old["planDigest"],runtimeSource=(ROOT/"tools/scene_builder_ground.server.luau").read_text())
            require(verification.get("verified") is True and verification["loadedVersion"]==11,"Independent verification failed")
            for sample in verification.pop("samples").values():
                sample["offlinePbr"]=inspect_blob(sample);validate_evidence(sample)
            write(out/"verification.json",verification)
            print("P4_LAYOUT_RECOVERED",json.dumps({"version":11,"models":verification["models"],"colliders":verification["colliders"],"defaultCloneRecords":len(defaults),"noNewSave":True}),flush=True)
        run("tools/scene_sync.py","--record")
        observed=read(SYNC/"staging.json")
        require(observed["loadedVersion"]==read(ROOT/"dist/p4-layout/after.json")["loadedVersion"] and observed["stateDigest"]==read(ROOT/"dist/p4-layout/after.json")["stateDigest"],"Unexpected change after verification")
    else:
        require(base["loadedVersion"]>10 and "managed:p4-tree-03-01" in base["records"],"Verified layout must be synchronized first")
        old=read(SYNC/"patches/p4-environment-scripts-v10.json")
        old["expectedVersion"]=base["loadedVersion"];old["baselineDigest"]=base["stateDigest"]
        path=SYNC/"patches/p4-environment-scripts-reviewed.json"
        write(path,old)
        run("tools/scene_patch.py","apply","--plan",path,"--confirm-staging")
        run("tools/scene_sync.py","--record")
        observed=read(SYNC/"staging.json")
        after=read(ROOT/"dist/scene-patch/after.json")
        require(observed["loadedVersion"]==after["loadedVersion"] and observed["stateDigest"]==after["stateDigest"],"Unexpected change after script verification")
    print("P4_STAGE_VERIFIED",json.dumps({"phase":a.phase,"version":observed["loadedVersion"],"digest":observed["stateDigest"]}),flush=True)
if __name__=="__main__":main()
