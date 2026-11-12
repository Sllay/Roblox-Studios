import argparse,os,json
from pathlib import Path
from scene_sync import ROOT,read,write,require,state_path,task
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,default=ROOT/"dist/s06-4");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    inv=read(GAME/"docs/s06/regeneration-v16/inventory.json")
    # Explicit audited canopy IDs from S04 policy; no guessed geometry.
    old=read(GAME/"docs/spatial/v14/s04/inventory.json")
    meshes={}
    for r in old["rows"]:
        for m in r["meshes"]:
            if "Canopy" in m["name"] or m["name"]=="Leaves":
                meshes[r["species"]]=m["mesh"]
    require(len(meshes)==8,"Canopy scope")
    mod=(GAME/"game/places/main/src/ReplicatedStorage/RSCanopyDeform.luau").read_text()
    src=(ROOT/"tools/sync/canopy_capability_probe.luau").read_text().replace("-- __RS_DEFORM__","local D=(function()\n"+mod+"\nend)()")
    r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+src+"\nend",read_version=base["loadedVersion"],compile_source=True,meshes=[{"species":k,"mesh":v} for k,v in sorted(meshes.items())])
    require(r["noPlaceWrites"] and not r["clientVerified"] and len(r["canopies"])==8,"Probe scope")
    write(a.output/"capability.json",r);print("S064_CAPABILITY "+json.dumps(r),flush=True)
if __name__=="__main__":main()
