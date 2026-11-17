import unittest
import numpy as np
from tools.creature_factory.next.volumetric_reconstruction import *
from tools.creature_factory.next.contracts import CameraCalibration,ContractError
class VolumeTests(unittest.TestCase):
    def test_known_depth_removes_only_free_space(self):
        c=CameraCalibration("known","orthographic",[[1,0,0,0],[0,1,0,0],[0,0,1,5],[0,0,0,1]],4,confidence=1)
        m=np.ones((32,32),bool);d=np.full(m.shape,5,np.float32)
        # Two distinct view IDs with same camera are a controlled carving test,
        # not triangulation or independent evidence.
        h={"grid":np.ones((12,12,12),bool),"origin":np.array([-.6,-.6,-.6]),"step":.1}
        result,r=carve_known_depth(h,{"a":(m,c),"b":(m,c)},{"a":d})
        self.assertGreater(r["carved_voxels"],0);self.assertTrue(result["grid"][:,:,:6].all());self.assertFalse(result["grid"][:,:,-1].any())
        self.assertTrue(h["grid"].all())
    def test_estimated_depth_rejected(self):
        c=CameraCalibration("estimated","orthographic",[[1,0,0,0],[0,1,0,0],[0,0,1,5],[0,0,0,1]],4,confidence=.4)
        m=np.ones((16,16),bool);h={"grid":np.ones((4,4,4),bool),"origin":np.zeros(3),"step":.1}
        with self.assertRaises(ContractError):carve_known_depth(h,{"a":(m,c),"b":(m,c)},{"a":np.ones(m.shape)})
    def test_surface_and_prior_confinement(self):
        h=np.zeros((20,20,20),bool);h[2:18,2:18,2:18]=True;p=np.zeros_like(h);p[5:15,5:15,5:15]=True
        grid={"grid":h,"origin":np.zeros(3),"step":.1}
        for g in prior_candidates(grid,p).values():self.assertFalse((g&~h).any())
        v,f=surface_from_grid(grid)
        self.assertGreater(len(f),0);self.assertGreaterEqual(v.min(),0)
