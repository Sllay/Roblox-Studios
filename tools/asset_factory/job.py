"""Validated immutable authoring request; no network or publication."""
import json,re,hashlib
from pathlib import Path
VIEWS={"front","back","left","right","top","bottom"}
def load(path):
    p=Path(path); d=json.loads(p.read_text())
    if d.get("schema")!=1 or not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}",d.get("id","")): raise ValueError("job identity")
    mode=d.get("mode"); refs=d.get("references",{})
    if mode not in {"text","image","multi_view"} or not isinstance(refs,dict): raise ValueError("input mode")
    if not isinstance(d.get("prompt"),str) or not d["prompt"].strip(): raise ValueError("prompt")
    if not isinstance(d.get("triangle_budget"),int) or not 1<=d["triangle_budget"]<=100000: raise ValueError("budget")
    if mode=="text" and refs or mode=="image" and len(refs)!=1 or mode=="multi_view" and (len(refs)<2 or not set(refs)<=VIEWS): raise ValueError("reference cardinality")
    if not isinstance(d.get("style"),str) or not d["style"]: raise ValueError("style")
    hashes={}
    for k,v in refs.items():
        q=(p.parent/v).resolve()
        if not q.is_relative_to(p.parent.resolve()) or not q.is_file() or q.suffix.lower() not in {".png",".jpg",".jpeg",".webp"}: raise ValueError("reference path")
        hashes[k]=hashlib.sha256(q.read_bytes()).hexdigest()
    return d,hashes
