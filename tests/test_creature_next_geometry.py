import unittest
import numpy as np
from tools.creature_factory.next.contracts import CameraCalibration,ContractError
from tools.creature_factory.next.geometry_evidence import *

def camera(z=5):
    return CameraCalibration("known","orthographic",[[1,0,0,0],[0,1,0,0],[0,0,1,z],[0,0,0,1]],4,confidence=1)

class GeometryEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.mask=np.zeros((32,32),bool);self.mask[4:-4,4:-4]=True
        self.depth=np.where(self.mask,5.,0.).astype(np.float32);self.c=camera()
    def test_normals_and_discontinuity(self):
        n,ok=normals_from_depth(self.depth,self.mask,self.c,.2)
        self.assertTrue(np.allclose(n[ok],[0,0,1]));self.assertFalse(ok[4,4])
        d=self.depth.copy();d[:,16:][self.mask[:,16:]]-=1
        n,ok=normals_from_depth(d,self.mask,self.c,.2)
        self.assertFalse(ok[:,15:17].any());self.assertTrue(ok[10,10])
    def test_perspective_surface(self):
        c=CameraCalibration("known","perspective",[[1,0,0,0],[0,1,0,0],[0,0,1,5],[0,0,0,1]],intrinsics=[[50,0,16],[0,50,16],[0,0,1]],confidence=1)
        n,ok=normals_from_depth(self.depth,self.mask,c,.2)
        self.assertTrue(np.allclose(n[ok],[0,0,1]))
        p=world_points(self.depth,self.mask,c);x,y,d=project_points(p[10:20,10:20],c,self.mask.shape)
        self.assertAlmostEqual(x[0,0],10.5);self.assertAlmostEqual(y[0,0],10.5)
    def test_conflict_not_occlusion(self):
        nearer=self.depth.copy();nearer[self.mask]-=.5
        a=compare_pair(nearer,self.mask,self.c,self.depth,self.mask,self.c,.05,.2)
        b=compare_pair(self.depth,self.mask,self.c,nearer,self.mask,self.c,.05,.2)
        self.assertEqual(a[16,16],3);self.assertEqual(b[16,16],2)
        r=assess_multiview({"a":(nearer,self.mask,self.c),"b":(self.depth,self.mask,self.c)},.05,.2)
        self.assertEqual(r["a"]["score"][16,16],0);self.assertEqual(r["b"]["score"][16,16],0)
    def test_agreement_and_background(self):
        r=assess_multiview({"a":(self.depth,self.mask,self.c),"b":(self.depth,self.mask,self.c)},.05,.2)
        self.assertEqual(r["a"]["score"][16,16],1)
        m=self.mask.copy();m[12:20,12:20]=False;d=np.where(m,self.depth,0)
        a=compare_pair(self.depth,self.mask,self.c,d,m,self.c,.05,.2)
        self.assertEqual(a[16,16],5);self.assertEqual(a[12,16],4)
    def test_no_metric_for_unknown(self):
        with self.assertRaises(ContractError):world_points(self.depth,self.mask,CameraCalibration("unknown"))
    def test_anchor_and_relative(self):
        s=np.arange(20,dtype=np.float32);d=1/(.01*s+.1)
        a,b,n=fit_anchors(s,d);self.assertAlmostEqual(a,.01,places=6);self.assertAlmostEqual(b,.1,places=6)
        with self.assertRaises(ContractError):fit_anchors(-s,d)
        s=np.arange(1024,dtype=np.float32).reshape(32,32)
        self.assertTrue(np.allclose(relative_stability(s,2*s+3,self.mask)[self.mask],1))
        self.assertLess(relative_stability(s,-s,self.mask)[self.mask].mean(),.6)
