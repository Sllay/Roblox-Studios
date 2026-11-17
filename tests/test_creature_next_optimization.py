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

    def test_sliver_link_collapse_preserves_surface(self):
        import trimesh
        m=trimesh.creation.icosphere(subdivisions=1);v=np.asarray(m.vertices);f=np.asarray(m.faces);i,j=map(int,m.edges_unique[0]);k=len(v)
        vv=np.vstack([v,v[i]+1e-5*(v[j]-v[i])]);ff=[]
        for face in f:
            if i in face and j in face:
                a=next(a for a in range(3) if {int(face[a]),int(face[(a+1)%3])}=={i,j})
                x,y,z=face[a],face[(a+1)%3],face[(a+2)%3];ff.extend([[x,k,z],[k,y,z]])
            else:ff.append(face)
        ff=np.asarray(ff,np.int32);a,b,r=repair_microscopic_edges(vv,ff)
        self.assertEqual(len(r),1);self.assertEqual(len(b),len(f))
        self.assertTrue(topology_compatible(mesh_topology(m),mesh_topology(trimesh.Trimesh(vertices=a,faces=b,process=False))))
