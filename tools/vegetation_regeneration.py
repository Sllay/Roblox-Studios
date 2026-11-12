"""S06.2 unified, deterministic vegetation planning against a verified scene.
Retain external scenery; replace competing placement layers logically, not by
deleting scene folders. No Place writes. Poses and density are preview only.
"""
import argparse,math,random,os,json
from pathlib import Path
from collections import Counter,defaultdict
from PIL import Image,ImageDraw
from scene_sync import ROOT,read,write,require,sha,state_path,require_current,task
from deploy import load_all,resolve
from spatial_index import SurfaceIndex,Occupancy,percentile
from physics_builder import cylinder_profile
from transaction_policy import inventory_budget
GAME=ROOT/"games/maps/mapa-principal"
DATA=GAME/"docs/spatial/v14"
RULES=GAME/"game/assets/vegetation-regeneration-s06.json"
def kind(r):
    s=r["species"]
    return "pine" if s.startswith("Pine_") else "tree" if s.startswith("Tree_") else "bush" if s.startswith("Bush_") else "fixed"
def tile_of(idx,x,z):return idx.tile_of.get(idx.cell_key(x,z))
def distance(a,b):return math.hypot(a[0]-b[0],a[1]-b[1])
def native_index(base,native):
    require(native["snapshotDigest"]==sha({k:v for k,v in native.items() if k!="snapshotDigest"}),"Native snapshot integrity")
    require(len(native["tiles"])==9 and len({t["id"] for t in native["tiles"]})==9,"Native tile scope")
    for t in native["tiles"]:
        r=base["records"]["terrain:"+t["id"]]
        require(t["digest"]==r["digest"] and t["bounds"]==r["bounds"],"Stale terrain snapshot")
    return SurfaceIndex(native["tiles"],native["materials"])
def position(r):return (r["pivot"][0],r["pivot"][2])
def inventory_check(base,rows):
    models={r["managedId"]:r for r in base["records"].values() if r.get("service")=="Workspace" and r.get("class")=="Model" and r.get("managedId") and r["path"][0]["name"] in {"RSSceneBuilder","RSWorldVegetation","RSEnvironmentP4","RSEnvironmentP4Detail","RSManagedAssets","RSResourcesP45"}}
    require(len(rows)==len(models)==len({r["id"] for r in rows}),"Complete unique model inventory")
    for r in rows:
        b=models[r["id"]]
        require(b["path"][0]["name"]==r["root"] and all(abs(a-b)<.001 for a,b in zip(b["properties"]["pivot"],r["pivot"])) and abs(b["properties"]["scale"]-r["scale"])<.001,"Model differs from baseline")
        require(math.isfinite(r["radius"]) and r["radius"]>0 and r["records"]>=2,"Invalid source geometry")
    return models
def fixed_occupancy(base,rows):
    fixed=[]
    for r in rows:
        if r["playable"] and kind(r)!="fixed":continue
        if r.get("resourceType") in ("Stone","Stick"):continue # Explicitly replanned in S06.3.
        x,z=position(r)
        fixed.append({"id":r["id"],"x":x,"z":z,"radius":r["radius"]})
    for k,r in base["records"].items():
        if r.get("service")=="Workspace" and r.get("class")=="SpawnLocation":
            p=r["properties"];x,y,z=p["cframe"][:3]
            if abs(x)<384 and abs(z)<384:fixed.append({"id":k,"x":x,"z":z,"radius":max(8,math.hypot(p["size"][0],p["size"][2])/2)})
    fixed.append({"id":"central-exclusion","x":0,"z":0,"radius":45})
    return Occupancy(fixed)
def candidates(idx):
    result=[]
    # Native cell centers, shared global lattice; no tile-local random seams.
    for (i,j),(h,m,w) in sorted(idx.cells.items()):
        if m!="Grass" or w:continue
        x,z=i*4+2,j*4+2
        s=idx.support(x,z,3)
        if s is None or s["slope"]>23 or s["relief"]>3 or not idx.dry(x,z,5) or idx.water_clearance(x,z,8)<8:continue
        result.append((x,z,s["height"],idx.tile_of[(i,j)]))
    return result
