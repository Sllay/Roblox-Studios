import unittest
import numpy as np
from tools.creature_factory.next.mesh_optimization import *
class MeshOptimizationTests(unittest.TestCase):
    def test_identical_mesh_passes(self):
        import trimesh
        m=trimesh.creation.icosphere(subdivisions=2)
        p=prepare(m.vertices,m.faces,sample_count=300,resolution=64)
        r=measure(p,m.vertices,m.faces)
        self.assertTrue(r["passed"]);self.assertLess(r["max_distance"],1e-9)
    def test_topology_change_rejected(self):
        import trimesh
        m=trimesh.creation.icosphere(subdivisions=1);p=prepare(m.vertices,m.faces,sample_count=100,resolution=64)
        r=measure(p,m.vertices,m.faces[:-1])
        self.assertFalse(r["passed"]);self.assertEqual(r["reason"],"topology_changed")
    def test_uniform_shrink_detected(self):
        import trimesh
        m=trimesh.creation.icosphere(subdivisions=2);p=prepare(m.vertices,m.faces,sample_count=100,resolution=64)
        r=measure(p,m.vertices*.8,m.faces)
        self.assertFalse(r["passed"])
    def test_master_not_mutated(self):
        import trimesh
        m=trimesh.creation.icosphere(subdivisions=2);v=m.vertices.copy();f=m.faces.copy()
        a,b,r=optimize(v,f,ratios=(.85,),sample_count=200,resolution=64)
        self.assertTrue(np.array_equal(v,m.vertices));self.assertTrue(np.array_equal(f,m.faces));self.assertLessEqual(len(b),len(f))
