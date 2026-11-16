import unittest
import numpy as np
from tools.creature_factory.next.contracts import CameraCalibration,ContractError
from tools.creature_factory.next.hull_alignment import *
def camera(r,u,b,t=(0,0,0),status="known"):
    return CameraCalibration(status,"orthographic",[[r[i],u[i],b[i],t[i]+5*b[i]] for i in range(3)]+[[0,0,0,1]],4,confidence=1 if status=="known" else .4)
class HullAlignmentTests(unittest.TestCase):
    def setUp(self):
        m=np.zeros((64,64),bool);m[16:48,16:48]=True
        self.views={"front":(m,camera((1,0,0),(0,0,1),(0,-1,0))),"right":(m,camera((0,1,0),(0,0,1),(1,0,0))),"top":(m,camera((1,0,0),(0,1,0),(0,0,1)))}
    def test_cube_and_intervals(self):
        h=build_hull(self.views,64,0);m,c=self.views["top"];n,f,r=ray_intervals(h,c,m.shape)
        self.assertAlmostEqual(n[32,32],4,delta=.08);self.assertAlmostEqual(f[32,32],6,delta=.08)
        self.assertEqual(r[32,32],1);self.assertEqual(r[0,0],0)
        self.assertLess(abs(h["grid"].sum()*h["step"]**3-8),.3)
    def test_correspondence(self):
        p=np.array([.2,-.4,.6]);obs={}
        for name,(m,c) in self.views.items():
            x,y,d=ortho_project(p,c,m.shape);obs[name]=(x,y)
        q=triangulate_observations(obs,self.views);self.assertTrue(np.allclose(q["point"],p))
        obs["right"]=(obs["right"][0],obs["right"][1]+12)
        with self.assertRaises(ContractError):triangulate_observations(obs,self.views)
    def test_mixed_gauge(self):
        m,c=self.views["top"];self.views["top"]=(m,camera((1,0,0),(0,1,0),(0,0,1),status="estimated"))
        with self.assertRaises(ContractError):build_hull(self.views,64)
    def test_alignment_positive_and_reversed(self):
        y,x=np.indices((64,64));mask=np.ones((64,64),bool);d=4+x/64+y/128
        score=(1/d-.1)/.01;near=d-.02;far=d+.02;runs=np.ones(mask.shape,np.uint16)
        result,r=align_hypothesis(score,mask,near,far,runs,.01)
        self.assertEqual(r["status"],"hull_aligned_candidate");self.assertLess(np.max(abs(result[result>0]-d[result>0])),1e-5)
        result,r=align_hypothesis(-score,mask,near,far,runs,.01)
        self.assertIsNone(result);self.assertEqual(r["status"],"unsupported_orientation")
    def test_flat_span_rejected(self):
        m=np.ones((64,64),bool);x=np.ones(m.shape)*4;r=np.ones(m.shape,np.uint16)
        d,report=align_hypothesis(x,m,x-.01,x+.01,r,.02);self.assertIsNone(d);self.assertEqual(report["status"],"insufficient_hull_depth_span")
