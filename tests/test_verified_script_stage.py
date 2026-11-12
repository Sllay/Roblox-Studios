import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from verified_script_stage import validate_plan
from workspace import WorkspaceError
class ScriptStageTests(unittest.TestCase):
    def test_scope(self):
        base={"loadedVersion":13,"stateDigest":"abc"}
        p={"schemaVersion":1,"expectedVersion":13,"baselineDigest":"abc","operations":[{"kind":"update_script"}]}
        validate_plan(p,base)
        p["operations"][0]["kind"]="move_model"
        with self.assertRaises(WorkspaceError):validate_plan(p,base)
        p["operations"][0]["kind"]="update_script";p["expectedVersion"]=12
        with self.assertRaises(WorkspaceError):validate_plan(p,base)
