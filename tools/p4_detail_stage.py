"""P4.4 candidate layout from reviewed exact audit; preview or staging apply."""
import argparse,sys,subprocess
from scene_sync import ROOT,read,write,require,sha
from environment_layout import validate,SPEC
GAME=ROOT/"games/maps/mapa-principal"
SYNC=GAME/"docs/sync/main"
DETAIL=GAME/"game/assets/environment-p4-detail-layout.json"
def run(*args):subprocess.run([sys.executable,*map(str,args)],cwd=ROOT,check=True)
def main():
    p=argparse.ArgumentParser()
    p.add_argument("phase",choices=["preview","apply"])
    a=p.parse_args()
    base=read(SYNC/"staging.json")
    require(base["loadedVersion"]>=12 and "managed:p4-localscript-rswind" in base["records"],"P4.3 not complete")
    plan=validate(read(DETAIL))
    out=ROOT/"dist/p4-detail-layout"
    if a.phase=="preview":
        run("tools/environment_layout.py","preview","--spec","detail","--output",out)
    else:
        reviewed=SYNC/"patches/p4-detail-layout-reviewed.json"
        prior=read(reviewed)
        require(prior["expectedVersion"]==base["loadedVersion"] and prior["baselineDigest"]==base["stateDigest"],"Stale approved detail layout")
        run("tools/environment_layout.py","apply","--spec","detail","--reviewed",reviewed,"--confirm-staging","--output",out)
        run("tools/scene_sync.py","--record")
        observed=read(SYNC/"staging.json")
        require(observed["stateDigest"]==read(out/"after.json")["stateDigest"],"Unexpected post-verify change")
        print("P4_DETAIL_STAGE_VERIFIED",observed["loadedVersion"],flush=True)
if __name__=="__main__":main()