def counts_by_tile(rows,idx):
    counts={t:Counter() for t in sorted(idx.tiles)}
    for r in rows:
        if r.get("playable") is False:continue
        if "tile" in r:t=r["tile"];k=r["kind"]
        else:t=tile_of(idx,*position(r));k=kind(r)
        if t in counts and k!="fixed":counts[t][k]+=1
    return {t:dict(c) for t,c in counts.items()}
def coverage(idx,rows):
    sites=[(r["position"][0],r["position"][2]) if "position" in r else position(r) for r in rows if (r.get("kind") or kind(r)) in ("tree","pine") and r.get("playable",True)]
    cells=[(i*4+2,j*4+2) for (i,j),(h,m,w) in idx.cells.items() if m=="Grass" and not w]
    # Area within 35 studs of a tree center, not measured canopy/render coverage.
    buckets=Occupancy({"id":str(i),"x":x,"z":z,"radius":35} for i,(x,z) in enumerate(sites))
    return sum(buckets.blocked(x,z,0.001) for x,z in cells)/len(cells)
def build(base,native,inventory,rules):
    require(base["stateDigest"]==sha(base["records"]) and inventory["loadedVersion"]==base["loadedVersion"] and inventory["stateDigest"]==base["stateDigest"],"Stale inventory")
    idx=native_index(base,native);rows=inventory["rows"];inventory_check(base,rows)
    old=[r for r in rows if r["playable"] and kind(r)!="fixed"]
    require(all(r["ground"] is not None and r["support"] is not None for r in old),"Missing ground provenance")
    require(all((r.get("collider") is not None)==(kind(r) in ("tree","pine")) for r in old),"Missing coupled collider")
    fixed=fixed_occupancy(base,rows)
    trunk=Occupancy();canopy=Occupancy();shrubs=Occupancy()
    rng=random.Random(rules["seed"]);pool=candidates(idx)
    require(pool,"No terrain candidates")
    high=percentile(idx.grass_heights,rules["pineMinPercentile"])
    # Deterministic clustered anchors per tile, with clearings between clusters.
    anchors=defaultdict(list)
    for t in sorted(idx.tiles):
        local=[p for p in pool if p[3]==t]
        require(local,"Empty playable tile")
        rng.shuffle(local)
        for p in local:
            if all(distance(p,a)>65 for a in anchors[t]):anchors[t].append(p)
            if len(anchors[t])==4:break
    byspecies=defaultdict(list)
    for r in old:byspecies[r["species"]].append(r)
    for v in byspecies.values():v.sort(key=lambda r:r["id"])
    requests=[]
    for sp,target in sorted(rules["speciesTargets"].items()):
        source=byspecies[sp];require(source and target>=len(source),"Species target must preserve all existing identities")
        for i in range(target):requests.append((source[i%len(source)],i<len(source),i))
    require(set(byspecies)==set(rules["speciesTargets"]),"Unhandled vegetation species")
    requests.sort(key=lambda q:({"pine":0,"tree":1,"bush":2}[kind(q[0])],q[2],q[0]["species"]))
    planned=[];reject=Counter();tileCounts=defaultdict(Counter)
    for src,reuse,i in requests:
        k=kind(src);sp=src["species"];id=src["id"] if reuse else "s06-"+sp.lower().replace("_","-").replace(".","-")+"-"+str(i+1).zfill(3)
        # Reserve final pine size now so S06.3 does not invalidate the layout.
        height=src["top"]-src["ground"]
        factor=rng.uniform(1.0,1.0) if k!="pine" else rng.uniform(64,76)/height
        radius=src["radius"]*factor
        d=src["collider"]["diameter"]*factor if src.get("collider") else 0
        tr=max(2,d/2+1) if k!="bush" else max(2,radius*.55)
        cr=radius*.62
        footprint=max(2,min(8,src["support"]*factor))
        require(0<footprint<=8 and d<=12,"Geometry profile range")
        def score(p):
            x,z,h,t=p;cluster=min(distance(p,a) for a in anchors[t])
            if k=="pine":return -h + tileCounts[t][k]*1.5 + cluster*.002
            # Prefer well distributed tiles, but with local groves/clearings.
            return tileCounts[t][k]*12+cluster*.38+rng.random()*13
        ordered=sorted(pool,key=score)
        chosen=None
        for x,z,h,t in ordered:
            if k=="pine" and h<high:reject["pine_altitude"]+=1;continue
            if k=="tree" and h>=high:reject["highland_reserved"]+=1;continue
            if max(abs(x),abs(z))+tr+5>=384:reject["boundary"]+=1;continue
            if fixed.blocked(x,z,tr+2) or trunk.blocked(x,z,tr+2) or shrubs.blocked(x,z,tr):reject["ground_occupancy"]+=1;continue
            if k!="bush" and canopy.blocked(x,z,cr):reject["canopy_spacing"]+=1;continue
            if not idx.dry(x,z,footprint) or idx.water_clearance(x,z,8)<8:reject["terrain_mask"]+=1;continue
            support=idx.support(x,z,footprint)
            if not support or support["slope"]>rules["maxSlope"] or support["relief"]>rules["maxRelief"]:reject["terrain_support"]+=1;continue
            chosen=(x,z,t,support);break
        require(chosen is not None,"Density target cannot fit: "+id)
        x,z,t,support=chosen;g=support["height"];y=g+(src["pivot"][1]-src["ground"])*factor
        out={"id":id,"sourceId":src["id"],"sourceRoot":src["root"],"targetRoot":"RSVegetationS06","species":sp,"kind":k,"tile":t,"action":"reuse" if reuse else "clone","sourcePivot":src["pivot"],"sourceScale":src["scale"],"sourceDigest":src.get("sourceDigest"),"asset":src["asset"],"scale":src["scale"]*factor,"scaleFactor":factor,"position":[x,y,z],"pivot":[x,y,z,*src["pivot"][3:]],"groundY":g,"supportRadius":footprint,"slope":support["slope"],"canopyRadius":radius,"canopySpacingRadius":cr,"groundRadius":tr,"sourceRecords":src["records"],"physicalHeight":height*factor}
        if k!="bush":
            col=src["collider"];cx=x+(col["shaft"][0]-src["pivot"][0])*factor;cz=z+(col["shaft"][2]-src["pivot"][2])*factor
            out["collider"]=cylinder_profile(cx,cz,g,g+height*factor,d)
            out["collider"]["group"]=col["group"]
            trunk.add({"id":id,"x":x,"z":z,"radius":tr});canopy.add({"id":id,"x":x,"z":z,"radius":cr})
        else:shrubs.add({"id":id,"x":x,"z":z,"radius":tr})
        tileCounts[t][k]+=1;planned.append(out)
    require(len({p["id"] for p in planned})==len(planned),"Duplicate destination identity")
    new=sum(p["sourceRecords"]+(2 if p["kind"]!="bush" else 0) for p in planned if p["action"]=="clone")+3
    budget=inventory_budget(base,[]);projected=base["total"]+budget["knownCloneEstimate"]+new
    result={"schemaVersion":1,"loadedVersion":base["loadedVersion"],"stateDigest":base["stateDigest"],"nativeSnapshotDigest":native["snapshotDigest"],"rulesDigest":sha(rules),"rows":planned,"preserveIds":[r["id"] for r in rows if not r["playable"] or kind(r)=="fixed"],"resourceReplanIds":[r["id"] for r in rows if r.get("resourceType") in ("Stone","Stick")],"noPlaceWrites":True,"applyAuthorized":False,"budget":{"current":base["total"],"newRecordsEstimate":new,"cloneEstimate":budget["knownCloneEstimate"],"projected":projected,"limit":5000,"reserve":500,"allowed":projected<=4500},"metrics":{"before":dict(Counter(kind(r) for r in old)),"after":dict(Counter(p["kind"] for p in planned)),"beforeTiles":counts_by_tile(old,idx),"afterTiles":counts_by_tile(planned,idx),"beforeCoverage35":coverage(idx,old),"afterCoverage35":coverage(idx,planned),"pineMinGround":min(p["groundY"] for p in planned if p["kind"]=="pine"),"broadleafMaxGround":max(p["groundY"] for p in planned if p["kind"]=="tree"),"pineThreshold":high,"pineHeightRange":[min(p["physicalHeight"] for p in planned if p["kind"]=="pine"),max(p["physicalHeight"] for p in planned if p["kind"]=="pine")],"rejections":dict(reject)},"limitations":["Preview only: resource positions must be replanned against final vegetation; no physical/visual client proof.","Canopy spacing is a conservative circle policy, not exact leaf intersection; trunk offsets and terrain contact need native coupled preview.","Existing Yasu width calibration remains provisional. Pine scaling is a reservation for S06.3.","New root requires wind and diagnostic consumer migration before publishing; no existing root deleted in this step."]}
    return result,idx
