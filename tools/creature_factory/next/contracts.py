"""Versioned C1 input and artifact contracts. No inferred calibration."""
from __future__ import annotations
from dataclasses import dataclass, field, asdict
from pathlib import Path
import hashlib, json, math, re
from typing import Literal
from .audit import sha256, evidence_path

class ContractError(ValueError): pass
VIEWS=("front","back","left","right","top","bottom","three-quarter")
PROFILES=("creature","thin_surface","organic_prop","hard_surface")
def require(ok,msg):
    if not ok: raise ContractError(msg)
def finite(v):
    if isinstance(v,float): require(math.isfinite(v),"Nonfinite value")
    elif isinstance(v,dict):
        for x in v.values(): finite(x)
    elif isinstance(v,(list,tuple)):
        for x in v: finite(x)
def digest(v):
    return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(",",":"),allow_nan=False).encode()).hexdigest()
def path_inside(root,name):
    p=Path(name)
    require(not p.is_absolute() and ".." not in p.parts,"Unsafe relative path")
    p=(root/p).resolve()
    require(p.is_relative_to(root.resolve()),"Path escapes root")
    return p

@dataclass(frozen=True)
class CameraCalibration:
    status: Literal["known","estimated","unknown"]
    projection: str | None = None
    world_from_camera: list | None = None
    ortho_scale: float | None = None
    intrinsics: list | None = None
    confidence: float | None = None
    def __post_init__(self):
        finite(asdict(self));require(self.status in ("known","estimated","unknown"),"Invalid camera status")
        if self.status=="unknown":
            require(self.world_from_camera is None and self.intrinsics is None and self.ortho_scale is None,"Unknown camera cannot claim calibration")
            return
        require(self.projection in ("orthographic","perspective"),"Invalid projection")
        require(isinstance(self.confidence,(int,float)) and 0<=self.confidence<=1,"Camera confidence")
        m=self.world_from_camera
        require(isinstance(m,list) and len(m)==4 and all(isinstance(r,list) and len(r)==4 for r in m),"Camera matrix shape")
        require(all(isinstance(x,(int,float)) for r in m for x in r) and m[3]==[0,0,0,1],"Camera affine matrix")
        cols=[[m[i][j] for i in range(3)] for j in range(3)]
        require(all(abs(sum(a*b for a,b in zip(cols[i],cols[j]))-(i==j))<1e-4 for i in range(3) for j in range(3)),"Camera rotation not orthonormal")
        det=sum(cols[0][i]*(cols[1][(i+1)%3]*cols[2][(i+2)%3]-cols[1][(i+2)%3]*cols[2][(i+1)%3]) for i in range(3))
        require(abs(det-1)<1e-4,"Camera handedness")
        if self.projection=="orthographic": require(isinstance(self.ortho_scale,(int,float)) and self.ortho_scale>0,"Invalid ortho scale")
        else: require(isinstance(self.intrinsics,list) and len(self.intrinsics)==3 and all(len(r)==3 for r in self.intrinsics) and self.intrinsics[0][0]>0 and self.intrinsics[1][1]>0,"Invalid intrinsics")

@dataclass(frozen=True)
class ReferenceView:
    id: str
    source: str
    sha256: str
    crop: list[int]
    camera: CameraCalibration
    def __post_init__(self):
        require(self.id in VIEWS,"Unknown view")
        require(re.fullmatch("[0-9a-f]{64}",self.sha256),"Bad source hash")
        require(len(self.crop)==4 and all(type(x)==int for x in self.crop),"Crop must be four integers")
        x,y,w,h=self.crop;require(min(x,y)>=0 and min(w,h)>0,"Invalid crop")

@dataclass(frozen=True)
class AssetManifest:
    asset_id: str
    profile: str
    views: list[ReferenceView]
    schema: int=1
    units: str="stud"
    axes: str="right-handed Z-up front -Y"
    scale: float=1.
    symmetry: str="none"
    legacy: bool=False
    parts: list[dict]=field(default_factory=list)
    landmarks: list[dict]=field(default_factory=list)
    articulations: list[dict]=field(default_factory=list)
    protected_regions: list[dict]=field(default_factory=list)
    thin_parts: list[dict]=field(default_factory=list)
    materials: dict=field(default_factory=dict)
    identity: dict=field(default_factory=dict)
    rig_required: bool=False
    def __post_init__(self):
        finite(asdict(self));require(self.schema==1,"Unsupported schema")
        require(bool(re.fullmatch("[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}",self.asset_id)),"Invalid asset ID")
        require(self.profile in PROFILES and self.symmetry in ("none","bilateral","intentional_asymmetry"),"Invalid profile/symmetry")
        require(self.units in ("stud","m","cm","unit") and self.axes=="right-handed Z-up front -Y" and self.scale>0,"Invalid units/axes/scale")
        ids=[v.id for v in self.views];require(len(ids)==len(set(ids)) and bool(ids),"Duplicate/missing views")
        require(self.legacy or len(set(v.source for v in self.views))==1,"New intake requires one sheet")
        require(self.legacy or set(ids)==set(VIEWS),"Seven views required")
        for v in self.views:
            for u in self.views:
                if v.id>=u.id or v.source!=u.source:continue
                a,b,c,d=v.crop;e,f,g,h=u.crop
                require(not (max(a,e)<min(a+c,e+g) and max(b,f)<min(b+d,f+h)),"Overlapping reference crops")
    @classmethod
    def read(cls,path):
        raw=json.loads(Path(path).read_text());finite(raw)
        views=[]
        for v in raw.pop("views"):
            v=dict(v);v["camera"]=CameraCalibration(**v["camera"]);views.append(ReferenceView(**v))
        return cls(views=views,**raw)

