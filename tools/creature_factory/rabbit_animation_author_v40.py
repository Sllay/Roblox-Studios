"""V40 motion candidate: organic breathing, articulated hop, gentle grooming head bow.

Source-only. Mesh skin-weight remediation is tracked separately and is NOT
claimed by this animation author.
"""
from __future__ import annotations
import numpy as np
import rabbit_animation_author_v39 as v39

CLIPS=dict(v39.CLIPS)
CLIPS["Idle"]=(3.6,72,True,0)
CLIPS["Walk"]=(1.02,72,True,1)
CLIPS["ScratchEar"]=(2.35,80,False,2)

def idle(rig):
    keys=[]
    # Slow inhale, longer exhale, with slight chest expansion and tiny ear lag.
    for phase,breath in ((0,0),(.12,.30),(.29,.85),(.40,1),(.53,.83),(.68,.38),(.84,.08),(1,0)):
        pose=v39.standing()
        pose["Chest"][0]+=.027*breath
        pose["Pelvis"][0]-=.008*breath
        pose["Head"][0]-=.014*breath
        pose["Shoulder_L"]=np.array([-.013*breath,0,0])
        pose["Shoulder_R"]=np.array([-.013*breath,0,0])
        pose["Ear_L"]=np.array([-.018*breath,0,0])
        pose["Ear_R"]=np.array([-.018*breath,0,0])
        keys.append((phase,pose))
    return keys,[]

# Vertical motion is explicitly paired with large thigh/shin/toe articulation.
# A full extension is required at takeoff, rather than vibrating the paw.
HOP=(
 (0.00,0.00, .30,-.42,.20,.09),
 (.13,-.055,.55,-.72,.27,.16),
 (.24,.08,-.34,.48,-.27,-.08),
 (.40,.43,-.48,.63,-.30,-.12),
 (.57,.39,-.24,.28,-.13,-.08),
 (.74,.12,.31,-.40,.19,.08),
 (.87,0.00,.43,-.55,.22,.10),
 (1.00,0.00,.30,-.42,.20,.09),
)
def walk(rig):
    keys=[];report=[]
    for t,y,hip,shin,toe,torso in HOP:
        pose=v39.standing()
        pose["RootYOffset"]=y
        pose["Pelvis"][0]+=.63*torso
        pose["Chest"][0]+=.37*torso
        pose["Head"][0]-=.56*torso
        for side in ("L","R"):
            pose["Hip_"+side]=np.array([hip,0,0])
            pose["Shin_"+side]=np.array([shin,0,0])
            pose["HindPaw_"+side]=np.array([toe,0,0])
        pose["Shoulder_L"]=np.array([-.09*max(y,0),0,0])
        pose["Shoulder_R"]=np.array([-.09*max(y,0),0,0])
        pose["Ear_L"]=np.array([-.11*max(y,0),0,0])
        pose["Ear_R"]=np.array([-.11*max(y,0),0,0])
        fk,_=rig.evaluate(pose)
        report.append({"phase":t,"root_y":y,"hip":hip,"shin":shin,
                       "hindpaw":toe,"head_y":float(fk["Head"][1,3]),
                       "hind_powered":True,"front_support":False})
        keys.append((t,pose))
    return keys,report

def groom(rig):
    keys,report=v39.groom(rig)
    # Bow the head subtly while the forepaw approaches; do not fold torso.
    # Recompute FK evidence after the change, not from stale V39 coordinates.
    for (t,pose),row in zip(keys,report):
        raised=row["raised"]
        pose["Head"]=np.asarray(pose["Head"])+np.array([-.17*raised,0,0])
        pose["Chest"]=np.asarray(pose["Chest"])+np.array([-.025*raised,0,0])
        fk,_=rig.evaluate(pose)
        row["head_y"]=float(fk["Head"][1,3])
        row["ear_tip"]=v39.ear_tip(fk).round(5).tolist()
        row["right_forepaw"]=fk["FrontPaw_R"][:3,3].round(5).tolist()
        row["head_bow"]=-.17*raised
    return keys,report

def run(rig):
    # Keep prior run as a diagnostic control until V40 skin-deformation review.
    return v39.run(rig)

def main():
    v39.CLIPS=CLIPS
    v39.idle=idle
    v39.walk=walk
    v39.groom=groom
    v39.run=run
    v39.main()

if __name__=="__main__":
    main()
