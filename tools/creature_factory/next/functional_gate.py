"""Functional anatomy gate: explicit observed parts and real deformation probes.
No silhouette/UV metric can substitute for missing functional evidence."""
from .contracts import require,finite

def evaluate_functional_parts(required,observations,probes):
    require(isinstance(required,list) and len(required)==len(set(required)) and bool(required),"Unique required parts")
    require(isinstance(observations,dict) and isinstance(probes,dict),"Functional evidence mappings")
    finite(observations);finite(probes)
    results={}
    for part in required:
        o=observations.get(part,{})
        p=probes.get(part,{})
        if o.get("state")!="present" or o.get("provenance") not in ("reviewed_geometry","measured_fixture_geometry"):
            results[part]="unverified_geometry";continue
        if o.get("articulated",False):
            if p.get("state")!="passed" or p.get("provenance")!="evaluated_mesh":
                results[part]="unverified_deformation";continue
            if p.get("moved_vertices",0)<1 or p.get("max_displacement",0)<=0 or p.get("static_leakage",1)>p.get("leakage_limit",0):
                results[part]="deformation_failed";continue
        results[part]="verified"
    ok=all(x=="verified" for x in results.values())
    return {"status":"functional_evidence_complete" if ok else "blocked_functional_anatomy","parts":results,"production_approval":False}
