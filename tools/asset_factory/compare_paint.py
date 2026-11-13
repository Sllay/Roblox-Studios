"""Compare aligned studio renders; fail on substantial color loss."""
import sys,json
from pathlib import Path
from PIL import Image
import numpy as np
a,b,out=map(Path,sys.argv[1:])
report={}
for view in ("front","quarter"):
    x=np.asarray(Image.open(a/f"original-{view}.png").convert("RGB"),dtype=float)/255
    y=np.asarray(Image.open(b/f"original-{view}.png").convert("RGB"),dtype=float)/255
    assert x.shape==y.shape
    bg=x[0,0]
    mask=np.max(abs(x-bg),axis=2)>0.08
    assert mask.sum()>1000
    delta=abs(x-y)[mask]
    report[view]={"meanAbsoluteRGB":float(delta.mean()),"p95AbsoluteRGB":float(np.percentile(delta,95)),"foregroundPixels":int(mask.sum()),"referenceMean":float(x[mask].mean()),"candidateMean":float(y[mask].mean())}
out.write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
assert all(v["meanAbsoluteRGB"]<0.08 and v["p95AbsoluteRGB"]<0.25 for v in report.values()),"Visual color fidelity gate failed"
