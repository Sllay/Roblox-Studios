"""C1 command entry points, preserving the C0 CLI."""
import argparse,json,sys
from pathlib import Path
from dataclasses import asdict
from . import audit
from .contracts import AssetManifest,validate_manifest,legacy_rabbit
from .dag import build,read_state,validate_job
def main(argv=None):
    argv=list(sys.argv[1:] if argv is None else argv)
    if not argv or argv[0]=="audit":return audit.main(argv)
    p=argparse.ArgumentParser();sub=p.add_subparsers(dest="cmd",required=True)
    b=sub.add_parser("build");b.add_argument("--manifest",type=Path,required=True);b.add_argument("--out",type=Path,required=True);b.add_argument("--config",type=Path);b.add_argument("--resume",action="store_true")
    for cmd in ("inspect","resume","validate"):
        q=sub.add_parser(cmd);q.add_argument("--job",type=Path,required=True)
    q=sub.add_parser("validate-manifest");q.add_argument("--manifest",type=Path,required=True)
    q=sub.add_parser("legacy-rabbit");q.add_argument("--source",type=Path,required=True)
    q=sub.add_parser("preflight");q.add_argument("--out",type=Path,required=True);q.add_argument("--blender",default="blender");q.add_argument("--profile",default="creature");q.add_argument("--require-backend",action="append",default=[])
    q=sub.add_parser("fixtures");q.add_argument("--out",type=Path,required=True);q.add_argument("--blender",default="blender");q.add_argument("--resolution",type=int,default=128)
    a=p.parse_args(argv)
    if a.cmd=="build":r=build(a.manifest,a.out,json.loads(a.config.read_text()) if a.config else {},resume=a.resume)
    elif a.cmd=="inspect":r=read_state(a.job)
    elif a.cmd=="resume":
        s=read_state(a.job);r=build(s["manifest_path"],a.job,s["config"],resume=True)
    elif a.cmd=="validate":r=validate_job(a.job)
    elif a.cmd=="validate-manifest":r=validate_manifest(AssetManifest.read(a.manifest),a.manifest.parent)
    elif a.cmd=="legacy-rabbit":r=asdict(legacy_rabbit(a.source))
    elif a.cmd=="preflight":
        from .backends import probe
        r=probe(a.out,a.blender,a.profile,tuple(a.require_backend or ["blender_cpu"]))
    else:
        from .fixtures import generate
        r=generate(a.out,a.blender,a.resolution)
    print(json.dumps(r,indent=2,allow_nan=False));return 1 if r.get("status") in ("invalid","blocked") else 0
