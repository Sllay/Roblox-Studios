"""Offline, version-bound top-surface index; native 4-stud voxel estimates.
Cross-tile interpolation, conservative wet/footprint masks, occupancy buckets
and deterministic placement. No Roblox writes, no runtime physics claims.
"""
from __future__ import annotations
import base64,math,random,struct
from collections import defaultdict,Counter
from scene_sync import require,sha

STEP=4
ROOTS={"RSVegetationS06","RSSceneBuilder","RSWorldVegetation","RSEnvironmentP4","RSEnvironmentP4Detail","RSManagedAssets"}

def decode_tile(tile,materials):
    b=tile["bounds"];nx,nz=tile["nx"],tile["nz"]
    require(len(b)==6 and all(type(v) is int and v%4==0 for v in b) and nx==(b[3]-b[0])//4 and nz==(b[5]-b[2])//4 and 0<nx<=256 and 0<nz<=256,"Native tile alignment")
    data=base64.b64decode(tile["samples"],validate=True)
    require(len(data)==nx*nz*7,"Native tile payload length")
    rows=[]
    for h,m,w in struct.iter_unpack("<fHB",data):
        require(math.isfinite(h) and b[1]-0.01<=h<=b[4]+0.01 and str(m) in materials and w in (0,1),"Invalid native sample")
        rows.append((h,materials[str(m)],bool(w)))
    return rows

def percentile(values,q):
    require(values and 0<=q<=1,"Percentile bounds")
    return sorted(values)[max(0,math.ceil(len(values)*q)-1)]

class SurfaceIndex:
    def __init__(self,tiles,materials):
        self.cells={};self.tiles={};self.tile_of={}
        for t in sorted(tiles,key=lambda x:x["id"]):
            require(t["id"] not in self.tiles,"Duplicate tile")
            self.tiles[t["id"]]=t["bounds"]
            x0,z0=t["bounds"][0]//4,t["bounds"][2]//4
            for n,row in enumerate(decode_tile(t,materials)):
                k=(x0+n%t["nx"],z0+n//t["nx"])
                require(k not in self.cells,"Overlapping native tiles")
                self.cells[k]=row;self.tile_of[k]=t["id"]
        self.grass_heights=sorted(h for h,m,w in self.cells.values() if m=="Grass" and not w)
        self.p80=percentile(self.grass_heights,.8)
    @staticmethod
    def cell_key(x,z):return math.floor(x/4),math.floor(z/4)
    def height(self,x,z,materials=("Grass",)):
        gx,gz=(x-2)/4,(z-2)/4;i,j=math.floor(gx),math.floor(gz)
        rows=[self.cells.get(k) for k in ((i,j),(i+1,j),(i,j+1),(i+1,j+1))]
        if any(r is None or r[1] not in materials or r[2] for r in rows):return None
        a,c,d,f=[r[0] for r in rows];tx,tz=gx-i,gz-j
        return (a+(c-a)*tx)*(1-tz)+(d+(f-d)*tx)*tz
    def support(self,x,z,r,materials=("Grass",)):
        require(math.isfinite(r) and 0<r<=32,"Support radius")
        values=[self.height(a,b,materials) for a,b in ((x,z),(x+r,z),(x-r,z),(x,z+r),(x,z-r))]
        if any(v is None for v in values):return None
        h,a,b,c,d=values;dx,dz=(a-b)/(2*r),(c-d)/(2*r)
        length=math.sqrt(1+dx*dx+dz*dz)
        return {"height":h,"slope":math.degrees(math.atan(math.hypot(dx,dz))),"relief":max(values)-min(values),"normal":[-dx/length,1/length,-dz/length]}
    @staticmethod
    def cell_distance(x,z,i,j):
        return math.hypot(max(i*4-x,0,x-(i+1)*4),max(j*4-z,0,z-(j+1)*4))
    def nearby_cells(self,x,z,r):
        for i in range(math.floor((x-r)/4)-1,math.floor((x+r)/4)+1):
            for j in range(math.floor((z-r)/4)-1,math.floor((z+r)/4)+1):
                d=self.cell_distance(x,z,i,j)
                if d<=r:yield (i,j),d,self.cells.get((i,j))
    def dry(self,x,z,r,materials=("Grass",)):
        require(0<=r<=64,"Footprint radius")
        return all(c is not None and c[1] in materials and not c[2] for _,_,c in self.nearby_cells(x,z,r))
    def water_clearance(self,x,z,cap):
        require(0<cap<=64,"Clearance range")
        # Distance to wet cell footprint; unknown exterior is treated as unsafe.
        return min((d for _,d,c in self.nearby_cells(x,z,cap) if c is None or c[2]),default=cap)
    def evaluate(self,x,z,rule,occupancy,ignore=None):
        if not self.dry(x,z,rule["footprint"],tuple(rule["materials"])):return "mask",None
        if self.water_clearance(x,z,rule["waterClearance"])<rule["waterClearance"]:return "water",None
        support=self.support(x,z,rule["supportRadius"],tuple(rule["materials"]))
        if not support or support["slope"]>rule["maxSlope"] or support["relief"]>rule["maxRelief"]:return "slope",None
        if rule.get("altitudePercentile") is not None and support["height"]<percentile(self.grass_heights,rule["altitudePercentile"]):return "altitude",None
        if occupancy.blocked(x,z,rule["radius"]+rule["spacing"],ignore):return "occupied",None
        return None,support

class Occupancy:
    def __init__(self,rows=()):
        self.rows={};self.buckets=defaultdict(set)
        for r in rows:self.add(r)
    @staticmethod
    def keys(x,z,r):
        for i in range(math.floor((x-r)/32),math.floor((x+r)/32)+1):
            for j in range(math.floor((z-r)/32),math.floor((z+r)/32)+1):yield i,j
    def add(self,row):
        require(row["id"] not in self.rows and 0<=row["radius"]<=2048,"Occupancy identity/radius")
        self.rows[row["id"]]=row
        for k in self.keys(row["x"],row["z"],row["radius"]):self.buckets[k].add(row["id"])
    def remove(self,id):
        row=self.rows.pop(id)
        for k in self.keys(row["x"],row["z"],row["radius"]):self.buckets[k].discard(id)
    def blocked(self,x,z,r,ignore=None):
        for k in self.keys(x,z,r):
            for id in self.buckets.get(k,()):
                if id==ignore:continue
                o=self.rows[id]
                if math.hypot(x-o["x"],z-o["z"])<r+o["radius"]:return True
        return False

def observed_occupancy(base,species_by_id):
    rows=[r for r in base["records"].values() if r.get("service")=="Workspace" and r.get("path")]
    models=[r for r in rows if r.get("class")=="Model" and r["path"][0]["name"] in ROOTS and len(r["path"])==(2 if r["path"][0]["name"]=="RSManagedAssets" else 3)]
    parts=[r for r in rows if r.get("coverage")=="basepart"]
    out=[]
    for m in models:
        p=m["properties"]["pivot"];children=[r for r in parts if r["path"][:len(m["path"])]==m["path"]]
        require(children,"Managed model has no observed parts")
        # Conservative footprint from transformed local part corners.
        radius=0
        for c in children:
            cf=c["properties"]["cframe"];s=c["properties"]["size"]
            dx,dz=abs(cf[0]-p[0]),abs(cf[2]-p[2])
            ex=sum(abs(cf[3+i])*s[i]/2 for i in range(3));ez=sum(abs(cf[9+i])*s[i]/2 for i in range(3))
            radius=max(radius,math.hypot(dx+ex,dz+ez))
        id=m["managedId"] or "path:"+sha(m["path"])
        out.append({"id":id,"name":m["name"],"root":m["path"][0]["name"],"species":species_by_id.get(id),"x":p[0],"y":p[1],"z":p[2],"radius":radius,"scale":m["properties"]["scale"]})
    for r in parts:
        if r["class"]!="SpawnLocation":continue
        p=r["properties"]["cframe"];s=r["properties"]["size"]
        out.append({"id":r["managedId"] or "spawn:"+sha(r["path"]),"name":r["name"],"root":"spawn","species":None,"x":p[0],"y":p[1],"z":p[2],"radius":max(8,math.hypot(s[0],s[2])/2),"scale":1})
    # Existing dedicated planner excludes central 45 studs.
    out.append({"id":"central-exclusion","name":"Central spawn exclusion","root":"policy","species":None,"x":0,"y":0,"z":0,"radius":45,"scale":1})
    return out

def validate_rule(rule):
    require(set(rule["materials"])=={"Grass"},"Initial grass-only policy")
    for k,lo,hi in (("radius",.1,64),("footprint",.1,64),("waterClearance",.1,64),("supportRadius",.1,32),("maxSlope",0,60),("maxRelief",0,16),("spacing",0,32)):
        v=rule[k];require(type(v) in (int,float) and math.isfinite(v) and lo<=v<=hi,"Invalid rule "+k)
    q=rule.get("altitudePercentile");require(q is None or (type(q) in (int,float) and 0<=q<=1),"Altitude rule")
    return rule

def place_candidates(index,occupied,rule,seed,count_per_tile,category):
    validate_rule(rule);require(type(count_per_tile) is int and 0<=count_per_tile<=64,"Per tile budget")
    rng=random.Random(seed);result=[];stats={}
    for id,b in sorted(index.tiles.items()):
        rejected=Counter();count=0
        for _ in range(3000):
            if count>=count_per_tile:break
            margin=max(4,rule["radius"]+rule["spacing"])
            x=round(rng.uniform(b[0]+margin,b[3]-margin),2);z=round(rng.uniform(b[2]+margin,b[5]-margin),2)
            reason,s=index.evaluate(x,z,rule,occupied)
            if reason:rejected[reason]+=1;continue
            count+=1;rid=f"{category}:{id}:{count:02d}"
            row={"id":rid,"category":category,"tile":id,"x":x,"z":z,"groundY":s["height"],"slope":s["slope"],"normal":s["normal"],"radius":rule["radius"]}
            result.append(row);occupied.add({"id":rid,"x":x,"z":z,"radius":rule["radius"]})
        stats[id]={"placed":count,"requested":count_per_tile,"rejected":dict(rejected)}
    return result,stats
