import unittest
import numpy as np
from tools.creature_factory.next.deep_correspondence import mutual_matches,epipolar_mask
from tools.creature_factory.next.contracts import CameraCalibration,ContractError
class DeepCorrespondenceTests(unittest.TestCase):
    def test_mutual_and_distinct(self):
        p=np.array([[0,0],[12,0],[24,0]],float);f=np.eye(3)
        self.assertEqual(len(mutual_matches(p,f,p,f)),3)
        self.assertEqual(mutual_matches(p,np.ones((3,3)),p,np.ones((3,3))),[])
    def test_geometry_restriction(self):
        p=np.array([[0,0],[12,0],[24,0]],float);f=np.eye(3)
        allowed=np.eye(3,dtype=bool)
        # No alternative: cannot establish descriptor distinctiveness.
        self.assertEqual(mutual_matches(p,f,p,f,allowed),[])
    def test_nonfinite(self):
        p=np.array([[0,0],[12,0]],float);f=np.eye(2);f[0,0]=np.nan
        with self.assertRaises(ContractError):mutual_matches(p,f,p,f)
    def test_epipolar(self):
        m=np.ones((64,64),bool)
        a=CameraCalibration("known","orthographic",[[1,0,0,0],[0,0,-1,-5],[0,1,0,0],[0,0,0,1]],4,confidence=1)
        b=CameraCalibration("known","orthographic",[[0,0,1,5],[1,0,0,0],[0,1,0,0],[0,0,0,1]],4,confidence=1)
        p=np.array([[20,10],[30,30]],float)
        self.assertTrue(np.array_equal(epipolar_mask(p,p,(m,a),(m,b)),np.eye(2,dtype=bool)))
