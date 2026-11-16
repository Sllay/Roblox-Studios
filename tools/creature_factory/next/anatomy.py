"""Universal declared anatomy. No fixed species ontology or inferred parts.

Identity.anatomy is an optional, versioned graph in the existing manifest.
Anatomy declarations express intent, not measured mesh segmentation.
"""
from dataclasses import dataclass,asdict,field
import re
from .contracts import require,finite

def ident(x):return isinstance(x,str) and bool(re.fullmatch("[a-z][a-z0-9_]{0,79}",x))
@dataclass(frozen=True)
class Part:
    id:str
    kind:str
    parent:str|None=None
    side:str="none"
    mirror:str|None=None
    protected:bool=False
    thin:bool=False
    articulation:str="none"
    description:str=""
    def __post_init__(self):
        require(ident(self.id) and ident(self.kind),"Invalid part ID/kind")
        require(self.parent is None or ident(self.parent),"Invalid parent")
        require(self.mirror is None or ident(self.mirror),"Invalid mirror")
        require(self.side in ("none","left","right","midline"),"Invalid anatomical side")
        require(self.articulation in ("none","hinge","ball","flexible","custom"),"Invalid articulation")
        require(type(self.protected)==bool and type(self.thin)==bool,"Part flags")
@dataclass(frozen=True)
class Anatomy:
    parts:list[Part]
    counts:dict[str,int]=field(default_factory=dict)
    schema:int=1
    def __post_init__(self):
        require(self.schema==1 and 0<len(self.parts)<=512,"Anatomy schema/size")
        ids={p.id:p for p in self.parts}
        require(len(ids)==len(self.parts),"Duplicate part ID")
        roots=[p for p in self.parts if p.parent is None]
        require(len(roots)==1,"Exactly one structural root required")
        for p in self.parts:
            require(p.parent is None or p.parent in ids,"Unknown parent")
            seen={p.id};q=p
            while q.parent is not None:
                require(q.parent not in seen,"Anatomy cycle")
                seen.add(q.parent);q=ids[q.parent]
            if p.mirror:
                require(p.mirror in ids and p.mirror!=p.id,"Invalid mirror reference")
                other=ids[p.mirror]
                require(other.mirror==p.id and other.kind==p.kind and {p.side,other.side}=={"left","right"},"Mirror must be reciprocal and opposite-sided")
        actual={}
        for p in self.parts:actual[p.kind]=actual.get(p.kind,0)+1
        for k,n in self.counts.items():
            require(ident(k) and type(n)==int and n>=0,"Invalid part count")
            require(actual.get(k,0)==n,f"Declared {k} count disagrees with graph")
    @classmethod
    def read(cls,raw):
        require(isinstance(raw,dict),"Anatomy must be object")
        return cls([Part(**p) for p in raw["parts"]],raw.get("counts",{}),raw.get("schema",1))
    def summary(self):
        kinds={}
        for p in self.parts:kinds[p.kind]=kinds.get(p.kind,0)+1
        return {"schema":1,"parts":len(self.parts),"counts":kinds,"protected_parts":[p.id for p in self.parts if p.protected],"thin_parts":[p.id for p in self.parts if p.thin],"articulated_parts":[p.id for p in self.parts if p.articulation!="none"],"status":"declared_intent_only","geometry_verified":False,"semantic_detector_required":False}

def validate_anatomy(manifest):
    raw=manifest.identity.get("anatomy")
    if raw is None:return {"status":"not_declared","geometry_verified":False}
    require(manifest.profile=="creature","Anatomy graph requires creature profile")
    return Anatomy.read(raw).summary()

def check_part_evidence(anatomy,observations):
    """Conservative count check on explicitly identified, verified parts.
    Unknown/occluded parts are not evidence of absence. No descriptor or
    generated mesh automatically qualifies as reviewed physical identity.
    """
    ids={p.id:p for p in anatomy.parts};seen=set();confirmed=set();unknown=[]
    for o in observations:
        require(isinstance(o,dict) and o.get("part_id") in ids,"Unknown observed part")
        p=o["part_id"];require(p not in seen,"Duplicate part evidence");seen.add(p)
        require(o.get("state") in ("present","absent","unknown"),"Invalid part evidence")
        if o.get("state")=="present" and o.get("provenance")=="reviewed_geometry":confirmed.add(p)
        else:unknown.append(p)
    missing=sorted(set(ids)-confirmed)
    return {"confirmed":sorted(confirmed),"unverified":missing,"status":"all_declared_parts_reviewed" if not missing else "incomplete","automatic_artistic_approval":False}
