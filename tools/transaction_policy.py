"""Conservative inventory headroom for existing Scene Patch operations.
The clone estimate is observed history, not a guarantee of engine behavior.
Never use this policy to authorize default-module deletion.
"""
from scene_sync import require

def inventory_budget(base,operations):
    roots={}
    for row in base["records"].values():
        path=row.get("path",[])
        if row.get("service")=="StarterPlayer" and path and path[0]["name"]=="PlayerModule" and path[0]["class"]=="ModuleScript":
            ordinal=path[0]["ordinal"];roots[ordinal]=roots.get(ordinal,0)+1
    # Last observed growth: one full PlayerModule and one AtomicBinding instance.
    clone_estimate=max(roots.values(),default=0)+1
    patch_estimate=2*len(operations)+1
    projected=base["total"]+clone_estimate+patch_estimate
    limit=5000;reserve=500
    return {"current":base["total"],"knownCloneEstimate":clone_estimate,"patchEstimate":patch_estimate,"projected":projected,"inventoryLimit":limit,"reserve":reserve,"allowed":projected<=limit-reserve,"estimateOnly":True}
def require_budget(base,ops):
    budget=inventory_budget(base,ops)
    require(budget["allowed"],"Inventory headroom insufficient; reconcile default-module growth before saving")
    return budget
