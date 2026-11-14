"""S08.6 sequential landmark/tint preview, one guarded save and native reopen."""
import argparse,json,os
from scene_sync import ROOT,task,write,require
from deploy import load_all,resolve
from sharded_scene_sync import latest
from s084_foliage_preview import retry
def main():
    parser=argparse.ArgumentParser();parser.add_argument("--publish",action="store_true");a=parser.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    out=ROOT/"dist/s086-polish";source="do\n"+(ROOT/"tools/sync/s086_final_polish.luau").read_text()+"\nend"
    def native(mode,version,**opts):
        return task(target,key,source,read_version=version,compile_source=True,mode=mode,**opts)
    require(retry(lambda:latest(target,key))==24,"Expected staging v24")
    r=retry(lambda:native("preview",24));write(out/"preview.json",r)
    expected={"tree":250,"pine":16,"bush":200}
    require(r["noPlaceWrites"] and r["readyForStaging"] and r["counts"]==expected and r["delta"]==8 and r["tinted"]==250 and r["geometryUnchanged"] and r["spawnChecked"]>0,"Preview")
    print("S086_CHECKPOINT_1",json.dumps({"delta":r["delta"],"before":r["before"]["pivot"],"after":r["after"]["pivot"],"height":r["after"]["bounds"][1],"spawnChecked":r["spawnChecked"]}),flush=True)
    print("S086_CHECKPOINT_2",json.dumps({"tinted":r["tinted"],"oldTint":r["oldTint"],"newTint":r["newTint"]}),flush=True)
    if not a.publish:return
    require(retry(lambda:latest(target,key))==24,"Head drift")
    opts=dict(expectedFingerprint=r["fingerprint"],expectedEnvironment=r["environment"],expectedTerrain={x["id"]:x["digest"] for x in r["terrain"]},expectedBefore=r["before"],expectedAfter=r["after"])
    write(out/"receipt.json",{"status":"started","beforeVersion":24,"retryAllowed":False})
    try:
        saved=native("apply",None,confirmStaging=True,journal=out/"cloud-task.json",**opts)
        require(saved["saved"] and saved["loadedVersion"]==24,"Save")
        require(retry(lambda:latest(target,key))==25,"Expected v25")
        proof=retry(lambda:native("verify",25,**opts));write(out/"verification.json",proof)
        require(proof["verified"] and proof["counts"]==expected and proof["tinted"]==250 and proof["geometryUnchanged"],"Readback")
        receipt={"status":"verified","beforeVersion":24,"afterVersion":25,"delta":8,"counts":expected,"oldTint":r["oldTint"],"newTint":r["newTint"],"pivot":proof["after"]["pivot"],"height":proof["after"]["bounds"][1],"spawnChecked":proof["spawnChecked"],"terrainRegions":len(proof["terrain"]),"clientRenderVerified":False}
        write(out/"receipt.json",receipt);print("S086_PUBLISHED",json.dumps(receipt),flush=True)
    except Exception:
        write(out/"receipt.json",{"status":"requires_reconciliation","beforeVersion":24,"retryAllowed":False});raise
if __name__=="__main__":main()
