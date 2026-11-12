"""Verify proposed resource scale endpoints using actual detached assets."""
import argparse,os,json,math
from pathlib import Path
from pipeline import ROOT
from scene_sync import task,read,write,require,state_path,sha
from deploy import load_all,resolve
from pack_import import inspect_blob,validate_evidence
GAME=ROOT/"games/maps/mapa-principal"
def factors(plan,category):
    rows=[r["scaleFactorFromSource"] for r in plan["resources"] if r["category"]==category]
    require(rows,"No resource rows")
    return [min(rows),max(rows)]
def compare(report,size,expected):
    require(len(report["scaledSamples"])==len(expected),"Scale samples count")
    err=0
    for r,factor in zip(report["scaledSamples"],expected):
        require(abs(r["factor"]-factor)<1e-8,"Scale factor")
        err=max(err,max(abs(a-b*factor) for a,b in zip(r["bounds"],size)))
    require(err<.012,"Scaled bounds differ from planned source dimensions")
    return err
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--plan",type=Path,required=True);p.add_argument("--output",type=Path,default=ROOT/"dist/s03-geometry");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target));key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    plan=read(a.plan);require(plan["planDigest"]==sha({k:v for k,v in plan.items() if k!="planDigest"}) and plan["stateDigest"]==base["stateDigest"],"Stale plan")
    assets=read(GAME/"game/assets/environment-p4.json");rock=next(r for r in assets["assets"] if r["name"]=="Rock")
    pack=(ROOT/"tools/assets/pack_import.luau").read_text()
    helpers=pack[pack.index("local allowed="):pack.index("local function cloneSelected")]
    helpers='local Assets=game:GetService("AssetService")\nlocal Serial=game:GetService("SerializationService")\n'+helpers
    src=(ROOT/"tools/assets/resource_geometry_probe.luau").read_text().replace("-- __RS_PACK_HELPERS__",helpers)
    rf=factors(plan,"stone");sf=factors(plan,"stick")
    r=task(target,key,"do\n"+src+"\nend",read_version=base["loadedVersion"],compile_source=True,assetId=rock["assetId"],selector=rock["selector"],sourceDigest=rock["sourceDigest"],scaleFactors=rf)
    prior=read(GAME/"game/assets/audits/s03-stick-extraction-v14.json")
    s=task(target,key,"do\n"+(ROOT/"tools/assets/component_extract.luau").read_text()+"\nend",read_version=base["loadedVersion"],compile_source=True,assetId=prior["assetId"],componentMode="extract",selector=prior["source"]["selector"],scaleFactors=sf)
    require(r["noPlaceWrites"] and s["noPlaceWrites"] and r["codeExecuted"] is False and s["codeExecuted"] is False and s["roundtripVerified"] and s["meshId"]==prior["meshId"] and s["textureId"]==prior["textureId"] and s["digest"]==prior["digest"],"Resource proof")
    s.pop("serializedBase64")
    err1=compare(r,r["sourceBounds"],rf);err2=compare(s,prior["size"],sf)
    report={"schemaVersion":1,"loadedVersion":base["loadedVersion"],"stateDigest":base["stateDigest"],"planDigest":plan["planDigest"],"rock":r,"stick":s,"rockMaxBoundsError":err1,"stickMaxBoundsError":err2,"noPlaceWrites":True}
    write(a.output/"geometry.json",report);print("S03_GEOMETRY "+json.dumps({"version":base["loadedVersion"],"rockMaxBoundsError":err1,"stickMaxBoundsError":err2,"rockSamples":r["scaledSamples"],"stickSamples":s["scaledSamples"],"noPlaceWrites":True}),flush=True)
if __name__=="__main__":main()
