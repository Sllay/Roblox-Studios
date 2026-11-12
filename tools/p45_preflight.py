"""Read-only P4.5 inspection and wind patch preview against v13."""
import os,json
from scene_sync import ROOT,require_current,task,write,require
from scene_patch import prepare
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    base=require_current(target,key)
    require(base["loadedVersion"]==13,"P4.5 expected v13")
    report=task(target,key,"do\n"+(ROOT/"tools/sync/p45_inspect.luau").read_text()+"\nend")
    require(report.get("noPlaceWrites") is True and report["loadedVersion"]==13,"Inspection failed")
    out=ROOT/"dist/p45";write(out/"inventory.json",report)
    from collections import Counter
    counts=Counter((r["root"],r.get("species") or r.get("id","unknown")) for r in report["rows"])
    print("P45_COUNTS",json.dumps([[*k,v] for k,v in counts.items()]),flush=True)
    print("P45_VISUAL_FLAGS",json.dumps([list(k)+[v] for k,v in Counter((m["name"],m["material"],m["anchored"],m["collide"],m["touch"],m["query"]) for r in report["rows"] for m in r["meshes"]).items()]),flush=True)
    ops=[]
    for name,cls,rel in [("RSWind","LocalScript","StarterPlayer/StarterPlayerScripts/RSWind.client.luau"),("RSWindPolicy","ModuleScript","ReplicatedStorage/RSWindPolicy.luau")]:
        matches=[k for k,r in base["records"].items() if r.get("name")==name and r.get("class")==cls and k.startswith("managed:")]
        require(len(matches)==1,"Missing wind identity")
        ops.append({"kind":"update_script","targetKey":matches[0],"archiveId":"p45-"+name.lower()+"-v13","sourcePath":str((GAME/"game/places/main/src"/rel).relative_to(ROOT))})
    plan={"schemaVersion":1,"expectedVersion":13,"baselineDigest":base["stateDigest"],"operations":ops}
    prepared=prepare(target,base,plan)
    preview=task(target,key,"do\n"+(ROOT/"tools/sync/patch.luau").read_text()+"\nend",mode="preview",environment="staging",expectedVersion=13,operations=prepared)
    require(preview.get("preview") is True and preview["operations"]==2,"Preview failed")
    write(out/"wind-patch.json",plan)
    print("P45_WIND_PATCH",json.dumps(plan),flush=True)
if __name__=="__main__":main()
