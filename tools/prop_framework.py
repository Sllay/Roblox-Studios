"""S07 shared deterministic prop planning. Offline estimates only; never publishes."""
from __future__ import annotations
import hashlib, math, random
from collections import Counter
from spatial_index import Occupancy

TEMPLATES={
 "ResourceProp":{"materials":["Grass","Ground"],"spacing":4,"waterClearance":4,"maxSlope":35,"maxRelief":5,"align":"surface","burial":0,"randomYaw":True,"variation":.2},
 "VegetationProp":{"materials":["Grass"],"spacing":4,"waterClearance":6,"maxSlope":25,"maxRelief":3,"align":"upright","burial":0,"randomYaw":True,"variation":.1},
}
def resolve(spec):
    if spec["template"] not in TEMPLATES: raise ValueError("Unknown template")
    r={**TEMPLATES[spec["template"]],**spec}
    if not isinstance(r["count"],int) or not 0<=r["count"]<=10000: raise ValueError("Count")
    if not 0<r["radius"]<=16 or not 0<=r["variation"]<1: raise ValueError("Geometry")
    if r["align"] not in ("surface","upright"): raise ValueError("Alignment")
    return r

def rng_for(seed,*parts):
    key=":".join(map(str,(seed,*parts)))
    return random.Random(int.from_bytes(hashlib.sha256(key.encode()).digest()[:8],"big"))

def plan(index, fixed, specs, seed):
    """Global occupancy, independent per-spec RNG, area-weighted tile quotas."""
    occ=Occupancy(fixed); rows=[]; reports={}
    ids=[s["id"] for s in specs]
    if len(ids)!=len(set(ids)): raise ValueError("Duplicate prop type")
    for spec in sorted(specs,key=lambda s:s["id"]):
        r=resolve(spec); name=r["id"]; rng=rng_for(seed,name)
        radius=r["radius"]*(1+r["variation"])
        rule={**r,"radius":radius,"footprint":radius,"supportRadius":max(.5,radius)}
        pools={t:[] for t in sorted(index.tiles)}
        for (i,j),(_,m,w) in sorted(index.cells.items()):
            if w or m not in r["materials"]: continue
            x,z=i*4+2,j*4+2
            reason,_=index.evaluate(x,z,rule,occ)
            if not reason: pools[index.tile_of[(i,j)]].append((x,z))
        total=sum(map(len,pools.values()))
        if not total and r["count"]: raise ValueError("No eligible area for "+name)
        weights={t:r["count"]*len(p)/max(1,total) for t,p in pools.items()}
        quotas={t:math.floor(w) for t,w in weights.items()}
        for t in sorted(weights,key=lambda t:(-(weights[t]-quotas[t]),t))[:r["count"]-sum(quotas.values())]: quotas[t]+=1
        rejected=Counter(); counts=Counter()
        for t,pool in pools.items():
            local=rng_for(seed,name,t); local.shuffle(pool)
            for x,z in pool:
                if counts[t]>=quotas[t]: break
                x+=local.uniform(-1.5,1.5); z+=local.uniform(-1.5,1.5)
                if index.tile_of.get(index.cell_key(x,z))!=t: continue
                reason,s=index.evaluate(x,z,rule,occ)
                if reason: rejected[reason]+=1;continue
                n=counts[t]+1; rid=f"s07:{name}:{t}:{n:04d}"
                scale=local.uniform(1-r["variation"],1+r["variation"])
                row={"id":rid,"type":name,"tile":t,"x":x,"z":z,"groundY":s["height"],"normal":s["normal"] if r["align"]=="surface" else [0,1,0],"yaw":local.uniform(0,360) if r["randomYaw"] else 0,"scale":scale,"radius":r["radius"]*scale,"contactStatus":"voxel_estimate_only"}
                rows.append(row);occ.add({"id":rid,"x":x,"z":z,"radius":row["radius"]});counts[t]+=1
        reports[name]={"requested":r["count"],"placed":sum(counts.values()),"quotas":quotas,"counts":dict(counts),"rejected":dict(rejected)}
    return {"rows":rows,"reports":reports,"complete":all(x["placed"]==x["requested"] for x in reports.values()),"noPlaceWrites":True}
