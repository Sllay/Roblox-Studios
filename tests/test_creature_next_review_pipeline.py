import unittest
import numpy as np
from tools.creature_factory.next.surface_refinement import smooth_vertices
from tools.creature_factory.next.uv_atlas import metrics
from tools.creature_factory.next.contracts import ContractError
class ReviewPipelineTests(unittest.TestCase):
    def test_smoothing_bounded(self):
        import trimesh
        m=trimesh.creation.icosphere(subdivisions=1);v=m.vertices.copy()
        q=smooth_vertices(v,m.faces,8,.01)
        self.assertLessEqual(np.linalg.norm(q-v,axis=1).max(),.0100001)
        self.assertTrue(np.array_equal(v,m.vertices))
    def test_uv_geometry_and_overlap(self):
        v=np.array([[0,0,0],[1,0,0],[1,1,0],[0,1,0]],float);f=np.array([[0,1,2],[0,2,3]],int)
        r,_=metrics(v,f,np.arange(4),f,v[:,:2]*.8+.1,64)
        self.assertEqual(r["overlap_pixels"],0);self.assertEqual(r["charts"],1)
        with self.assertRaises(ContractError):metrics(v,f,np.arange(4),f[:,::-1],v[:,:2],64)
