"""Build a reusable, evidence-backed visual catalog from an inspected model pack.
Component thumbnails are NOT a render of a complete model. No invented visual labels.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from discover import thumbnails,download_thumbnail,DiscoveryError
from pipeline import write,ROOT,check_id
from pack import validate_selector

def asset_id(value):
    m=re.fullmatch(r"rbxassetid://([1-9][0-9]*)",str(value))
    return m.group(1) if m else None

def fingerprint(item):
    payload={k:item[k] for k in ("selector","name","bounds","counts","visualComponents")}
    return hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()

def build_catalog(report):
    pid=check_id(report["assetId"])
    pack=report["pack"]
    result=[]
    for item in pack["candidates"]:
        validate_selector(item["selector"])
        technical=item["technicalCandidate"] is True
        components=[]
        for raw in item.get("visualComponents",[]):
            components.append({**raw,"meshAssetId":asset_id(raw.get("meshId")),"textureAssetId":asset_id(raw.get("textureId"))})
        result.append({
            "packAssetId":pid,"selector":item["selector"],"name":item["name"],
            "modelKey":fingerprint(item),"classification":"candidate" if technical else "auxiliary_or_ineligible",
            "technical":{"bounds":item["bounds"],"parts":item["parts"],"meshParts":item["meshes"],"pbr":item["pbr"],"scripts":item["scripts"]},
            "components":components,
            "visual":{"status":"unreviewed","description":None,"observed":{"foliageColor":None,"trunkColor":None,"canopyShape":None,"trunkShape":None,"style":None},
                      "inferred":{"resembles":None,"suitableBiomes":[],"avoidBiomes":[],"moodTags":[]},
                      "confidence":None,"evidence":[]},
            "securityStatus":"not_approved","importStatus":"not_imported"})
    return {"schemaVersion":1,"packAssetId":pid,"universeId":report["universeId"],"placeId":report["placeId"],
            "loadedVersion":report["loadedVersion"],"totalModels":pack["totalModels"],
            "inventoryTruncated":pack["inventoryTruncated"],"models":result,
            "note":"Component tints are engine parameters, not observed final colors. Visual review requires evidence."}

def render(catalog,output):
    output.mkdir(parents=True,exist_ok=True)
    folder=output/"thumbs";folder.mkdir(exist_ok=True)
    ids=sorted({c["meshAssetId"] for m in catalog["models"] for c in m["components"] if c["meshAssetId"]}|{catalog["packAssetId"]})
    urls={}
    for start in range(0,len(ids),50):
        urls.update(thumbnails(ids[start:start+50]))
    images={}
    for aid in ids:
        url=urls.get(aid)
        if url:
            im=download_thumbnail(url)
            if im is not None:
                im.thumbnail((420,420))
                im.save(folder/f"{aid}.png")
                images[aid]=im
    font=ImageFont.load_default()
    candidates=[m for m in catalog["models"] if m["classification"]=="candidate"]
    for model in candidates:
        for component in model["components"]:
            aid=component["meshAssetId"]
            if aid in images:
                model["visual"]["evidence"].append({"kind":"official_mesh_thumbnail","assetId":aid,"path":f"thumbs/{aid}.png","scope":"component_only"})
        if model["visual"]["evidence"]:
            model["visual"]["status"]="partial_evidence"
    # Four plants per sheet; two component thumbnails per plant, with clear labeling.
    for start in range(0,len(candidates),4):
        sheet=Image.new("RGB",(1120,830),"#eef2f5")
        draw=ImageDraw.Draw(sheet)
        draw.rectangle((0,0,1120,65),fill="#182638")
        draw.text((18,16),"PACK COMPONENT PREVIEWS | NOT assembled model renders",font=font,fill="white")
        draw.text((18,38),"Colors in PBR textures may differ. Names and tints are metadata only.",font=font,fill="#c0cddd")
        for i,m in enumerate(candidates[start:start+4]):
            x=18+(i%2)*552;y=80+(i//2)*370
            draw.rectangle((x,y,x+532,y+350),fill="white",outline="#bbc9d5")
            draw.text((x+12,y+10),m["name"],font=font,fill="#152638")
            draw.text((x+12,y+29),f"Parts {m['technical']['parts']} | PBR {m['technical']['pbr']} | visual review pending",font=font,fill="#526274")
            for j,c in enumerate(m["components"][:2]):
                xx=x+12+j*260; yy=y+55; aid=c["meshAssetId"]
                draw.rectangle((xx,yy,xx+248,yy+235),fill="#e4eaf0")
                if aid in images:
                    im=images[aid].copy();im.thumbnail((242,229));sheet.paste(im,(xx+(248-im.width)//2,yy+(235-im.height)//2))
                else: draw.text((xx+45,yy+100),"Mesh preview unavailable",font=font,fill="#607080")
                draw.text((xx,yy+244),str(c["name"])[:32],font=font,fill="#182638")
                tint=tuple(round(v*255) for v in c["tint"])
                draw.rectangle((xx,yy+263,xx+17,yy+280),fill=tint,outline="#555555")
                draw.text((xx+23,yy+266),f"tint RGB {tint}",font=font,fill="#526274")
        sheet.save(output/f"components-{start//4+1:02}.png")
    if catalog["packAssetId"] in images:
        images[catalog["packAssetId"]].save(output/"pack-thumbnail.png")
    write(output/"visual-catalog.json",catalog)
    print(f"VISUAL CATALOG: {len(catalog['models'])} models, {len(candidates)} candidates, {len(images)}/{len(ids)} thumbnails")
    print("Full model render and visual description not automatically inferred.")

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--inventory",type=Path,required=True)
    p.add_argument("--output",type=Path,default=ROOT/"dist"/"visual-memory")
    a=p.parse_args()
    try:
        c=build_catalog(json.loads(a.inventory.read_text()))
        render(c,a.output)
        return 0
    except (ValueError,KeyError,OSError,DiscoveryError) as exc:
        print(f"ERROR: {exc}")
        return 1
if __name__=="__main__":raise SystemExit(main())
