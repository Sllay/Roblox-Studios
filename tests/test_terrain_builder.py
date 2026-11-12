import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from terrain_builder import validate,WorkspaceError
class TerrainTests(unittest.TestCase):
    def setUp(self):
        self.p=json.loads((ROOT/"games/maps/mapa-principal/game/terrain/pilot-valley.json").read_text())
    def test_plan(self):self.assertEqual(validate(self.p),self.p)
    def test_reject_unsafe(self):
        for path,value in [("bounds",[0,0,0,513,64,512]),("seed",True),("noiseLayers",[])]:
            p=copy.deepcopy(self.p);p[path]=value
            with self.assertRaises(WorkspaceError):validate(p)
        for key,value in [("depth",25),("center",[100,0]),("irregularity",0.9)]:
            p=copy.deepcopy(self.p);p["lake"][key]=value
            with self.assertRaises(WorkspaceError):validate(p)
    def test_paint_channel_only(self):
        s=(ROOT/"tools/terrain/builder.luau").read_text()
        self.assertIn("Terrain:WriteVoxelChannels(region,4,{SolidMaterial=painted})",s)
        self.assertIn("maxSolid==0 and maxWater==0",s)
        self.assertNotIn("Terrain:Clear(",s)
