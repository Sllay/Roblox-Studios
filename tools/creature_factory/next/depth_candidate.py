"""C2-C candidate: local CPU Depth Anything V2 Small inference.
Produces relative inverse-depth evidence; no metric depth or adopted backend claim.
"""
from pathlib import Path
import time,hashlib
from .audit import sha256
from .contracts import require
MODEL_ID="depth-anything/Depth-Anything-V2-Small-hf"
REVISION="b4769fd619394250528294b658587285526fab1c"
WEIGHT_SHA256="3152477ce0d8d6978d76b995120de97cb5b928701fd0f817769f59e249a16b70"
class DepthCandidate:
    def __init__(self,model_dir):
        import torch
        from transformers import AutoImageProcessor,AutoModelForDepthEstimation
        self.torch=torch;torch.set_num_threads(2);torch.set_num_interop_threads(1)
        p=Path(model_dir)
        require(sha256(p/"model.safetensors")==WEIGHT_SHA256,"Depth weights hash mismatch")
        self.provenance={"model":MODEL_ID,"revision":REVISION,"weights_sha256":WEIGHT_SHA256,"license":"Apache-2.0",
            "files":{name:sha256(p/name) for name in ("model.safetensors","config.json","preprocessor_config.json")},
            "device":"cpu","semantics":"relative inverse-depth score (higher means nearer), not metric"}
        self.processor=AutoImageProcessor.from_pretrained(p,local_files_only=True,trust_remote_code=False)
        self.model=AutoModelForDepthEstimation.from_pretrained(p,local_files_only=True,trust_remote_code=False,use_safetensors=True).eval().to("cpu")
        self.provenance["torch"]=torch.__version__
    def predict(self,im,background=192):
        import numpy as np
        from PIL import Image
        torch=self.torch;start=time.monotonic()
        im=im.convert("RGBA");w,h=im.size
        # Square letterbox, preserve aspect ratio. Never send input images to a service.
        scale=518/max(w,h);nw,nh=max(1,round(w*scale)),max(1,round(h*scale));left,top=(518-nw)//2,(518-nh)//2
        rgba=im.resize((nw,nh),Image.Resampling.LANCZOS)
        canvas=Image.new("RGB",(518,518),(background,)*3);canvas.paste(rgba,(left,top),rgba.getchannel("A"))
        inp=self.processor(images=canvas,return_tensors="pt")
        with torch.inference_mode():
            raw=self.model(**inp).predicted_depth
            pred=torch.nn.functional.interpolate(raw[:,None],size=(518,518),mode="bicubic",align_corners=False)[0,0]
            pred=pred[top:top+nh,left:left+nw][None,None]
            pred=torch.nn.functional.interpolate(pred,size=(h,w),mode="bilinear",align_corners=False)[0,0].numpy().astype(np.float32)
        require(np.isfinite(pred).all(),"Nonfinite depth score")
        return pred,{"seconds":time.monotonic()-start,"input_size":[w,h],"letterbox":[left,top,nw,nh],"background":background}
def fit_inverse_depth(pred,truth,mask):
    """Oracle fixture calibration only: fit on disjoint grid subset, evaluate held-out pixels."""
    import numpy as np
    yy,xx=np.indices(mask.shape);valid=mask&np.isfinite(pred)&np.isfinite(truth)&(truth>0)
    train=valid&((xx+3*yy)%4==0);test=valid&~train
    p=pred[train].astype(np.float64);t=1/truth[train].astype(np.float64)
    if len(p)<8 or len(pred[test])<8:return {"status":"insufficient_samples"}
    true_range=float(np.ptp(truth[valid]))
    if true_range<1e-5:return {"status":"constant_ground_truth","raw_std":float(pred[valid].std()),"raw_range":float(np.ptp(pred[valid])),"true_range":true_range}
    if float(np.std(p))<1e-8:return {"status":"constant_prediction","true_range":true_range}
    slope,offset=np.linalg.lstsq(np.column_stack([p,np.ones(len(p))]),t,rcond=None)[0]
    q=pred[test].astype(np.float64);gt=truth[test].astype(np.float64)
    inv=slope*q+offset
    corr=float(np.corrcoef(q,1/gt)[0,1]) if np.std(q)>0 and np.std(gt)>0 else None
    if slope<=0 or np.any(inv<=0):return {"status":"orientation_or_alignment_failed","slope":float(slope),"correlation":corr,"true_range":true_range}
    est=1/inv;err=np.abs(est-gt);baseline=np.abs(np.median(truth[train])-gt)
    return {"status":"oracle_affine_inverse_depth","slope":float(slope),"offset":float(offset),"correlation":corr,"true_range":true_range,
       "mae":float(err.mean()),"p95":float(np.percentile(err,95)),"normalized_mae":float(err.mean()/true_range),
       "constant_baseline_mae":float(baseline.mean()),"improvement_over_constant":float(1-err.mean()/max(baseline.mean(),1e-12)),"heldout_pixels":int(test.sum())}
def background_sensitivity(a,b,mask):
    import numpy as np
    x=a[mask].astype(np.float64);y=b[mask].astype(np.float64)
    if len(x)<8 or min(x.std(),y.std())<1e-8:return None
    return float(np.sqrt(np.mean(((x-x.mean())/x.std()-(y-y.mean())/y.std())**2)))
