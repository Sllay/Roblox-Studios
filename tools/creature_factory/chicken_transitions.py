"""Native crossfade and speed probe on the five approved animation assets."""
import os,sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/"tools"),str(ROOT/"tools/asset_factory")]
from scene_sync import task
from deploy import load_all,resolve
from s08_prop_intake import write,commit
def main():
    d=ROOT/"asset-library/roblox-receipts/s09"
    a=json.loads((d/"chicken-v2-native-animation-set.json").read_text())
    assert a["allPlaybackVerified"] and a["rigAssetId"]=="76960331636475"
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    code=(ROOT/"tools/sync/s09_chicken_transitions.luau").read_text()
    p=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],code,read_version=25,compile_source=True,ids={k:v["assetId"] for k,v in a["clips"].items()})
    dest=d/"chicken-v2-transition-proof.json";write(dest,p);commit([dest],"evidence(s09): native chicken crossfade and speed tests")
    print(json.dumps(p,indent=2));assert p["allPassed"] and len(p["transitions"])==7 and len(p["speedTests"])==6,p
if __name__=="__main__":main()
