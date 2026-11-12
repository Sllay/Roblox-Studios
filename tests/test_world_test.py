import sys,unittest,json,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/"tools"))
from world_test import validate,WorkspaceError,PLAN
class WorldTests(unittest.TestCase):
    def test_plan(self):
        p=json.loads(PLAN.read_text());self.assertEqual(validate(p),p)
        for key,v in [("chunkSize",512),("maxModels",1000),("spawnRadius",400)]:
            q=copy.deepcopy(p);q[key]=v
            with self.assertRaises(WorkspaceError):validate(q)
    def test_death_guard(self):
        s=(ROOT/"games/maps/mapa-principal/game/places/main/src/ServerScriptService/RSCentralSpawnSafety.server.luau").read_text()
        self.assertIn("not alive(character)",s)
        self.assertIn("hum.BreakJointsOnDeath=true",s)
        self.assertIn("Players.CharacterAutoLoads=true",s)
        self.assertNotIn("Players.CharacterAutoLoads=false",s)
        self.assertNotIn("LoadCharacterAsync",s)
        self.assertIn("voxel_estimate",s)
    def test_support_not_terrain(self):
        s=(ROOT/"tools/sync/prop_support.luau").read_text()
        self.assertNotIn("WriteVoxel",s);self.assertIn("model:PivotTo(cf)",s)
