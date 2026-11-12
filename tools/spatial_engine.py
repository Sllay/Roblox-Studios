"""Pinned native terrain index and offline environmental planning; no Place writes."""
import argparse,hashlib,json,os
from pathlib import Path
from collections import Counter
from PIL import Image,ImageDraw
from scene_sync import ROOT,read,write,require,sha,regions,state_path,task
from deploy import load_all,resolve
from spatial_index import SurfaceIndex,Occupancy,observed_occupancy,place_candidates,decode_tile
GAME=ROOT/"games/maps/mapa-principal"
SOURCE=ROOT/"tools/sync/terrain_atlas.luau"
RULES=GAME/"game/assets/spatial-rules-p45.json"

def load_native(target,key,base,cache):
    regions_play=[r for r in regions(target) if r["playable"]]
    require(len(regions_play)==9,"Expected nine playable tiles")
    source=SOURCE.read_text();fingerprint=hashlib.sha256(source.encode()).hexdigest()
    def cache_path(r):
        ref=base["records"]["terrain:"+r["id"]]
        return cache/(sha([2,target["universeId"],target["placeId"],r["id"],ref["digest"],r["bounds"],fingerprint])+".json")
    def check(r,entry):
        t=entry["tile"];ref=base["records"]["terrain:"+r["id"]]
        require(t["id"]==r["id"] and t["bounds"]==ref["bounds"] and t["digest"]==ref["digest"],"Native tile identity/hash")
        require(entry["sourceSha256"]==fingerprint and entry["schemaVersion"]==2,"Native cache schema")
        require(entry["entryDigest"]==sha({k:v for k,v in entry.items() if k!="entryDigest"}),"Native cache integrity")
        decode_tile(t,entry["materials"])
        return entry
    found={};missing=[]
    for r in regions_play:
        path=cache_path(r)
        if path.is_file():found[r["id"]]=check(r,read(path))
        else:missing.append(r)
    calls=0
    for i in range(0,len(missing),2):
        batch=missing[i:i+2];ids=[r["id"] for r in batch]
        report=task(target,key,"do\n"+source+"\nend",read_version=base["loadedVersion"],compile_source=True,surfaceNative=True,surfaceTileIds=ids)
        calls+=1
        require(report["loadedVersion"]==base["loadedVersion"] and report["schemaVersion"]==2 and report["stepStuds"]==4 and report["sampleOffsetStuds"]==2 and report["noPlaceWrites"] is True,"Native report contract")
        require(len(report["tiles"])==len(ids) and {t["id"] for t in report["tiles"]}==set(ids),"Native batch scope")
        for r in batch:
            t=next(t for t in report["tiles"] if t["id"]==r["id"])
            e={"schemaVersion":2,"sourceSha256":fingerprint,"tile":t,"materials":report["materials"]}
            e["entryDigest"]=sha(e);check(r,e);write(cache_path(r),e);found[r["id"]]=e
    materials=next(iter(found.values()))["materials"]
    require(all(v["materials"]==materials for v in found.values()),"Material schema mismatch")
    return [found[r["id"]]["tile"] for r in regions_play],materials,{"cloudCalls":calls,"cacheHits":len(regions_play)-len(missing)}

def prior_rows():
    folder=GAME/"docs/sync/main/patches"
    rows=[]
    for name in ("p4-environment-layout-v10.json","p4-detail-layout-reviewed.json"):
        rows.extend(read(folder/name)["rows"])
    return rows

def regression(index,rows):
    errors=[]
    for r in rows:
        x,y,z=r["position"];s=index.support(x,z,r["supportRadius"])
        require(s is not None,"Prior support missing: "+r["id"])
        errors.append(abs(s["height"]-r["groundY"]))
    require(max(errors,default=0)<.002,"Prior placement height regression")
    return {"samples":len(errors),"maxHeightErrorStuds":max(errors,default=0)}

def pine_scenario(index,objects,rows,species,rules):
    # Both variants are conditional; neither is asserted to be the yellow tree.
    import random
    rng=random.Random(7301);occ=Occupancy(objects);moves=[];rejections=Counter()
    for old in [r for r in rows if r["name"]==species]:
        obj=occ.rows[old["id"]];rule={**rules["dryTree"],"radius":obj["radius"],"footprint":max(3,obj["radius"]*.6),"supportRadius":old["supportRadius"]}
        from spatial_index import validate_rule
        validate_rule(rule)
        x,z=obj["x"],obj["z"]
        reason,s=index.evaluate(x,z,rule,occ,ignore=obj["id"])
        target=(x,z,s) if reason is None else None
        if target is None:
            for _ in range(10000):
                id=rng.choice(sorted(index.tiles));b=index.tiles[id];margin=max(20,rule["radius"]+2)
                x,z=round(rng.uniform(b[0]+margin,b[3]-margin),2),round(rng.uniform(b[2]+margin,b[5]-margin),2)
                why,s=index.evaluate(x,z,rule,occ,ignore=obj["id"])
                if why:rejections[why]+=1;continue
                target=(x,z,s);break
        if target is None:continue
        x,z,s=target;occ.remove(obj["id"]);occ.add({**obj,"x":x,"z":z})
        moves.append({"id":obj["id"],"species":species,"from":old["position"],"to":[x,obj["y"]+s["height"]-old["groundY"],z],"groundY":s["height"],"oldGroundY":old["groundY"],"yaw":old["yaw"],"scale":old["scale"],"tile":index.tile_of[index.cell_key(x,z)],"requiresCoupledColliderMigration":True,"reason":reason or "already_valid"})
    return {"species":species,"conditionalOnly":True,"visualIdentityConfirmed":False,"rows":moves,"rejections":dict(rejections),"requested":4}

