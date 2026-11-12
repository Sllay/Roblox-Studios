"""S03: geometry-aware resource/bush preview using persisted S02 evidence.
No Place mutation. Resource positions are conditional on exact component evidence.
"""
import argparse,math,random,json
from pathlib import Path
from collections import Counter
from scene_sync import ROOT,read,write,require,sha,state_path
from deploy import load_all,resolve
from spatial_index import SurfaceIndex,Occupancy
from spatial_engine import prior_rows
GAME=ROOT/"games/maps/mapa-principal"
DATA=GAME/"docs/spatial/v14"
ASSETS=GAME/"game/assets"

def dimensions(size,width,axis):
    require(len(size)==3 and all(type(v) in (int,float) and math.isfinite(v) and v>0 for v in size),"Invalid source dimensions")
    require(.5<=width<=2 and axis in (0,1,2),"Resource dimension")
    scale=width/size[axis]
    return scale,[v*scale for v in size]

def plan_resources(base,native,source,objects,rock,stick):
    require(base["loadedVersion"]==native["loadedVersion"]==source["loadedVersion"] and base["stateDigest"]==native["stateDigest"]==source["stateDigest"],"Stale spatial evidence")
    require(native["snapshotDigest"]==sha({k:v for k,v in native.items() if k!="snapshotDigest"})==source["nativeSnapshotDigest"],"Native snapshot integrity")
    require(source["planDigest"]==sha({k:v for k,v in source.items() if k!="planDigest"}),"Candidate integrity")
    idx=SurfaceIndex(native["tiles"],native["materials"])
    require(len(idx.tiles)==9 and all(base["records"]["terrain:"+t["id"]]["digest"]==t["digest"] for t in native["tiles"]),"Terrain digest")
    existing=[o for o in objects if o["species"]=="Rock"];require(len(existing)==8,"Expected eight existing resource rocks")
    occ=Occupancy(objects);old={r["id"]:r for r in prior_rows()}
    rows=[];rng=random.Random(14503)
    # Retain all eight existing identities; move and rescale them into the new
    # distribution. Recenter geometry in detached model before scaling.
    for o in existing:occ.remove(o["id"])
    available={r["id"]:r for r in source["resourceCandidates"] if r["category"]=="stone"}
    require(len(available)==108,"Stone candidate count")
    assignments={}
    for o in sorted(existing,key=lambda x:x["id"]):
        r=min(available.values(),key=lambda r:(math.hypot(o["x"]-r["x"],o["z"]-r["z"]),r["id"]))
        assignments[r["id"]]=o;available.pop(r["id"])
    for candidate in sorted(source["resourceCandidates"],key=lambda x:x["id"]):
        category=candidate["category"]
        if category=="stick" and stick.get("status")!="extracted":continue
        if category=="stone":
            size=rock["bounds"];axis=max((0,2),key=lambda i:size[i]);width=rng.uniform(.65,1.45)
            assetId=rock["assetId"];digest=rock["digest"]
        else:
            size=stick["size"];axis=max(range(3),key=lambda i:size[i]);width=rng.uniform(.85,1.95)
            assetId=stick["assetId"];digest=stick["digest"]
        scale,scaled=dimensions(size,width,axis)
        # Rotate longest axis to horizontal X before yaw; Y becomes original X
        # when the longest dimension was vertical. Use explicit local axis map.
        rotation="Z90" if category=="stick" and axis==1 else "Y90" if category=="stick" and axis==2 else "identity"
        if rotation=="Z90":scaled=[scaled[1],scaled[0],scaled[2]]
        elif rotation=="Y90":scaled=[scaled[2],scaled[1],scaled[0]]
        radius=math.hypot(scaled[0],scaled[2])/2
        x,z=candidate["x"],candidate["z"]
        require(radius<=1.5,"Resource footprint budget")
        support=idx.support(x,z,max(.5,radius));require(support is not None,"Resource support")
        require(idx.dry(x,z,radius) and idx.water_clearance(x,z,4)>=4 and not occ.blocked(x,z,radius+1),"Resource geometry/occupancy conflict")
        # Centered local bounding box; support is voxel estimate, not raycast.
        burial=min(.03,scaled[1]*.08)
        identity=assignments.get(candidate["id"])
        id=identity["id"] if identity else "p45-"+candidate["id"].replace(":","-")
        row={"id":id,"action":"resize_relocate" if identity else "new","category":category,"assetId":assetId,"sourceDigest":digest,"candidateId":candidate["id"],"tile":candidate["tile"],"scaleFactorFromSource":scale,"bounds":scaled,"maxHorizontal":max(scaled[0],scaled[2]),"yaw":rng.randrange(360),"orientation":rotation,"position":[x,support["height"]+scaled[1]/2-burial,z],"groundY":support["height"],"burial":burial,"radius":radius,"anchored":True,"canCollide":False,"canTouch":False,"canQuery":False,"resourceState":"decorative","futureCollectible":True,"contactStatus":"voxel_estimate_only"}
        if identity:row["before"]={k:identity[k] for k in ("x","y","z","scale")}
        rows.append(row);occ.add({"id":id,"x":x,"z":z,"radius":radius})
    # Relocate 3 existing bushes near the central exploration band, not spawn.
    bushes=sorted((o for o in objects if o["species"]=="Bush_03"),key=lambda x:-math.hypot(x["x"],x["z"]))
    require(len(bushes)==8,"Expected eight Bush_03")
    moves=[];rejected=Counter()
    for o in bushes[:3]:
        before=old[o["id"]];r=o["radius"];picked=None
        for _ in range(6000):
            angle=rng.uniform(0,math.tau);distance=rng.uniform(65,125)
            x,z=round(math.cos(angle)*distance,2),round(math.sin(angle)*distance,2)
            rule={"materials":["Grass"],"radius":r,"footprint":max(3,r*.6),"waterClearance":6,"supportRadius":before["supportRadius"],"maxSlope":15,"maxRelief":1.5,"spacing":2,"altitudePercentile":None}
            why,s=idx.evaluate(x,z,rule,occ,ignore=o["id"])
            if why:rejected[why]+=1;continue
            picked=(x,z,s);break
        if not picked:continue
        x,z,s=picked;occ.remove(o["id"]);occ.add({**o,"x":x,"z":z})
        moves.append({"id":o["id"],"species":"Bush_03","from":before["position"],"to":[x,o["y"]+s["height"]-before["groundY"],z],"groundY":s["height"],"scale":before["scale"],"yaw":before["yaw"],"sourceDigest":before["sourceDigest"],"tile":idx.tile_of[idx.cell_key(x,z)],"requiresCoupledMigration":True})
    return {"schemaVersion":1,"loadedVersion":base["loadedVersion"],"stateDigest":base["stateDigest"],"spatialPlanDigest":source["planDigest"],"resources":rows,"bushMoves":moves,"bushRejections":dict(rejected),"noPlaceWrites":True,"applyAuthorized":False,"limitations":["Final physical contact and visibility in tall grass require client validation.","Stone/Stick use one source each; additional variants pending review.","Legacy rock scale below old environment layout minimum requires dedicated resource adapter.","Pine altitude scenarios separate; visual identity still unconfirmed."]}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--stick",type=Path,required=True);p.add_argument("--output",type=Path,default=ROOT/"dist/s03");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    native,source=read(DATA/"native.json"),read(DATA/"candidates.json")
    audit=read(ASSETS/"audits/p4-environment-43181270756.json");rock=next(r for r in audit["results"] if r["name"]=="Rock")
    require(rock["status"]=="exact_v2_pass","Rock audit missing")
    stick=read(a.stick);require(stick["assetId"]=="9204066145" and stick["loadedVersion"]==base["loadedVersion"] and stick["noPlaceWrites"] is True,"Stick evidence")
    plan=plan_resources(base,native,source,read(DATA/"occupancy.json"),rock,stick)
    plan["planDigest"]=sha(plan);write(a.output/"resource-plan.json",plan)
    stats={"version":base["loadedVersion"],"rocks":sum(r["category"]=="stone" for r in plan["resources"]),"sticks":sum(r["category"]=="stick" for r in plan["resources"]),"reusedRockIdentities":sum(r["action"]=="resize_relocate" for r in plan["resources"]),"bushMoves":len(plan["bushMoves"]),"stickStatus":stick["status"],"planDigest":plan["planDigest"],"noPlaceWrites":True}
    write(a.output/"resource-summary.json",stats);print("S03_PLAN "+json.dumps(stats),flush=True)
if __name__=="__main__":main()
