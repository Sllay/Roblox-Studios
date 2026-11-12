"""P4.4: exact audited new environment models; no Place writes."""
import json,os
from pathlib import Path
from pipeline import ROOT,write,WorkspaceError,call
from pack_import import audit_report
from deploy import load_all,resolve
from scene_sync import require_current
from discover import thumbnails,download_thumbnail
GAME=ROOT/"games/maps/mapa-principal"
def main():
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    games,targets=load_all();t=resolve(games,targets,"mapa-principal","main","staging")
    base=require_current(t,key)
    if base["loadedVersion"]<12 or "managed:p4-localscript-rswind" not in base["records"]:
        raise WorkspaceError("P4.3 must be verified before P4.4")
    spec=json.loads((GAME/"game/assets/environment-p4-detail.json").read_text())
    out=ROOT/"dist/p4-detail";results=[]
    for a in spec["assets"]:
        try:
            report=audit_report(t,key,a["assetId"],a["selector"])
            if report["loadedVersion"]!=base["loadedVersion"]:raise WorkspaceError("Place changed")
            write(out/(a["name"]+"-audit.json"),report)
            meshes=[x for x in report["audit"]["rows"] if x["class"]=="MeshPart"]
            ids=[x["mesh"].split("://")[1] for x in meshes]
            images=[]
            for aid,url in thumbnails(ids).items():
                im=download_thumbnail(url)
                if im is not None:
                    folder=out/"thumbs";folder.mkdir(parents=True,exist_ok=True)
                    im.save(folder/(aid+".png"));images.append(aid)
            item={**a,"status":"exact_v2_pass","sourceDigest":report["digest"],"loadedVersion":report["loadedVersion"],"bounds":report["audit"]["bounds"],"meshRows":meshes,"surfaces":report["audit"]["surfaces"],"dependencies":report["audit"]["dependencies"],"thumbnailIds":images,"importAuthorized":False}
        except (WorkspaceError,ValueError,KeyError,OSError) as exc:
            item={**a,"status":"blocked","diagnostic":str(exc)[:400],"importAuthorized":False}
        results.append(item);print("P4_DETAIL_ASSET "+json.dumps(item),flush=True)
        if "429" in item.get("diagnostic",""):break
    moss=call(t,key,"detail_geometry",spec["moss"]["assetId"])
    if moss["loadedVersion"]!=base["loadedVersion"]:raise WorkspaceError("Place changed")
    write(out/"moss-geometry.json",moss)
    print("P4_DETAIL_MOSS "+json.dumps(moss),flush=True)
    write(out/"summary.json",{"loadedVersion":base["loadedVersion"],"results":results,"noPlaceWrites":True})
    return 0 if len(results)==len(spec["assets"]) and all(x["status"]=="exact_v2_pass" for x in results) else 2
if __name__=="__main__":raise SystemExit(main())
