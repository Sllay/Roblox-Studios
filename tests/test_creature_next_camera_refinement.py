import unittest
import numpy as np
from tools.creature_factory.next.camera_refinement import *
from tools.creature_factory.next.contracts import CameraCalibration

class CameraRefinementTests(unittest.TestCase):
    def setUp(self):
        self.cam=CameraCalibration("known","orthographic",[[1,0,0,0],[0,1,0,0],[0,0,1,5],[0,0,0,1]],4,confidence=1)
        self.shape=(256,256);rng=np.random.default_rng(11);p=rng.uniform(-1,1,(24,3));y=projections(self.cam,self.shape,p)
        self.anchors={f"p{i}":{"point":a.tolist(),"xy":b.tolist(),"weight":1.,"reference_gauge":"known"} for i,(a,b) in enumerate(zip(p,y))}
    def test_recover_perturbed_camera(self):
        initial=adjusted_camera(self.cam,self.shape,[.11,.07,-.05,.04,.03,-.025])
        c,r=refine(initial,self.shape,self.anchors)
        self.assertEqual(r["status"],"refined_camera_hypothesis");self.assertLess(r["holdout_after"]["rmse"],.05)
        self.assertEqual(c.status,"estimated");self.assertFalse(r["metric_calibration"])
    def test_whole_identity_holdout_rejects_wrong_points(self):
        initial=adjusted_camera(self.cam,self.shape,[.1,.03,0,0,.02,0])
        a={k:dict(v) for k,v in self.anchors.items()}
        _,held=split_ids(list(a))
        for k in held:a[k]["xy"]=[a[k]["xy"][0]+25,a[k]["xy"][1]-20]
        c,r=refine(initial,self.shape,a);self.assertIsNone(c);self.assertEqual(r["status"],"holdout_rejected_or_no_improvement")
    def test_insufficient_and_degenerate(self):
        self.assertIsNone(refine(self.cam,self.shape,dict(list(self.anchors.items())[:3]))[0])
        a={k:{**v,"point":[v["point"][0],v["point"][1],0]} for k,v in self.anchors.items()}
        self.assertEqual(refine(self.cam,self.shape,a)[1]["status"],"degenerate_3d_support")
    def test_no_change_for_already_correct(self):
        self.assertIsNone(refine(self.cam,self.shape,self.anchors)[0])
