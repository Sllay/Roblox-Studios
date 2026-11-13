"""Continuous orthographic visual hull using signed distance fields."""
import numpy as np
from scipy.ndimage import distance_transform_edt, gaussian_filter
from skimage.measure import marching_cubes
def signed(mask):
    return distance_transform_edt(mask)-distance_transform_edt(~mask)
def continuous_surface(masks,sigma=.65):
    f,r,t=(signed(np.asarray(masks[k],bool))[::-1,:].T for k in ("front","right","top"))
    field=np.minimum(np.minimum(f[:,None,:],r[None,:,:]),t[:,:,None])
    field=gaussian_filter(field,sigma)
    n=field.shape[0]
    verts,faces,_,_=marching_cubes(np.pad(field,1,constant_values=-2),level=0,gradient_direction="ascent")
    verts=(verts-.5)/n*2-1
    return verts.tolist(),faces.tolist()