def render(index,objects,props,scenarios,out):
    xs=[k[0] for k in index.cells];zs=[k[1] for k in index.cells];x0,z0=min(xs),min(zs);w,h=max(xs)-x0+1,max(zs)-z0+1
    im=Image.new("RGB",(w,h),(30,35,40));alt=im.copy()
    for (i,j),(y,m,wet) in index.cells.items():
        c=(52,121,175) if wet else {"Grass":(72,125,65),"Sand":(203,185,130),"Ground":(145,108,77),"Rock":(125,126,130)}.get(m,(55,59,62))
        im.putpixel((i-x0,j-z0),c);alt.putpixel((i-x0,j-z0),(211,168,66) if m=="Grass" and not wet and y>=index.p80 else c)
    scale=4;im=im.resize((w*scale,h*scale),Image.Resampling.NEAREST);alt=alt.resize(im.size,Image.Resampling.NEAREST)
    alt.save(out/"high-terrain.png")
    def xy(x,z):return ((x/4-x0)*scale,(z/4-z0)*scale)
    d=ImageDraw.Draw(im)
    for o in objects:
        a,b=xy(o["x"],o["z"])
        if 0<=a<im.width and 0<=b<im.height:d.ellipse((a-2,b-2,a+2,b+2),fill="#d7e6be" if o["root"] in ("RSSceneBuilder","RSWorldVegetation") else "#f1b05b")
    for r in props:
        a,b=xy(r["x"],r["z"]);d.ellipse((a-2,b-2,a+2,b+2),fill="#f5f5f4" if r["category"]=="stone" else "#d48cfa")
    im.save(out/"resource-candidates.png")
    for scenario in scenarios:
        p=alt.copy();d=ImageDraw.Draw(p)
        for r in scenario["rows"]:
            a,b=xy(r["from"][0],r["from"][2]);c,e=xy(r["to"][0],r["to"][2])
            d.line((a,b,c,e),fill="#fff1b8",width=2);d.ellipse((c-4,e-4,c+4,e+4),fill="#ff7722",outline="black")
        p.save(out/(scenario["species"]+"-conditional.png"))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--output",type=Path,default=ROOT/"dist/s02");p.add_argument("--cache",type=Path,default=ROOT/".rs-cache/surface");p.add_argument("--offline",action="store_true");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    require(base["stateDigest"]==sha(base["records"]),"Baseline integrity")
    if a.offline:
        native=read(a.output/"native.json");require(native["stateDigest"]==base["stateDigest"] and native["loadedVersion"]==base["loadedVersion"],"Offline snapshot stale")
        tiles,materials=native["tiles"],native["materials"];metrics={"cloudCalls":0,"offline":True}
        for tile in tiles:
            ref=base["records"]["terrain:"+tile["id"]];require(tile["digest"]==ref["digest"] and tile["bounds"]==ref["bounds"],"Offline tile mismatch")
        require(native["snapshotDigest"]==sha({k:v for k,v in native.items() if k!="snapshotDigest"}),"Offline snapshot integrity")
    else:
        tiles,materials,metrics=load_native(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],base,a.cache)
    require(len(tiles)==9 and {t["id"] for t in tiles}=={r["id"] for r in regions(target) if r["playable"]},"Playable tile scope")
    native={"schemaVersion":2,"loadedVersion":base["loadedVersion"],"stateDigest":base["stateDigest"],"tiles":tiles,"materials":materials};native["snapshotDigest"]=sha(native);write(a.output/"native.json",native)
    index=SurfaceIndex(tiles,materials);rows=prior_rows();objects=observed_occupancy(base,{r["id"]:r["name"] for r in rows})
    rules=read(RULES);occ=Occupancy(objects)
    stones,ss=place_candidates(index,occ,rules["stone"],18201,12,"stone")
    sticks,ts=place_candidates(index,occ,rules["stick"],18202,12,"stick")
    scenarios=[pine_scenario(index,objects,rows,s,rules) for s in ("Pine_01.1","Pine_03.1")]
    prior=regression(index,rows)
    plan={"schemaVersion":1,"loadedVersion":base["loadedVersion"],"stateDigest":base["stateDigest"],"nativeSnapshotDigest":native["snapshotDigest"],"rulesDigest":sha(rules),"noPlaceWrites":True,"applyAuthorized":False,"resourceCandidates":stones+sticks,"stats":{"stone":ss,"stick":ts},"conditionalPineScenarios":scenarios}
    plan["planDigest"]=sha(plan);write(a.output/"candidates.json",plan);write(a.output/"occupancy.json",objects)
    render(index,objects,stones+sticks,scenarios,a.output)
    summary={"loadedVersion":base["loadedVersion"],"stateDigest":base["stateDigest"],"nativeSamples":len(index.cells),"tiles":len(tiles),"grassSamples":len(index.grass_heights),"grassAltitudeP80":index.p80,"observedModels":sum(o["root"] in {"RSSceneBuilder","RSWorldVegetation","RSEnvironmentP4","RSEnvironmentP4Detail","RSManagedAssets"} for o in objects),"stones":len(stones),"sticks":len(sticks),"pineScenarios":[{"species":s["species"],"planned":len(s["rows"]),"requested":s["requested"],"visualIdentityConfirmed":False} for s in scenarios],"legacyRegression":prior,"metrics":metrics,"planDigest":plan["planDigest"],"noPlaceWrites":True}
    write(a.output/"summary.json",summary);print("S02_SPATIAL "+json.dumps(summary),flush=True)
if __name__=="__main__":main()
