"""C3-C conservative CPU volume reconstruction.

Measured depth can remove observed free space. Untrusted neural shapes remain
priors; they never become metric depth observations. Every output is a candidate.
"""
from __future__ import annotations
import numpy as np
from .contracts import require
from .hull_alignment import build_hull,ortho_project,ray_intervals,validate_views

def carve_known_depth(hull,views,depths,tolerance_voxels=1.25):
    """Intersect the visual hull with observed free space.
    Ignore occluded space and unstable depth edges; no averaging conflicts.
    """
    require(validate_views(views)=="known_camera_outer_hypothesis","Depth carving requires measured/known cameras")
    require(set(depths)<=set(views) and bool(depths),"Missing depth evidence")
    require(np.isfinite(tolerance_voxels) and .5<=tolerance_voxels<=3,"Depth tolerance")
    grid=hull["grid"].copy();step=hull["step"];origin=hull["origin"];total=int(grid.sum())
    idx=np.argwhere(grid);points=origin+(idx+.5)*step;remove=np.zeros(len(idx),bool);per_view={}
    for name,d in depths.items():
        m,c=views[name]
        require(d.shape==m.shape and np.isfinite(d).all() and (d[m]>0).all(),"Invalid known depth")
        x,y,z=ortho_project(points,c,m.shape);ix=np.floor(x).astype(int);iy=np.floor(y).astype(int)
        q=np.flatnonzero((ix>=1)&(iy>=1)&(ix<m.shape[1]-1)&(iy<m.shape[0]-1)&(z>0))
        ix=ix[q];iy=iy[q]
        mask=np.stack([m[iy+j,ix+i] for j in (-1,0,1) for i in (-1,0,1)])
        values=np.stack([d[iy+j,ix+i] for j in (-1,0,1) for i in (-1,0,1)])
        # Only carve in fully observed neighborhoods without a large jump.
        stable=mask.all(0)&(np.ptp(values,axis=0)<=6*step)
        free=stable&(z[q]<values.min(0)-tolerance_voxels*step)
        per_view[name]=int(free.sum());remove[q[free]]=True
    removed=idx[remove];grid[removed[:,0],removed[:,1],removed[:,2]]=False
    require(grid.any(),"Depth constraints removed entire volume")
    return {**hull,"grid":grid},{"initial_voxels":total,"retained_voxels":int(grid.sum()),"carved_voxels":int(remove.sum()),"per_view_free_space":per_view,"scope":"known depth free-space carving; not neural metric inference"}

def surface_from_grid(hull,smoothing=0.0):
    from skimage.measure import marching_cubes
    from scipy.ndimage import gaussian_filter
    grid=hull["grid"];require(grid.any() and not grid.all(),"Invalid occupancy")
    field=np.pad(grid.astype(np.float32),1)
    if smoothing:
        require(0<smoothing<=1,"Smoothing in voxel units")
        field=gaussian_filter(field,smoothing)
    require(field.max()>.5,"Surface vanished")
    v,f,_,_=marching_cubes(field,.5,allow_degenerate=False)
    v=hull["origin"]+(v-1+.5)*hull["step"]
    # marching_cubes gradient convention is not relied on for export.
    import trimesh
    mesh=trimesh.Trimesh(vertices=v,faces=f,process=False);mesh.fix_normals()
    return np.asarray(mesh.vertices,dtype=np.float64),np.asarray(mesh.faces,dtype=np.int32)

def neural_occupancy(v,f,hull):
    """Resample a closed prior onto the common voxel lattice, not the final mesh."""
    import trimesh
    mesh=trimesh.Trimesh(vertices=v,faces=f,process=False)
    require(mesh.is_watertight,"Neural prior must be watertight")
    vox=mesh.voxelized(pitch=hull["step"],method="subdivide").fill()
    grid=np.zeros_like(hull["grid"]);idx=np.floor((vox.points-hull["origin"])/hull["step"]).astype(int)
    good=((idx>=0)&(idx<np.asarray(grid.shape))).all(1);idx=idx[good]
    grid[idx[:,0],idx[:,1],idx[:,2]]=True
    require(grid.any(),"Prior outside reconstruction lattice")
    return grid

def signed_grid(grid):
    from scipy.ndimage import distance_transform_edt
    return distance_transform_edt(~grid)-distance_transform_edt(grid)

def prior_candidates(hull,prior):
    """Frozen hypotheses: hull, clipped prior and two regularized SDF blends.
    Blend is a shape hypothesis, not fusion of measured depth. All candidates
    remain inside the hull; no per-animal topology repair.
    """
    require(prior.shape==hull["grid"].shape and prior.dtype==bool,"Prior grid shape")
    h=hull["grid"];sdh=signed_grid(h);sdp=signed_grid(prior)
    clipped=prior&h;require(clipped.any(),"Prior/hull do not overlap")
    result={"hull":h.copy(),"clipped_prior":clipped}
    for a in (.35,.65):
        field=(1-a)*sdh+a*sdp;g=h&(field<=0)
        if g.any():result["hybrid_"+str(a)]=g
    return result

def depth_metrics(volume,views,truth):
    result={}
    for name,d in truth.items():
        mask,c=views[name];near,far,runs=ray_intervals(volume,c,mask.shape);hit=near>0;use=mask&hit
        require(use.any(),"No comparable rays")
        err=np.abs(near[use]-d[use])
        result[name]={"mask_iou":float(use.sum()/(mask|hit).sum()),"coverage":float(use.sum()/mask.sum()),"near_mae":float(err.mean()),"near_p95":float(np.percentile(err,95))}
    return result
