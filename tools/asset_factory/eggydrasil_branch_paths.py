"""V4 branch centerlines, derived from the approved direct-modelled source.
This module reproduces the original curve sampling without modifying the wood.
Endpoint parity is checked against the immutable V4 artifact before placement.
"""
import math
from mathutils import Vector
def cat(p0,p1,p2,p3,t):
    return .5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)

def paths_from_v4():
    paths=[];anchors=[]
    def sweep(name,points,radii,sides=12,steps=4,flute=.12,twist=.6):
        P=[Vector(p) for p in points];C=[];R=[]
        for i in range(len(P)-1):
            for j in range(steps):
                t=j/steps
                C.append(cat(P[max(0,i-1)],P[i],P[i+1],P[min(len(P)-1,i+2)],t))
                R.append(radii[i]*(1-t)+radii[i+1]*t)
        C.append(P[-1]);R.append(radii[-1])
        paths.append(dict(name=name,points=C,radii=R,kind="twig" if "_twig" in name else "fork" if "_fork" in name else "major"))
        return C
    branches=[
    ("lower_left", [(-.4,-.6,12),(-4,-.8,15),(-8,-1.4,18),(-12,-.6,17),(-16,.1,16),(-20,-.8,19)], [2.45,2.35,1.8,1.35,.8,.13]),
    ("lower_right",[(.7,-.8,13),(4,-1,17),(8,-.5,19),(12,0,17.8),(16,-.7,18.5),(20,-1.5,21)],[2.35,2.15,1.65,1.2,.7,.12]),
    ("middle_left",[(1.4,.2,19),(-2,.5,23),(-6,.2,25),(-10,-.4,23.5),(-14,-.6,24),(-18,.4,27)],[2.1,1.95,1.55,1.1,.65,.12]),
    ("middle_right",[(1.2,.4,21),(5,.8,25),(9,1.1,26),(13,1,24),(17,.2,26),(20,1,29)],[2.05,1.9,1.45,1.05,.58,.10]),
    ("upper_left",[(.2,.3,26),(-3,.8,29),(-6,1.2,31),(-10,1.5,30),(-13,.4,32),(-15,0,35)],[1.75,1.5,1.15,.85,.45,.09]),
    ("upper_right",[(.1,.2,28),(4,.1,32),(7,-.6,35),(10,-.4,34),(13,.2,35),(15,.7,38)],[1.65,1.4,1.0,.7,.4,.08]),
    ("top_left",[(.4,.2,31),(-2,.4,35),(-5,-.3,38),(-8,-.8,38),(-10,-.5,41)],[1.4,1.15,.8,.45,.08]),
    ("top_right",[(1,.2,33),(4,.1,36),(5,1,39),(4.8,1.6,42)],[1.15,.87,.5,.08]),
    ("rear_crown",[(0,1,22),(.8,4,25),(-1,8,27),(-3,11,29),(-4,13,33)],[1.85,1.45,1.05,.6,.10]),
    ("rear_upper",[(0,1,28),(2,4,31),(5,7,32),(7,10,36)],[1.4,1.05,.6,.09]),
    ]
    # Angles in Blender XY: +X right, -Y front. Each of eight sectors has a major limb.
    target_angles=[180,0,225,45,135,315,157,22,90,270]
    coverage=set();sector_report=[]
    for k,(name,points,radii) in enumerate(branches):
        origin=Vector(points[0]);delta=Vector(points[-1])-origin
        angle=math.radians(target_angles[k])-math.atan2(delta.y,delta.x)
        def rotate(v):
            return Vector((math.cos(angle)*v.x-math.sin(angle)*v.y,math.sin(angle)*v.x+math.cos(angle)*v.y,v.z))
        # Preserve curves and vertical profile. Extend short depth limbs to fill the crown.
        scale=1.0 if k<8 else (1.25 if k==8 else 1.55)
        def transform(p):
            d=rotate(Vector(p)-origin);d.x*=scale;d.y*=scale;return origin+d
        C=sweep(name,[transform(p) for p in points],radii,12,4,.19,1.25)
        d=C[-1]-origin;sector=int((math.degrees(math.atan2(d.y,d.x))+22.5)%360//45)
        coverage.add(sector);sector_report.append(dict(branch=name,sector=sector,azimuth=round(math.degrees(math.atan2(d.y,d.x))%360,2),reach=round(math.hypot(d.x,d.y),2)))
    
        # Forks arise exactly on parent centerline, with outward and upward curves.
        sign=-1 if "left" in name else 1
        for j,t in enumerate((.43,.65,.82)):
            start=C[round(t*(len(C)-1))];r=(1-t)*radii[0]*.66+.12
            dx=sign*(2.4+j*.75);dy=(-1 if j%2==0 else 1)*(1.8+.7*(k%3));dz=3.6+j*.35
            if name.startswith("rear"):dx=(-1 if j%2 else 1)*3;dy=2
            end=start+rotate(Vector((dx,dy,dz)));mid=start+rotate(Vector((dx*.5,dy*.3,dz*.3)))
            tip=sweep(name+"_fork%d"%j,[start,mid,end+rotate(Vector((-.4*sign,0,-.4))),end],[r,r*.78,r*.32,.06],8,3,.13,.7)
            anchors.append(list(end))
            for h in range(2):
                s=tip[round((.55+h*.2)*(len(tip)-1))];e=s+rotate(Vector((sign*(1.4+h*.7),(-1 if h==0 else 1)*1.2,1.9+h*.7)))
                sweep(name+"_twig%d%d"%(j,h),[s,s.lerp(e,.55)+Vector((0,0,-.25)),e],[r*.30,r*.20,.035],6,2,.09,.3);anchors.append(list(e))
    
    assert coverage==set(range(8))
    return paths,anchors
def calibrated_paths(approved_anchors):
    paths,anchors=paths_from_v4()
    assert len(anchors)==len(approved_anchors)==90
    # Original wood was translated only in Z to align its bottom to the ground.
    shift=sum(b.z-a[2] for a,b in zip(anchors,approved_anchors))/len(anchors)
    assert max((Vector(a)+Vector((0,0,shift))-b).length for a,b in zip(anchors,approved_anchors))<1e-4
    for path in paths:
        path["points"]=[p+Vector((0,0,shift)) for p in path["points"]]
    return paths
