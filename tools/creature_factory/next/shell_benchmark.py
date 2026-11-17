"""Exploratory threshold sweep on frozen C2 correspondence evidence.
No neural inference, parameter fitting, or production adoption."""
from pathlib import Path
import sys,json
import numpy as np
from PIL import Image,ImageDraw
from .audit import write_json,validate_output,ROOT,REGISTRY,verify_sources
from .hull_benchmark import view_files,resize_mask
from .deep_benchmark import preview
from .shell_visibility import filter_shell

def run(ab,hullroot,deep,out):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=False)
    preserve=verify_sources(ROOT,json.loads(REGISTRY.read_text()))
    thresholds=(2,4,8);report={};rows=[]
    for name in ("flat","wavy","convex","concave","asymmetric","articulation","rabbit"):
        raw=view_files(Path(ab)/name);views={k:(resize_mask(m),c) for k,(m,c,p) in raw.items()}
        images={k:Image.open(p).convert("RGBA").resize((views[k][0].shape[1],views[k][0].shape[0]),Image.Resampling.LANCZOS) for k,(m,c,p) in raw.items()}
        z=np.load(Path(hullroot)/name/"hull.npz");step=float(z["step"])
        intervals={k:dict(np.load(Path(hullroot)/name/k/"ray-intervals.npz")) for k in views}
        original=json.loads((Path(deep)/name/"matches.json").read_text())
        q=out/name;q.mkdir();filtered={}
        counts={str(t):{"matches":0,"correct":0 if name!="rabbit" else None} for t in thresholds}
        total=0;correct=0 if name!="rabbit" else None;best=None
        for pair,methods in original.items():
            a,b=pair.split("/");records=methods["deep"];total+=len(records)
            if correct is not None:correct+=sum(r.get("evaluation")=="correct" for r in records)
            filtered[pair]={}
            for t in thresholds:
                keep=filter_shell(records,views,intervals,step,t);filtered[pair][str(t)]=keep
                counts[str(t)]["matches"]+=len(keep)
                if correct is not None:counts[str(t)]["correct"]+=sum(r.get("evaluation")=="correct" for r in keep)
            if best is None or len(filtered[pair]["4"])>best[0]:best=(len(filtered[pair]["4"]),a,b,filtered[pair]["4"])
        for x in counts.values():
            x["precision"]=x["correct"]/x["matches"] if x["correct"] is not None and x["matches"] else None
            x["correct_retention"]=x["correct"]/correct if correct else None
        write_json(q/"filtered.json",filtered)
        report[name]={"original_matches":total,"original_correct":correct,"thresholds":counts,"camera_gauge":"estimated" if name=="rabbit" else "known"}
        if best:rows.append((name+" | retained at 4 voxels: "+str(counts["4"]["matches"]),preview(best[1],best[2],images,best[3])))
    aggregate={}
    for t in thresholds:
        n=sum(r["thresholds"][str(t)]["matches"] for k,r in report.items() if k!="rabbit")
        c=sum(r["thresholds"][str(t)]["correct"] for k,r in report.items() if k!="rabbit")
        original_c=sum(r["original_correct"] for k,r in report.items() if k!="rabbit")
        aggregate[str(t)]={"matches":n,"correct":c,"precision":c/n if n else None,"correct_retention":c/original_c if original_c else None}
    im=Image.new("RGB",(520,310*len(rows)),(245,245,245));draw=ImageDraw.Draw(im)
    for i,(title,p) in enumerate(rows):draw.text((4,i*310+4),title,fill=(20,20,20));im.paste(p,(0,i*310+22))
    im.save(out/"shell-review.png")
    write_json(out/"report.json",{"schema":1,"status":"exploratory_outer_shell_diagnostic","aggregate":aggregate,"assets":report,"preservation":preserve,"production_adopted":False,"limitations":["Threshold sweep uses same fixtures as original experiment, not a held-out benchmark.","Outer hull near depth is not ground truth; true concavities may be rejected.","Rabbit camera hypotheses have no metric truth; rejection does not prove all appearance matches wrong.","No model fusion or reconstruction enabled."]})
    print(json.dumps({"aggregate":aggregate,"rabbit":report["rabbit"]}),flush=True)
if __name__=="__main__":run(*map(Path,sys.argv[1:]))
