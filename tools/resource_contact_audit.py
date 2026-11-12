"""S06.7 mobile report follow-up: actual v17 resource placement/visual audit, read-only."""
import argparse,os,json,math
from collections import Counter
from pathlib import Path
from scene_sync import ROOT,read,write,require,task,state_path
from deploy import load_all,resolve
GAME=ROOT/"games/maps/mapa-principal"
IDS={"p45-stone-chunk-1--1-12","p45-stick-chunk-1--1-06","p45-stick-chunk-1-0-03"}
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    require(base["loadedVersion"]==17,"Expected v17")
    plan=read(GAME/"docs/s06/resources-v16/plan.json");rows=plan["resources"]
    data=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],"do\n"+(ROOT/"tools/sync/resource_contact_audit.luau").read_text()+"\nend",read_version=17,compile_source=True,rows=rows)
    require(data["loadedVersion"]==17 and data["noPlaceWrites"] and len(data["rows"])==216,"Audit scope")
    byid={r["id"]:r for r in rows};actual={r["id"]:r for r in data["rows"]}
    require(actual.keys()==byid.keys(),"Identity coverage")
    categories={}
    for cat in ("stone","stick"):
        rs=[r for r in data["rows"] if r["category"]==cat]
        def span(key):return [min(r[key] for r in rs),max(r[key] for r in rs)]
        categories[cat]={"count":len(rs),"maxPositionError":max(math.dist(r["position"],byid[r["id"]]["position"]) for r in rs),"maxBoundsError":max(math.dist(r["bboxSize"],byid[r["id"]]["bounds"]) for r in rs),"burial":span("burial"),"voxelBaseGap":span("voxelBaseGap"),"voxelTopGap":span("voxelTopGap"),"maxExpectedVoxelDelta":max(abs(r["expectedGround"]-r["voxelGround"]) for r in rs),"height":[min(r["bboxSize"][1] for r in rs),max(r["bboxSize"][1] for r in rs)],"minDimension":[min(min(r["bboxSize"]) for r in rs),max(min(r["bboxSize"]) for r in rs)],"transparent":sum(r["transparency"]!=0 or r["localTransparency"]!=0 for r in rs),"terrainRays":sum(bool(r["ray"]) for r in rs),"meshRays":sum(r["meshQueryHit"] for r in rs),"materials":dict(Counter(r["nearestColumn"]["material"] for r in rs)),"belowEstimatedSurface":sum(r["voxelTopGap"]<0 for r in rs)}
    pair=[]
    for stone in (r for r in data["rows"] if r["category"]=="stone"):
        stick=min((r for r in data["rows"] if r["category"]=="stick"),key=lambda r:math.dist(r["position"][::2],stone["position"][::2]))
        pair.append(math.dist(stone["position"][::2],stick["position"][::2]))
    summary={"loadedVersion":17,"stateDigest":base["stateDigest"],"categories":categories,"assets":data["assets"],"controlPartRay":data["controlPartRay"],"selected":[actual[i] for i in sorted(IDS)],"nearestStoneStickDistance":[min(pair),max(pair)],"noPlaceWrites":True,"clientRenderVerified":False}
    write(a.output/"resource-contact-audit.json",data);write(a.output/"summary.json",summary)
    print("S067_AUDIT "+json.dumps({**summary,"selected":[{k:r[k] for k in ("id","position","bboxSize","bottom","top","expectedGround","burial","voxelGround","voxelBaseGap","voxelTopGap","ray","transparency","localTransparency","meshSize","color","nearestColumn")} for r in summary["selected"]]}),flush=True)
if __name__=="__main__":main()
