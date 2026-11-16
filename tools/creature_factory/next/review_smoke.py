"""Recovery smoke: prove that unverified creature anatomy blocks expensive UV/rig work."""
from pathlib import Path
from dataclasses import asdict
import json,sys,shutil
from .audit import write_json,validate_output,ROOT,REGISTRY,verify_sources
from .contracts import legacy_rabbit,require
from .dag import build,validate_job
from .anatomy import Anatomy,Part
def run(archive,out,resume=False):
    out=validate_output(Path(out))
    if resume:
        require((out/"job/job.json").is_file(),"Resume job missing")
    else:out.mkdir(parents=True,exist_ok=False)
    src=ROOT/"asset-library/references/rabbit-v1";m=legacy_rabbit(src);staging=out/"input"
    if not resume:
        staging.mkdir()
        for n in {v.source for v in m.views}:shutil.copyfile(src/n,staging/n)
        shutil.copyfile(archive,staging/"checkpoint.zip")
    raw=asdict(m);parts=[Part("body","body"),Part("head","head","body",articulation="ball"),Part("muzzle","muzzle","head",protected=True,articulation="flexible"),Part("tail","tail","body",protected=True,articulation="flexible")]
    for side in ("left","right"):
        parts.append(Part(side+"_ear","ear","head",side,protected=True,articulation="ball"))
        parts.append(Part(side+"_foreleg","foreleg","body",side,protected=True,articulation="ball"))
        parts.append(Part(side+"_hindleg","hindleg","body",side,protected=True,articulation="ball"))
        parts.append(Part(side+"_hindpaw","hindpaw",side+"_hindleg",side,protected=True,articulation="hinge"))
        for i in range(3):parts.append(Part(f"{side}_whisker_{i}","whisker","head",side,protected=True,thin=True))
    raw["identity"]["anatomy"]=asdict(Anatomy(parts,{"ear":2,"whisker":6}));write_json(staging/"manifest.json",raw)
    cfg={"candidate_ready":{"backend":"verified_triposr_checkpoint","archive":"checkpoint.zip","sha256":"d045c52dd746d74db9b37dd5b974791c52a11813750efdd2b38536e5d706dd9c"},"candidate_review_ready":{"enabled":True},"candidate_uv_ready":{"resolution":2048}}
    job=out/"job";previous=json.loads((job/"job.json").read_text()) if resume else None
    s=build(staging/"manifest.json",job,cfg,resume=resume)
    # Historical manifests and code changed; rebuilding affected stages is
    # intentional. Verify that a second run on the exact same inputs reuses
    # every successful stage rather than demanding stale attempt IDs.
    require(s["stages"]["candidate_volume_ready"]["state"]=="succeeded",str({k:(v["state"],v["cause"]) for k,v in s["stages"].items()}))
    for name in ("candidate_functional_ready","candidate_refinement_ready","candidate_optimized_ready","candidate_uv_ready","candidate_review_ready","review_ready"):
        require(s["stages"][name]["state"]=="blocked","Unverified anatomy bypass: "+name)
    first={k:v["attempt"] for k,v in s["stages"].items() if v["state"]=="succeeded"}
    t=build(staging/"manifest.json",job,cfg,resume=True)
    require(first=={k:v["attempt"] for k,v in t["stages"].items() if v["state"]=="succeeded"},"Cache miss")
    require(validate_job(job)["status"]=="valid_incomplete","Job integrity")
    write_json(out/"report.json",{"schema":1,"status":"functional_gate_blocked_unverified_candidate","cache_reused":True,"stages":{k:{"state":v["state"],"metrics":v["metrics"],"cause":v["cause"]} for k,v in s["stages"].items()},"preservation":verify_sources(ROOT,json.loads(REGISTRY.read_text())),"production_ready":False})
    print(json.dumps(json.loads((out/"report.json").read_text())),flush=True)
if __name__=="__main__":run(Path(sys.argv[1]),Path(sys.argv[2]),"--resume" in sys.argv[3:])
