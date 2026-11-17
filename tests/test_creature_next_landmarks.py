import unittest
import numpy as np
from tools.creature_factory.next.landmarks import *
from tools.creature_factory.next.contracts import CameraCalibration,ContractError
from tools.creature_factory.next.hull_alignment import ortho_project
def camera(r,u,b):
    return CameraCalibration("known","orthographic",[[r[i],u[i],b[i],5*b[i]] for i in range(3)]+[[0,0,0,1]],4,confidence=1)
class LandmarkTests(unittest.TestCase):
    def setUp(self):
        m=np.ones((64,64),bool);self.views={"front":(m,camera((1,0,0),(0,0,1),(0,-1,0))),"right":(m,camera((0,1,0),(0,0,1),(1,0,0))),"top":(m,camera((1,0,0),(0,1,0),(0,0,1)))}
        self.hashes={k:"a"*64 for k in self.views};self.d=LandmarkDefinition("left_eye_outer","head","left");self.p=np.array([.2,-.4,.6])
        self.obs=[LandmarkObservation(self.d.id,k,"visible","reviewed",1,list(ortho_project(self.p,c,m.shape)[:2]),self.hashes[k]) for k,(m,c) in self.views.items()]
    def test_identity_and_holdout(self):
        b=LandmarkBundle("test",[self.d],self.obs);r=solve_landmarks(b,self.views,self.hashes)[self.d.id]
        self.assertEqual(r["status"],"heldout_consistent");self.assertTrue(r["metric_candidate"]);self.assertTrue(np.allclose(r["point"],self.p))
        held=next(iter(r["heldout_reprojection"]))
        bad=[LandmarkObservation(o.landmark_id,o.view_id,"visible","reviewed",1,[o.xy[0]+10,o.xy[1]],o.reference_sha256) if o.view_id==held else o for o in self.obs]
        self.assertEqual(solve_landmarks(LandmarkBundle("test",[self.d],bad),self.views,self.hashes)[self.d.id]["status"],"heldout_rejected")
    def test_no_duplicate_and_occlusion(self):
        with self.assertRaises(ContractError):LandmarkBundle("test",[self.d],self.obs+[self.obs[0]])
        with self.assertRaises(ContractError):LandmarkObservation(self.d.id,"top","occluded","reviewed",1,[1,1],"a"*64)
        obs=self.obs[:2]+[LandmarkObservation(self.d.id,"top","unknown","reviewed",0,None,"a"*64)]
        self.assertEqual(solve_landmarks(LandmarkBundle("test",[self.d],obs),self.views,self.hashes)[self.d.id]["status"],"insufficient_independent_views")
    def test_stale_source(self):
        with self.assertRaises(ContractError):solve_landmarks(LandmarkBundle("test",[self.d],self.obs),self.views,{**self.hashes,"front":"b"*64})
    def test_candidate_not_promoted(self):
        obs=[LandmarkObservation(o.landmark_id,o.view_id,o.visibility,"detector_candidate",1,o.xy,o.reference_sha256) for o in self.obs]
        r=solve_landmarks(LandmarkBundle("test",[self.d],obs),self.views,self.hashes)[self.d.id]
        self.assertEqual(r["status"],"heldout_consistent");self.assertFalse(r["metric_candidate"])
    def test_internal_joint_not_surface(self):
        d=LandmarkDefinition(self.d.id,"head","left","joint")
        self.assertEqual(solve_landmarks(LandmarkBundle("test",[d],self.obs),self.views,self.hashes)[d.id]["status"],"not_surface_anchor")
