"""Native isolated Book DataStore test, no player keys or Place writes."""
import os,sys,time,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/"tools"),str(ROOT/"tools/asset_factory")]
from scene_sync import task
from deploy import load_all,resolve
from s08_prop_intake import write,commit
def main():
    folder=ROOT/"games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework"
    files={"Registry":"CreatureRegistry","Core":"BookCore","Persist":"BookPersistence","Store":"BookDataStore"}
    dispatch="do\n"+"\n".join("local "+k+"=(function()\n"+(folder/(v+".luau")).read_text()+"\nend)()" for k,v in files.items())+"\n"+(ROOT/"tools/sync/s095_d_book.luau").read_text()+"\nend"
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    for i in range(4):
        try:
            p=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],dispatch,read_version=25,compile_source=True);break
        except Exception as e:
            if "HTTP 503" not in str(e) or i==3:raise
            time.sleep(3*2**i)
    dest=ROOT/"asset-library/roblox-receipts/s09/chicken-d-book-proof.json";write(dest,p);commit([dest],"evidence(s09.5-D): isolated native DataStore probe")
    print(json.dumps(p,indent=2));assert p["passed"] and p["cleaned"],p
if __name__=="__main__":main()
