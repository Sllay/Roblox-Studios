"""Generate paired trunk cylinder + rounded cap profiles from observed geometry.
Preview only. A retained legacy width is explicitly provisional, never a
measurement of a branched mesh. No runtime physics claims.
"""
import argparse,json,math,statistics
from pathlib import Path
from collections import Counter
from scene_sync import ROOT,read,write,require,sha,state_path
from deploy import load_all,resolve
from spatial_index import SurfaceIndex
GAME=ROOT/"games/maps/mapa-principal"

def cylinder_profile(x,z,ground,top,diameter):
    require(all(math.isfinite(v) for v in (x,z,ground,top,diameter)) and .1<=diameter<=12,"Collider dimensions")
    radius=diameter/2
    bottom=ground-.12
    center=top-radius
    height=center-bottom
    require(height>diameter,"Tree too short for rounded termination")
    # Cylinder axis is local X; sphere overlaps its upper end by one radius.
    return {"bottom":bottom,"top":top,"diameter":diameter,"shaft":{"size":[height,diameter,diameter],"position":[x,bottom+height/2,z],"shape":"Cylinder","rotation":"Z90"},"cap":{"size":[diameter]*3,"position":[x,center,z],"shape":"Ball","rotation":"identity"}}

def build(base,inventory,native):
    require(inventory["loadedVersion"]==native["loadedVersion"]==base["loadedVersion"] and inventory["stateDigest"]==native["stateDigest"]==base["stateDigest"],"Stale evidence")
    require(native["snapshotDigest"]==sha({k:v for k,v in native.items() if k!="snapshotDigest"}),"Native snapshot integrity")
    require(len(native["tiles"])==9 and all(base["records"]["terrain:"+t["id"]]["digest"]==t["digest"] and base["records"]["terrain:"+t["id"]]["bounds"]==t["bounds"] for t in native["tiles"]),"Terrain digest")
    idx=SurfaceIndex(native["tiles"],native["materials"])
    rows=inventory["rows"];ids={r["id"] for r in rows}
    require(len(ids)==len(rows),"Model identity")
    trees=[r for r in rows if r["species"].startswith(("Tree_","Pine_"))]
    prior={}
    for r in trees:
        if r.get("collider"):
            c=r["collider"];prior.setdefault(r["species"],[]).append(c["size"][1]/r["scale"])
    profiles=[];excluded=[];blocked=[]
    for r in trees:
        if not r["playable"]:
            require(r.get("collider") is None,"Horizon collider unexpected")
            excluded.append(r["id"]);continue
        trunk=[m for m in r["meshes"] if m["name"].startswith("Trunk")]
        require(len(trunk)==1,"Exact trunk mesh required")
        t=trunk[0];c=r.get("collider")
        x,z=(c["position"][0],c["position"][2]) if c else (r["position"][0],r["position"][2])
        source="legacy_width_provisional"
        width=c["size"][1] if c else statistics.median(prior[r["species"]])*r["scale"]
        if r["species"].startswith("Pine_"):
            # Straight tapered trunk without branches, separately audited.
            x,z=t["position"][0],t["position"][2]
            width=max(t["size"][0],t["size"][2])
            source="audited_branchless_trunk_bounds"
        ground=idx.height(x,z)
        if ground is None:
            blocked.append({"id":r["id"],"reason":"no_dry_native_support"});continue
        if not r["low"]-.2<=ground<=r["top"]-2:
            blocked.append({"id":r["id"],"reason":"visual_ground_mismatch"});continue
        profile=cylinder_profile(x,z,ground,r["top"],width)
        profiles.append({"id":r["id"],"root":r["root"],"species":r["species"],"asset":r["asset"],"mesh":t["mesh"],"modelPosition":r["position"],"modelScale":r["scale"],"groundY":ground,"oldCollider":c,"action":"replace" if c else "add","widthEvidence":source,"widthCalibrationRequired":source=="legacy_width_provisional","collisionGroup":c["group"] if c else "Default","owner":c["owner"] if c else "RobloxStudiosStaticV1",**profile})
    speciesProfiles={}
    for p in profiles:
        a=speciesProfiles.setdefault(p["species"],{"widthEvidence":p["widthEvidence"],"widthCalibrationRequired":p["widthCalibrationRequired"],"count":0,"diameters":[],"heights":[]})
        a["count"]+=1;a["diameters"].append(p["diameter"]);a["heights"].append(p["top"]-p["groundY"])
    for a in speciesProfiles.values():
        a["diameterRange"]=[min(a["diameters"]),max(a["diameters"])];a["heightRange"]=[min(a["heights"]),max(a["heights"])]
        del a["diameters"];del a["heights"]
    return {"schemaVersion":1,"loadedVersion":base["loadedVersion"],"stateDigest":base["stateDigest"],"speciesProfiles":speciesProfiles,"profiles":profiles,"excludedHorizon":excluded,"blocked":blocked,"geometryProbe":inventory["geometry"],"noPlaceWrites":True,"applyAuthorized":False,"runtimeSlideVerified":False}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--inventory",type=Path,required=True);p.add_argument("--output",type=Path,default=ROOT/"dist/s04");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    base=read(state_path(target));native=read(GAME/"docs/spatial/v14/native.json")
    plan=build(base,read(a.inventory),native);plan["planDigest"]=sha(plan);write(a.output/"collider-plan.json",plan)
    summary={"version":base["loadedVersion"],"profiles":len(plan["profiles"]),"replacements":sum(r["action"]=="replace" for r in plan["profiles"]),"new":sum(r["action"]=="add" for r in plan["profiles"]),"widthEvidence":dict(Counter(r["widthEvidence"] for r in plan["profiles"])),"horizonExcluded":len(plan["excludedHorizon"]),"blocked":plan["blocked"],"minHeight":min(r["top"]-r["groundY"] for r in plan["profiles"]),"maxHeight":max(r["top"]-r["groundY"] for r in plan["profiles"]),"planDigest":plan["planDigest"],"noPlaceWrites":True}
    write(a.output/"collider-summary.json",summary);print("S04_PLAN "+json.dumps(summary),flush=True)
if __name__=="__main__":main()
