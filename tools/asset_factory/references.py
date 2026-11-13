"""Extract foreground from aligned orthographic references without inventing camera calibration."""
import numpy as np
from PIL import Image
def read_reference(path, resolution=64):
    im=Image.open(path).convert("RGBA")
    if im.width!=im.height: raise ValueError("reference must use a shared square orthographic canvas")
    a=np.asarray(im)
    if np.any(a[:,:,3]<250):
        mask=a[:,:,3]>127
        method="alpha"
    else:
        rgb=a[:,:,:3].astype(float)
        border=np.concatenate([rgb[0],rgb[-1],rgb[:,0],rgb[:,-1]])
        bg=np.median(border,axis=0)
        if np.percentile(np.linalg.norm(border-bg,axis=1),95)>15: raise ValueError("background not uniform; supply alpha mask")
        mask=np.linalg.norm(rgb-bg,axis=2)>25
        method="uniform"
    if not mask.any() or mask.all(): raise ValueError("invalid foreground")
    if mask[0].any() or mask[-1].any() or mask[:,0].any() or mask[:,-1].any(): raise ValueError("foreground clipped by canvas")
    m=Image.fromarray(mask.astype(np.uint8)*255).resize((resolution,resolution),Image.Resampling.NEAREST)
    return np.asarray(m)>127,method
def load_views(refs,resolution=64):
    if set(refs)!={"front","right","top"}: raise ValueError("P2.2 requires front/right/top")
    sizes={Image.open(p).size for p in refs.values()}
    if len(sizes)!=1: raise ValueError("shared canvas size required")
    pairs={k:read_reference(p,resolution) for k,p in refs.items()}
    return {k:v[0] for k,v in pairs.items()},{k:v[1] for k,v in pairs.items()}
