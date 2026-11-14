"""Persist wood UV-only release and upload once; no Place writes."""
import json,os,sys,shutil
from pathlib import Path
from PIL import Image,ImageOps
from s08_prop_intake import ROOT,EGG,submit,commit,write,sha
def main():
    src=Path(sys.argv[1]);dest=EGG/"wood-uv";dest.mkdir(exist_ok=True)
    report=json.loads((src/"manifest.json").read_text())
    assert report["geometryUnchanged"] and report["triangles"]==14460
    audit=json.loads((src/"uv-audit.json").read_text())
    assert audit["triangles"]==14460 and all(audit[k]==0 for k in ("degenerate","outsideUnitSquare","overlapPairs")),audit
    for name in ("wood-v4-uv.glb","bark-neutral.png","manifest.json","uv-audit.json"):
        shutil.copyfile(src/name,dest/name)
    im=Image.open(dest/"bark-neutral.png").convert("L")
    assert im.getextrema()[1]-im.getextrema()[0]>20
    mask=Image.open(dest/"bark-neutral.png").convert("RGBA")
    # Keep the actual RGB bark artwork even in lower-alpha pixels; alpha controls tint, not opacity.
    mask.putalpha(im.point(lambda x: 180+round(75*x/255)))
    mask.save(dest/"bark-alpha-mask.png")
    report["maskSha256"]=sha((dest/"bark-alpha-mask.png").read_bytes());write(dest/"manifest.json",report)
    commit([dest],"assets(s082): exact Wood V4 geometry with neutral bark UV and separate alpha mask")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    ids={}
    for name,file,kind in [("eggydrasil-wood-v4-uv","wood-v4-uv.glb","Model"),("eggydrasil-bark-neutral","bark-neutral.png","Image"),("eggydrasil-bark-alpha-mask","bark-alpha-mask.png","Image")]:
        r=submit(key,"8136365379","User",name,dest/file,kind);assert r["state"]=="created";ids[name]=r["assetId"]
    write(dest/"roblox-ids.json",ids);commit([dest/"roblox-ids.json"],"evidence(s082): wood UV and bark texture upload receipts")
    print("S082_WOOD_IDS",json.dumps(ids),flush=True)
if __name__=="__main__":main()
