"""Full experimental review from the exact rabbit source checkpoint."""
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
    raw=asdict(m);parts=[Part("body","body"),Part("head","head","body")]
    for side in ("left","right"):
        parts.append(Part(side+"_ear","ear","head",side,protected=True,articulation="ball"))
        for i in range(3):parts.append(Part(f"{side}_whisker_{i}","whisker","head",side,protected=True,thin=True))
    raw["identity"]["anatomy"]=asdict(Anatomy(parts,{"ear":2,"whisker":6}));write_json(staging/"manifest.json",raw)
    cfg={"candidate_ready":{"backend":"verified_triposr_checkpoint","archive":"checkpoint.zip","sha256":"d045c52dd746d74db9b37dd5b974791c52a11813750efdd2b38536e5d706dd9c"},"candidate_review_ready":{"enabled":True},"candidate_uv_ready":{"resolution":2048}}
    job=out/"job";previous=json.loads((job/"job.json").read_text()) if resume else None
    s=build(staging/"manifest.json",job,cfg,resume=resume)
    if previous:
        for stage in ("candidate_ready","candidate_alignment_ready","candidate_volume_ready"):
            require(s["stages"][stage]["attempt"]==previous["stages"][stage]["attempt"],"Upstream checkpoint unexpectedly rebuilt: "+stage)
    require(s["stages"]["candidate_review_ready"]["state"]=="succeeded",str({k:(v["state"],v["cause"]) for k,v in s["stages"].items()}))
    require(s["stages"]["review_ready"]["state"]=="blocked","Production approval bypass")
    first={k:v["attempt"] for k,v in s["stages"].items() if v["state"]=="succeeded"}
    t=build(staging/"manifest.json",job,cfg,resume=True)
    require(first=={k:v["attempt"] for k,v in t["stages"].items() if v["state"]=="succeeded"},"Review resume cache miss")
    require(validate_job(job)["status"]=="valid_incomplete","Job integrity")
    final=s["stages"]["candidate_review_ready"]
    review=out/"review";review.mkdir()
    for p in final["outputs"]:shutil.copyfile(job/p,review/Path(p).name)
    write_json(out/"report.json",{"schema":1,"status":"experimental_review_pipeline_validated","cache_reused":True,"stages":{k:{"state":v["state"],"metrics":v["metrics"]} for k,v in s["stages"].items()},"preservation":verify_sources(ROOT,json.loads(REGISTRY.read_text())),"production_ready":False})
    print(json.dumps(json.loads((out/"report.json").read_text())),flush=True)
if __name__=="__main__":run(Path(sys.argv[1]),Path(sys.argv[2]),"--resume" in sys.argv[3:])
