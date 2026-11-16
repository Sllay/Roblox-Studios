"""C1 persistent, single-writer stage DAG; future stages remain unavailable."""
from __future__ import annotations
from dataclasses import asdict, dataclass
from pathlib import Path
from contextlib import contextmanager
import fcntl, inspect, json, os, time, uuid
from importlib.metadata import version
from .audit import sha256,write_json,validate_output
from .contracts import *
from .evidence import segment
from .cameras import calibrate
from .anatomy import validate_anatomy
from .master_candidate import import_checkpoint
from .neural_backend import generate_candidate

class JobError(ValueError):pass
class TransientError(RuntimeError):pass
@dataclass(frozen=True)
class Stage:
    name:str
    deps:tuple[str,...]
    version:str="1"
    backend:str="c1"
STAGES=(Stage("intake",()),Stage("reference_ready",("intake",)),Stage("segmentation_ready",("reference_ready",),"2a","alpha"),Stage("calibration_ready",("segmentation_ready",),"2b","camera"),Stage("candidate_ready",("reference_ready","calibration_ready"),"3a","checkpoint"),Stage("candidate_alignment_ready",("candidate_ready","segmentation_ready","calibration_ready"),"3b","similarity"),Stage("candidate_volume_ready",("candidate_alignment_ready","segmentation_ready","calibration_ready"),"3c.1","volume"),Stage("candidate_functional_ready",("candidate_volume_ready",),"1","functional-anatomy"),Stage("candidate_refinement_ready",("candidate_volume_ready","candidate_functional_ready","segmentation_ready","calibration_ready"),"4b","refine"),Stage("candidate_optimized_ready",("candidate_refinement_ready",),"4a","optimize"),Stage("candidate_uv_ready",("candidate_optimized_ready",),"5a","uv"),Stage("candidate_review_ready",("candidate_ready","candidate_alignment_ready","candidate_volume_ready","candidate_refinement_ready","candidate_optimized_ready","candidate_uv_ready"),"6a","review"),Stage("evidence_ready",("calibration_ready",)),Stage("master_ready",("evidence_ready",)),Stage("quality_checked",("master_ready",)),Stage("optimized",("quality_checked",)),Stage("uv_ready",("optimized",)),Stage("materials_ready",("uv_ready",)),Stage("rig_ready",("optimized",)),Stage("packaged",("materials_ready","rig_ready")),Stage("review_ready",("packaged",)))
@contextmanager
def lock(root):
    root.mkdir(parents=True,exist_ok=True)
    p=root/".job.lock"
    fd=os.open(p,os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
    try:
        try:fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError as e:raise JobError("Job locked") from e
        yield
    finally:os.close(fd)

def read_state(root):
    state=json.loads(path_inside(root,"job.json").read_text());finite(state)
    require(state.get("schema")==1 and isinstance(state.get("stages"),dict),"Invalid job schema")
    return state
def valid_outputs(root,r):
    try:
        return bool(r["outputs"]) and all(sha256(path_inside(root,p))==h for p,h in r["outputs"].items())
    except (ValueError,OSError,KeyError,TypeError):return False
def intake(m,source,out,cfg):
    report=validate_manifest(m,source.parent,cfg.get("alpha_threshold",16))
    report["anatomy"]=validate_anatomy(m)
    write_json(out/"manifest.json",asdict(m));write_json(out/"validation.json",report)
    return report
def references(m,source,out,cfg):
    from PIL import Image
    for view in m.views:
        x,y,w,h=view.crop
        with Image.open(path_inside(source.parent,view.source)) as im:im.crop((x,y,x+w,y+h)).save(out/(view.id+".png"))
    write_json(out/"views.json",{"views":[asdict(v) for v in m.views],"visual_consistency":"not_evaluated_C2"})
    return {"views":len(m.views)}
RUNNERS={"intake":intake,"reference_ready":references,"segmentation_ready":segment,"calibration_ready":calibrate}
def build(manifest,root,config=None,*,resume=False,runners=None,stages=STAGES):
    root=validate_output(Path(root));source=Path(manifest).resolve();initial_manifest_hash=sha256(source);m=AssetManifest.read(source)
    require(sha256(source)==initial_manifest_hash,"Manifest changed while reading")
    require(not source.is_relative_to(root),"Source must be outside job directory")
    config=config or {};finite(config);runners=RUNNERS if runners is None else runners
    production=runners is RUNNERS
    if production and config.get("candidate_ready",{}).get("backend"):
        choice=config["candidate_ready"]["backend"]
        require(choice in ("verified_triposr_checkpoint","generic_triposr"),"Unknown candidate backend")
        runners={**RUNNERS,"candidate_ready":import_checkpoint if choice=="verified_triposr_checkpoint" else generate_candidate}
        if config.get("candidate_review_ready",{}).get("enabled",False):
            from .pipeline_stages import RUNNERS as review_runners
            runners.update(review_runners)
    # Read actual input bytes, not only the digest asserted by a manifest.
    def input_digest():
        return digest({"manifest":sha256(source),"sources":{v.source:sha256(path_inside(source.parent,v.source)) for v in m.views}})
    input_hash=input_digest()
    require(sha256(source)==initial_manifest_hash,"Manifest changed while hashing inputs")
    with lock(root):
        p=path_inside(root,"job.json")
        old=read_state(root) if p.exists() else None
        if old and not resume:raise JobError("Existing job: use resume")
        if old and old["asset_id"]!=m.asset_id:raise JobError("Asset identity changed")
        state=old or asdict(JobManifest(m.asset_id,str(source),config,{}))
        state.update(manifest_path=str(source),config=config,input_hash=input_hash,status="incomplete")
        records=state["stages"]
        def persist():write_json(p,state)
        def archive(r):
            if r:
                h=path_inside(root,"history/"+uuid.uuid4().hex+".json");write_json(h,r)
        persist()
        for s in stages:
            prev=records.get(s.name);deps={d:records[d]["key"] for d in s.deps}
            cfg=config.get(s.name,{})
            require(isinstance(cfg,dict),"Stage configuration must be object")
            runner=runners.get(s.name)
            # Explicit stage versions plus real implementation fingerprints. For
            # callable test doubles, source identity is diagnostic only.
            code_hash="unavailable" if runner is None else "injected-test-runner"
            backend=s.backend
            if production and runner is not None:
                backend=f"{s.backend}:pillow@{version('Pillow')}"
                code_hash=digest({"runner_module":sha256(Path(inspect.getfile(runner))),"contracts":sha256(Path(__file__).with_name("contracts.py"))})
            if production and runner is not None and s.name.startswith("candidate_") and s.name!="candidate_ready":
                module_deps={"candidate_alignment_ready":["rigid_alignment.py","camera_refinement.py","hull_alignment.py"],"candidate_volume_ready":["volumetric_reconstruction.py","hull_alignment.py","rigid_alignment.py"],"candidate_refinement_ready":["surface_refinement.py","mesh_optimization.py","rigid_alignment.py"],"candidate_optimized_ready":["mesh_optimization.py","rigid_alignment.py"],"candidate_uv_ready":["uv_atlas.py"],"candidate_review_ready":[]}
                code_hash=digest([code_hash]+[sha256(Path(__file__).with_name(n)) for n in module_deps[s.name]])
            if production and s.name=="candidate_ready" and runner is not None:
                backend=cfg["backend"]
                if backend=="verified_triposr_checkpoint":
                    actual=sha256(path_inside(source.parent,cfg["archive"]))
                    require(actual==cfg["sha256"],"Candidate archive hash mismatch")
                    code_hash=digest([code_hash,actual])
                else:
                    legacy=Path(__file__).resolve().parents[1]
                    code_hash=digest([code_hash,sha256(legacy/"rabbit_neural_inference.py"),sha256(legacy/"tsr_cpu_marching_cubes.py")])
            key=digest({"stage":s.name,"version":s.version,"backend":backend,"implementation":code_hash,"deps":deps,"config":cfg,"input":input_hash if not s.deps else None})
            ready=all(records[d]["state"] in ("succeeded","skipped") for d in s.deps)
            # Include attempt identity so corruption/recovery invalidates descendants even when bytes match.
            key=digest({"key":key,"dependency_attempts":{d:records[d].get("attempt") for d in s.deps}})
            if prev and prev["key"]==key and prev["state"]=="succeeded" and ready and valid_outputs(root,prev):continue
            if prev and prev["key"]==key and prev["state"]=="skipped" and s.name in ("rig_ready","candidate_functional_ready") and not m.rig_required:continue
            if prev:
                archive(prev)
                records[s.name]={**prev,"state":"invalidated"};persist()
            def result(status,**kw):
                records[s.name]=asdict(StageResult(s.name,s.version,status,key,dependencies=deps,config=cfg,backend=backend,**kw));persist()
            if s.name=="rig_ready" and not m.rig_required:
                result("skipped",cause="profile does not require rig");continue
            if not ready:
                result("blocked",cause="Dependency incomplete");continue
            if s.name not in runners:
                if s.name=="candidate_functional_ready":
                    result("blocked",cause="Functional anatomy not verified: require actual part geometry and evaluated deformation evidence before refinement/UV")
                else:result("blocked",cause="Stage not implemented yet")
                continue
            retries=cfg.get("transient_retries",0)
            require(type(retries)==int and 0<=retries<=2,"Invalid retry limit")
            for n in range(retries+1):
                attempt=uuid.uuid4().hex;out=path_inside(root,f"attempts/{s.name}/{attempt}")
                out.mkdir(parents=True,exist_ok=False)
                result("running",attempt=attempt);start=time.monotonic()
                try:
                    if input_digest()!=input_hash:raise JobError("Inputs changed during job; resume with new manifest")
                    if production and s.name not in ("intake","reference_ready"):
                        inputs={d:{Path(p).name:path_inside(root,p) for p in records[d]["outputs"]} for d in s.deps}
                        metrics=runner(m,source,out,cfg,inputs) or {}
                    else:metrics=runner(m,source,out,cfg) or {}
                    if input_digest()!=input_hash:raise JobError("Inputs changed during stage; partial attempt retained")
                    outputs={}
                    for f in sorted(out.rglob("*")):
                        if f.is_symlink():raise JobError("Symlink output prohibited")
                        if f.is_file():
                            rel=str(f.relative_to(root));outputs[rel]=sha256(path_inside(root,rel))
                            with f.open("rb") as stream:os.fsync(stream.fileno())
                    if not outputs:raise JobError("No output")
                    finite(metrics)
                    result("succeeded",attempt=attempt,outputs=outputs,metrics=metrics,duration_seconds=time.monotonic()-start);break
                except Exception as exc:
                    result("failed",attempt=attempt,cause=f"{type(exc).__name__}: {exc}",duration_seconds=time.monotonic()-start)
                    if not isinstance(exc,TransientError) or n==retries:break
                    archive(records[s.name])
        state["status"]="review_ready" if records[stages[-1].name]["state"]=="succeeded" else "incomplete"
        persist();return state
def validate_job(root):
    root=Path(root).resolve()
    with lock(root):
        state=read_state(root)
        invalid=[s for s,r in state["stages"].items() if r["state"]=="succeeded" and not valid_outputs(root,r)]
        try:
            source=Path(state["manifest_path"]);m=AssetManifest.read(source)
            current=digest({"manifest":sha256(source),"sources":{v.source:sha256(path_inside(source.parent,v.source)) for v in m.views}})
            if current!=state.get("input_hash"):invalid.append("intake:source_changed")
        except (OSError,ValueError,KeyError):invalid.append("intake:source_unavailable")
        return {"status":"invalid" if invalid else "valid_incomplete" if state.get("status")!="review_ready" else "valid","invalid_stages":invalid,"artistic_approval":False}
