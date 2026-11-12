import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from physics_builder import cylinder_profile
from workspace import WorkspaceError
class PhysicsBuilderTests(unittest.TestCase):
    def test_shaft_cap(self):
        p=cylinder_profile(2,3,10,40,2)
        s,c=p["shaft"],p["cap"]
        self.assertAlmostEqual(s["position"][1]-s["size"][0]/2,9.88)
        self.assertAlmostEqual(s["position"][1]+s["size"][0]/2,c["position"][1])
        self.assertEqual(c["position"][1]+c["size"][1]/2,40)
        self.assertEqual(s["size"][1:],c["size"][1:])
        self.assertEqual(s["rotation"],"Z90")
    def test_reject_bad_dimensions(self):
        for args in ((0,0,0,1,4),(0,0,0,10,0),(0,0,0,10,float("nan"))):
            with self.assertRaises(WorkspaceError):cylinder_profile(*args)
