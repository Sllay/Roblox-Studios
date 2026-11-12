import sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools/assets"))
from placement import validate_profile,pivot_y
class PlacementTests(unittest.TestCase):
    def profile(self):
        return dict(schemaVersion=1,mountType="bury_in_ground",orientation="upright",contactRule="bounds_bottom_plus_burial",buryDepthStuds=6,supportRadiusStuds=2,maxSlopeDegrees=15,maxHeightDeltaStuds=1,rayTop=256,rayBottom=-128,groundNames=["Baseplate"],calibrationStatus="provisional")
    def test_burial(self):
        self.assertAlmostEqual(pivot_y(0,-7.99861145,6),1.99861145)
        self.assertEqual(pivot_y(12,-4,0),16)
    def test_invalid(self):
        for k,v in [("buryDepthStuds",-1),("buryDepthStuds",float("nan")),("groundNames",[]),("mountType","wall"),("rayBottom",512)]:
            p=self.profile();p[k]=v
            with self.assertRaises(ValueError):validate_profile(p)
    def test_sit(self):
        p=self.profile();p["mountType"]="sit_on_ground"
        with self.assertRaises(ValueError):validate_profile(p)
        p["buryDepthStuds"]=0;self.assertEqual(validate_profile(p),p)

    def test_custom_anchor(self):
        p=self.profile();p["contactRule"]="local_anchor"
        with self.assertRaises(ValueError):validate_profile(p)
        p["contactLocal"]=[1,-2,3]
        self.assertEqual(validate_profile(p),p)
