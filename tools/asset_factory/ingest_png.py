"""Register exact PNG bytes from a repository inbox, without resampling."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser();p.add_argument("source",type=Path);p.add_argument("asset");p.add_argument("revision");a=p.parse_args()
for s in (a.asset,a.revision):
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}",s): p.error("Invalid identifier")
root=Path(__file__).resolve().parents[2]/"asset-library"
src=a.source.resolve()
if not src.is_relative_to((root/"inbox").resolve()): p.error("Inbox required")
with Image.open(src) as im:
    if im.format!="PNG" or max(im.size)>4096 or min(im.size)<1: p.error("Invalid PNG")
    size=im.size;im.verify()
dst=root/"paint-inputs"/a.asset/a.revision
dst.mkdir(parents=True,exist_ok=False)
q=dst/"color.png";shutil.copyfile(src,q)
(dst/"manifest.json").write_text(json.dumps({"schema":1,"asset":a.asset,"revision":a.revision,"sha256":hashlib.sha256(q.read_bytes()).hexdigest(),"size":size,"status":"unbound_artwork"},indent=2))
