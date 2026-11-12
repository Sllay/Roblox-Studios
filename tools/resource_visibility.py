"""S06.3: visible resource clusters on existing terrain, with bounded paint intent.
No Place writes. Paint changes material only; exact native preview is separate.
"""
import argparse,math,random,json
from collections import Counter
from pathlib import Path
from scene_sync import ROOT,read,write,require,sha,state_path
from deploy import load_all,resolve
from vegetation_regeneration import native_index,fixed_occupancy,inventory_check
from resource_layout import dimensions
from spatial_index import Occupancy
GAME=ROOT/"games/maps/mapa-principal"
def build(base,native,inv,forest,old):
    require(forest["planDigest"]==sha({k:v for k,v in forest.items() if k!="planDigest"}) and forest["stateDigest"]==base["stateDigest"]==inv["stateDigest"],"Stale forest")
    idx=native_index(base,native);inventory_check(base,inv["rows"])
    occ=fixed_occupancy(base,inv["rows"])
    # Resources are deliberately allowed closer to the central origin than trees,
    # but still avoid actual spawn pads and trunks.
    occ.remove("central-exclusion")
    for r in forest["rows"]:
        x,y,z=r["position"];occ.add({"id":r["id"],"x":x,"z":z,"radius":r["groundRadius"]+1})
    rng=random.Random(60317)
    sources={r["id"]:r for r in inv["rows"] if r.get("resourceType") in ("Stone","Stick")}
    require(len(sources)==216 and set(sources)==set(forest["resourceReplanIds"]),"Resource identities")
    oldrows={r["id"]:r for r in old["resources"]};require(set(oldrows)==set(sources),"Old resource plan")
    assets=GAME/"game/assets"
    rock=next(r for r in read(assets/"audits/p4-environment-43181270756.json")["results"] if r["name"]=="Rock")
    stick=read(assets/"audits/s03-stick-extraction-v14.json")
    patches=[];placed=[];used=set();centers=Occupancy()
    # 36 little clearings, 4x4 native cells at most; 6 in central tile,
    # balance other tiles with 3 or 4, all 216 existing IDs retained.
    tiles=sorted(idx.tiles);central="chunk-0-0"
    targets={t:4 for t in tiles};targets[central]=6
    for t in (tiles[0],tiles[-1]):targets[t]=3
    for t in [central]+[x for x in tiles if x!=central]:
        b=idx.tiles[t];pool=[]
        for i in range(b[0]//4+2,b[3]//4-2):
            for j in range(b[2]//4+2,b[5]//4-2):
                x,z=i*4+4,j*4+4
                keys=[(i+di,j+dj) for di in (0,1) for dj in (0,1)]
                if any(k not in idx.cells or idx.cells[k][1]!="Grass" or idx.cells[k][2] for k in keys):continue
                s=idx.support(x,z,4)
                if not s or s["slope"]>10 or s["relief"]>1.5 or not idx.dry(x,z,5) or idx.water_clearance(x,z,8)<8:continue
                if occ.blocked(x,z,6):continue
                # Central clusters prioritize exploration close to origin, other tiles
                # prioritize proximity to forest edges without blocking trunks.
                d=math.hypot(x,z)
                score=(abs(d-65)*.8 if t==central else 0)+rng.random()*45
                pool.append((score,x,z,keys))
        n=0
        for _,x,z,keys in sorted(pool):
            if n>=targets[t]:break
            if any(k in used for k in keys) or centers.blocked(x,z,24):continue
            pid=f"clearing-{t}-{n+1:02d}"
            # Six separate points, with jitter and real support; no floating props.
            trial=[];local=Occupancy()
            for k in range(6):
                a=2*math.pi*k/6+rng.uniform(-.12,.12)
                rr=rng.uniform(2.1,2.6);px,pz=x+math.cos(a)*rr,z+math.sin(a)*rr
                cat="stone" if k%2==0 else "stick"
                size=rock["bounds"] if cat=="stone" else stick["size"]
                axis=max((0,2),key=lambda i:size[i]) if cat=="stone" else 1
                width=rng.uniform(.95,1.45) if cat=="stone" else rng.uniform(1.15,1.85)
                scale,sz=dimensions(size,width,axis)
                if cat=="stick":sz=[sz[1],sz[0],sz[2]]
                radius=math.hypot(sz[0],sz[2])/2
                s=idx.support(px,pz,max(.5,radius))
                if not s or s["slope"]>10 or s["relief"]>1.5 or local.blocked(px,pz,radius+.1) or occ.blocked(px,pz,radius+.5):break
                burial=min(.025,sz[1]*.08)
                trial.append({"category":cat,"patch":pid,"tile":t,"position":[px,s["height"]+sz[1]/2-burial,pz],"groundY":s["height"],"bounds":sz,"radius":radius,"yaw":rng.randrange(360),"orientation":"Z90" if cat=="stick" else "identity","scaleFactorFromSource":scale,"burial":burial,"anchored":True,"canCollide":True,"canQuery":True,"canTouch":False,"collisionGroup":"RSNaturalResource","contactStatus":"voxel_estimate","assetId":stick["assetId"] if cat=="stick" else rock["assetId"],"sourceDigest":stick["digest"] if cat=="stick" else rock["digest"]})
                local.add({"id":str(k),"x":px,"z":pz,"radius":radius})
            if len(trial)!=6:continue
            patches.append({"id":pid,"tile":t,"center":[x,z],"cells":[{"x":i*4,"z":j*4,"height":idx.cells[(i,j)][0],"from":"Grass","to":"Ground"} for i,j in keys]})
            used.update(keys);centers.add({"id":pid,"x":x,"z":z,"radius":12});placed.extend(trial);n+=1
        require(n==targets[t],"Clearing target "+t)
    for cat in ("stone","stick"):
        ids=sorted(r["id"] for r in old["resources"] if r["category"]==cat)
        group=[r for r in placed if r["category"]==cat]
        require(len(ids)==len(group)==108,"Resource count")
        for id,r in zip(ids,group):
            src=sources[id];r.update(id=id,sourcePivot=src["pivot"],sourceScale=src["scale"],targetScale=oldrows[id]["scaleFactorFromSource"] and src["scale"]*r["scaleFactorFromSource"]/oldrows[id]["scaleFactorFromSource"])
    require(len(patches)==36 and len(used)==144,"Paint budget")
    return {"schemaVersion":1,"loadedVersion":base["loadedVersion"],"stateDigest":base["stateDigest"],"forestDigest":forest["planDigest"],"resources":placed,"patches":patches,"pines":[r for r in forest["rows"] if r["kind"]=="pine"],"preserveLargeRocks":[r["id"] for r in inv["rows"] if "Mossy_Rock" in r["species"]],"noPlaceWrites":True,"applyAuthorized":False,"metrics":{"centralClusters":sum(p["tile"]==central for p in patches),"within100":dict(Counter(r["category"] for r in placed if math.hypot(r["position"][0],r["position"][2])<100)),"paintCells":len(used),"paintAreaStuds2":len(used)*16,"stoneWidth":[min(max(r["bounds"][0],r["bounds"][2]) for r in placed if r["category"]=="stone"),max(max(r["bounds"][0],r["bounds"][2]) for r in placed if r["category"]=="stone")],"stickLength":[min(r["bounds"][0] for r in placed if r["category"]=="stick"),max(r["bounds"][0] for r in placed if r["category"]=="stick")]},"limitations":["Material-only paint intent needs native inverse proof and final client appearance; exact grass occlusion not measured.","Existing vegetation/terrain are not changed in this step.","Avatar head scale is a proposed visual range, not measured custom avatar."]}
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,default=ROOT/"dist/s06-3");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    d=GAME/"docs/s06/regeneration-v16";old=GAME/"docs/spatial/v14"
    plan=build(base,read(old/"native.json"),read(d/"inventory.json"),read(d/"plan.json"),read(old/"s03/resource-plan.json"))
    plan["planDigest"]=sha(plan);write(a.output/"plan.json",plan)
    summary={k:plan[k] for k in ("planDigest","metrics","loadedVersion","forestDigest","noPlaceWrites")};summary.update(resources=len(plan["resources"]),pines=len(plan["pines"]),largeRocks=len(plan["preserveLargeRocks"]))
    write(a.output/"summary.json",summary);print("S063_PLAN "+json.dumps(summary),flush=True)
if __name__=="__main__":main()
