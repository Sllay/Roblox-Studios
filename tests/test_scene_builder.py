
import sys,json,unittest,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from scene_builder import validate,WorkspaceError
class SceneBuilderTests(unittest.TestCase):
    def test_plan(self):
        p=json.loads((ROOT/"games/maps/mapa-principal/game/terrain/forest-pilot.json").read_text())
        self.assertEqual(validate(p),p)
        for key,value in [("maxModels",2),("terrainDigest","wrong"),("minSpacing",0)]:
            q=copy.deepcopy(p);q[key]=value
            with self.assertRaises(WorkspaceError):validate(q)
    def test_no_terrain_mutation(self):
        s=(ROOT/"tools/scene_builder.luau").read_text()
        self.assertNotIn("WriteVoxel",s)
        self.assertIn("Terrain baseline changed",s)
        self.assertIn("Visual/geometry audit changed",s)
