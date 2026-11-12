"""One-time P4.3 staging orchestration. No production target."""
import argparse, json, subprocess, sys
from pathlib import Path
from scene_sync import ROOT,read,write,sha,require,reconcile
from environment_layout import SPEC
GAME=ROOT/"games/maps/mapa-principal"
SYNC=GAME/"docs/sync/main"
def run(*args):
    subprocess.run([sys.executable,*map(str,args)],cwd=ROOT,check=True)
def main():
    p=argparse.ArgumentParser()
    p.add_argument("phase",choices=["layout","scripts"])
    a=p.parse_args()
    base=read(SYNC/"staging.json")
    if a.phase=="layout":
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
        run("tools/environment_layout.py","apply","--reviewed",reviewed,"--confirm-staging")
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
