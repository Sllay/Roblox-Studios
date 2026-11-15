"""CPU marching-cubes adapter for the pinned TripoSR source.
The upstream helper expects torchmcubes' x/z-swapped output convention.
Use the Lewiner implementation from scikit-image, with explicit axis mapping.
"""
import torch
from skimage.measure import marching_cubes as lewiner
def marching_cubes(level,threshold):
    v,f,_,_=lewiner(level.detach().cpu().numpy(),level=float(threshold),allow_degenerate=False)
    return torch.from_numpy(v[:,[2,1,0]].copy()).float(),torch.from_numpy(f.copy()).long()
