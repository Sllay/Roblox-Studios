
"""Validated placement profiles. Unknown mounts fail closed; no guessed offsets."""
import math

def number(v,lo,hi):
    return type(v) in (int,float) and math.isfinite(v) and lo<=v<=hi

def validate_profile(p):
    if not isinstance(p,dict) or p.get("schemaVersion")!=1:
        raise ValueError("Placement profile required")
    if p.get("mountType") not in ("sit_on_ground","bury_in_ground") or p.get("orientation")!="upright" or p.get("contactRule") not in ("bounds_bottom_plus_burial","local_anchor"):
        raise ValueError("Unsupported placement profile")
    for k,lo,hi in (("buryDepthStuds",0,64),("supportRadiusStuds",0.1,256),("maxSlopeDegrees",0,45),("maxHeightDeltaStuds",0,32),("rayTop",-100000,100000),("rayBottom",-100000,100000)):
        if not number(p.get(k),lo,hi): raise ValueError("Invalid placement field "+k)
    if p["contactRule"]=="local_anchor" and (not isinstance(p.get("contactLocal"),list) or len(p["contactLocal"])!=3 or not all(number(x,-512,512) for x in p["contactLocal"])):raise ValueError("Invalid local contact anchor")
    if p["mountType"]=="sit_on_ground" and p["buryDepthStuds"]!=0:raise ValueError("Sit profile cannot bury")
    if p["rayTop"]<=p["rayBottom"] or p["rayTop"]-p["rayBottom"]>4096:raise ValueError("Invalid ray range")
    names=p.get("groundNames")
    if not isinstance(names,list) or not 1<=len(names)<=16 or not all(isinstance(n,str) and 1<=len(n)<=100 for n in names):raise ValueError("Explicit ground names required")
    if p.get("calibrationStatus") not in ("provisional","verified"):raise ValueError("Missing calibration status")
    return p

def pivot_y(ground_y,bottom_offset,depth):
    if not all(number(v,-100000,100000) for v in (ground_y,bottom_offset,depth)) or depth<0:raise ValueError("Invalid placement geometry")
    return ground_y-bottom_offset-depth
