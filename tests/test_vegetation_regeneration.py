import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from vegetation_regeneration import kind,distance
from spatial_index import Occupancy
class RegenerationTests(unittest.TestCase):
    def test_classification(self):
        self.assertEqual(kind({"species":"Pine_01.1"}),"pine")
        self.assertEqual(kind({"species":"Tree_08"}),"tree")
        self.assertEqual(kind({"species":"Bush_03"}),"bush")
        self.assertEqual(kind({"species":"Mossy_Rock"}),"fixed")
    def test_separate_canopy_and_ground(self):
        ground=Occupancy([{"id":"tree","x":0,"z":0,"radius":3}])
        canopy=Occupancy([{"id":"tree","x":0,"z":0,"radius":12}])
        self.assertFalse(ground.blocked(9,0,3))
        self.assertTrue(canopy.blocked(9,0,12))
        self.assertEqual(distance((0,0),(3,4)),5)