@dataclass(frozen=True)
class GeometryArtifact:
    path:str;sha256:str;units:str;vertices:int;triangles:int
    schema:int=1
@dataclass(frozen=True)
class EvidenceBundle:
    view_id:str;camera:CameraCalibration;mask:str;depth:str;normals:str
    confidence:str|None=None;schema:int=1
    convention:str="camera-forward distance; world XYZ normals; top-left array; zero background"
@dataclass(frozen=True)
class ExportTarget:
    name:str;format:str;max_triangles_per_mesh:int|None=None;schema:int=1
@dataclass(frozen=True)
class QualityReport:
    status:str;metrics:dict;limitations:list[str];schema:int=1
    artistic_approval:bool=False;publication_allowed:bool=False
@dataclass(frozen=True)
class StageResult:
    stage:str;version:str;state:str;key:str;attempt:str|None=None
    outputs:dict=field(default_factory=dict);metrics:dict=field(default_factory=dict)
    dependencies:dict=field(default_factory=dict);config:dict=field(default_factory=dict)
    duration_seconds:float=0.;cause:str|None=None;limitations:list[str]=field(default_factory=list)
    backend:str="c1";schema:int=1
@dataclass(frozen=True)
class JobManifest:
    asset_id:str;manifest_path:str;config:dict;stages:dict
    schema:int=1;artistic_approval:bool=False;publication_allowed:bool=False

def validate_manifest(m,root,alpha_threshold=16):
    from PIL import Image
    diagnostics=[];images={}
    require(type(alpha_threshold)==int and 0<alpha_threshold<=255,"Alpha threshold")
    for v in m.views:
        p=path_inside(root,v.source);require(p.is_file(),"Reference missing")
        require(sha256(p)==v.sha256,"Reference hash mismatch")
        if p not in images:
            with Image.open(p) as im:
                require(im.format=="PNG" and "A" in im.getbands(),"PNG with real alpha required")
                images[p]=im.copy()
        im=images[p];x,y,w,h=v.crop
        require(x+w<=im.width and y+h<=im.height,"Crop out of bounds")
        alpha=im.crop((x,y,x+w,y+h)).getchannel("A")
        bounds=alpha.point(lambda a:255 if a>=alpha_threshold else 0).getbbox()
        require(bounds is not None,"Empty view")
        if bounds[0]==0 or bounds[1]==0 or bounds[2]==w or bounds[3]==h:
            diagnostics.append({"kind":"suspect","view":v.id,"reason":"alpha touches crop edge"})
        if alpha.getextrema()[0]==255:diagnostics.append({"kind":"suspect","view":v.id,"reason":"no transparent pixels"})
    missing=sorted(set(VIEWS)-{v.id for v in m.views})
    if missing:diagnostics.append({"kind":"incomplete","missing_views":missing})
    if any(v.camera.status!="known" for v in m.views):diagnostics.append({"kind":"incomplete","reason":"camera calibration not measured"})
    return {"status":"structurally_valid","diagnostics":diagnostics,"missing_views":missing,"visual_consistency":"not_evaluated_C2"}

def legacy_rabbit(root):
    """Use historical documented quadrants only after explicitly identifying them.
    Preserve full source sheet, do not fabricate unmeasured crop labels."""
    raw=json.loads((root/"manifest.json").read_text());h=raw["references"]["hero"];s=raw["references"]["views"]
    for v in (h,s):require(sha256(path_inside(root,v["path"]))==v["sha256"],"Legacy hash mismatch")
    # Historical sheet has four panels but not machine-verified crop metadata.
    # Keep sheet as preserved supplemental source; only hero is mapped.
    return AssetManifest("rabbit-v1","creature",[ReferenceView("three-quarter",h["path"],h["sha256"],[0,0,*h["size"]],CameraCalibration("unknown"))],legacy=True,rig_required=True,identity={"supplemental_sheet":s,"legacy_unmapped_panel_count":4,"reason":"requires explicit crop calibration","whiskers":6})
