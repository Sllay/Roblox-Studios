
import sys,json,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from terrain_paint import validate,WorkspaceError
class PaintTests(unittest.TestCase):
    def test_plan(self):
        p=json.loads((ROOT/"games/maps/mapa-principal/game/terrain/paint-example.json").read_text())
        self.assertEqual(validate(p),p)
        for bad in ("Air","Water"):
            q=dict(p,material=bad)
            with self.assertRaises(WorkspaceError):validate(q)
    def test_no_geometry_write(self):
        s=(ROOT/"tools/terrain/paint.luau").read_text()
        self.assertEqual(s.count("T:WriteVoxelChannels"),1)
        self.assertIn("T:WriteVoxelChannels(region,4,{SolidMaterial=mat})",s)
        self.assertIn("Paint altered occupancy",s)