def render(idx,rows,plan,out):
    im=Image.new("RGB",(768,768),(29,34,39))
    d=ImageDraw.Draw(im)
    for (i,j),(h,m,w) in idx.cells.items():
        x,z=i*4+384,j*4+384
        c=(55,110,155) if w else (65+int(min(45,max(0,h))),108+int(min(35,max(0,h/2))),66) if m=="Grass" else (172,150,110)
        d.rectangle((x,z,x+3,z+3),fill=c)
    for name,points in (("before",[r for r in rows if r["playable"] and kind(r)!="fixed"]),("after",plan["rows"])):
        p=im.copy();d=ImageDraw.Draw(p)
        for r in points:
            x,z=(r["position"][0],r["position"][2]) if "position" in r else position(r)
            k=r.get("kind") or kind(r);size=5 if k=="pine" else 4 if k=="tree" else 2
            c={"pine":"#e9ba55","tree":"#d0e9ac","bush":"#79d0a0"}[k]
            x+=384;z+=384;d.ellipse((x-size,z-size,x+size,z+size),fill=c,outline="#25392e")
        for a in (256,512):d.line((a,0,a,768),fill="#b0b5a0",width=1);d.line((0,a,768,a),fill="#b0b5a0",width=1)
        p.save(out/(name+".png"))
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,default=ROOT/"dist/s06-2");p.add_argument("--offline",action="store_true");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    require(base["loadedVersion"]==16,"Expected v16 baseline")
    if a.offline:inv=read(a.output/"inventory.json")
    else:
        key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];base=require_current(target,key,16)
        inv=task(target,key,"do\n"+(ROOT/"tools/sync/regeneration_inventory.luau").read_text()+"\nend",read_version=16,compile_source=True)
        require(inv["noPlaceWrites"] and inv["loadedVersion"]==16,"Native inventory scope")
        inv["stateDigest"]=base["stateDigest"];write(a.output/"inventory.json",inv)
    plan,idx=build(base,read(DATA/"native.json"),inv,read(RULES))
    plan["planDigest"]=sha(plan);write(a.output/"plan.json",plan);render(idx,inv["rows"],plan,a.output)
    summary={k:plan[k] for k in ("loadedVersion","stateDigest","planDigest","budget","metrics","noPlaceWrites","applyAuthorized")}
    summary["retainedOutside"]=sum(not r["playable"] and kind(r)!="fixed" for r in inv["rows"])
    summary["resourcesReplan"]=len(plan["resourceReplanIds"])
    write(a.output/"summary.json",summary);print("S06_REGEN "+json.dumps(summary),flush=True)
if __name__=="__main__":main()
