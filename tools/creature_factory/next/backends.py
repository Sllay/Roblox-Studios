"""Capability discovery, not backend adoption."""
from pathlib import Path
import importlib.util, shutil
from .audit import preflight,validate_output,write_json
def probe(out,blender="blender"):
    out=validate_output(Path(out));out.mkdir(parents=True,exist_ok=True)
    base=preflight(out,blender)
    result={"schema":1,"host":base,"backends":{
      "blender_cpu":{"available":base["blender"]["status"]=="passed","device":"cpu","dependencies":["blender","embedded numpy"],"license":"GPL-2.0-or-later","provenance":"official 4.3.2 pinned CI bundle","estimated_memory_mib":1024,"multiview":True,"depth":True,"normals":True,"scope":"render known geometry, not inference"},
      "depth_anything_v2_small":{"available":False,"device":"cpu","dependencies":["torch","weights"],"license":"Apache-2.0 (Small checkpoint)","provenance":"https://github.com/DepthAnything/Depth-Anything-V2","estimated_memory_mib":None,"multiview":False,"depth":True,"normals":False,"scope":"candidate; not installed or validated C1"},
      "hunyuan3d_2mv":{"available":False,"device":"gpu","dependencies":["CUDA","weights"],"license":"custom; suitability unresolved","provenance":"https://huggingface.co/tencent/Hunyuan3D-2mv","estimated_memory_mib":None,"multiview":True,"depth":False,"normals":False,"scope":"blocked hardware/license"}}}
    write_json(out/"capabilities.json",result);return result
