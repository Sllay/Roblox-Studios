import unittest
import numpy as np
from tools.creature_factory.next.rigid_alignment import *
class SimilarityTests(unittest.TestCase):
    def test_rotations(self):
        r=rotations();self.assertEqual(len(r),24)
        self.assertTrue(all(np.allclose(x.T@x,np.eye(3)) and np.linalg.det(x)>.99 for x in r))
    def test_iou(self):
        m=np.eye(4,dtype=bool);self.assertEqual(iou(m,m),1);self.assertEqual(iou(m,~m),0)
    def test_render_union(self):
        from tools.creature_factory.next.contracts import CameraCalibration
        c=CameraCalibration("known","orthographic",[[1,0,0,0],[0,1,0,0],[0,0,1,5],[0,0,0,1]],4,confidence=1)
        v=np.array([[-1,-1,0],[1,-1,0],[1,1,0],[-1,1,0]],float);f=np.array([[0,1,2],[0,2,3]])
        a=render_mask(v,f,c,(64,64));b=render_mask(v,np.r_[f,f],c,(64,64))
        self.assertTrue(np.array_equal(a,b));self.assertTrue(a[32,32]);self.assertFalse(a[0,0])
