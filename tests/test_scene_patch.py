import sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/"tools"))
from scene_patch import changes,cf,prepare,WorkspaceError
class PatchTests(unittest.TestCase):
    def test_cframe(self):
        cf([1,2,3,1,0,0,0,1,0,0,0,1])
        with self.assertRaises(WorkspaceError):cf([1,2,3,1,0,0,0,1,0,0,0,-1])
    def test_property_allowlist(self):
        changes({"size":[2,3,4],"color":[1,0,0]})
        for p in ({"Source":"bad"},{"size":[0,1,1]},{"material":"Air"}):
            with self.assertRaises(WorkspaceError):changes(p)
    def test_stale(self):
        with self.assertRaises(WorkspaceError):prepare({"environment":"staging"},{"loadedVersion":7,"stateDigest":"a"},{"schemaVersion":1,"expectedVersion":6,"baselineDigest":"a"})
