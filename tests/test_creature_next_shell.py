import unittest
import numpy as np
from tools.creature_factory.next.contracts import CameraCalibration
from tools.creature_factory.next.shell_visibility import shell_gap,filter_shell

class ShellVisibilityTests(unittest.TestCase):
    def setUp(self):
        m=np.ones((8,8),bool)
        a=CameraCalibration("known","orthographic",[[1,0,0,0],[0,0,-1,-5],[0,1,0,0],[0,0,0,1]],4,confidence=1)
        b=CameraCalibration("known","orthographic",[[0,0,1,5],[1,0,0,0],[0,1,0,0],[0,0,0,1]],4,confidence=1)
        self.views={"front":(m,a),"right":(m,b)}
        self.rays={k:{"near":np.full((8,8),4.),"far":np.full((8,8),6.),"runs":np.ones((8,8),int)} for k in self.views}
        self.r={"point":[1,-1,0],"observations":{"front":[4,4],"right":[4,4]}}
    def test_visible_shell(self):
        self.assertAlmostEqual(shell_gap(self.r,self.views,self.rays,.1)["max_gap_voxels"],0)
        self.assertEqual(len(filter_shell([self.r],self.views,self.rays,.1,2)),1)
    def test_interior_rejected(self):
        r={**self.r,"point":[0,0,0]}
        self.assertEqual(filter_shell([r],self.views,self.rays,.1,4),[])
    def test_front_of_shell_rejected(self):
        r={**self.r,"point":[2,-2,0]}
        self.assertEqual(filter_shell([r],self.views,self.rays,.1,4),[])
    def test_disjoint_ray_rejected(self):
        self.rays["front"]["runs"][4,4]=2
        self.assertIsNone(shell_gap(self.r,self.views,self.rays,.1))
