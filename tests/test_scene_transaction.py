import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from scene_transaction import make_manifest,verify_manifest
from scene_sync import sha
from transaction_policy import inventory_budget,require_budget
from workspace import WorkspaceError
class TransactionTests(unittest.TestCase):
    def setUp(self):
        self.target={"environment":"staging","game":"mapa-principal","place":"main","universeId":"1","placeId":"2"}
        self.base={"universeId":"1","placeId":"2","loadedVersion":14,"records":{},"stateDigest":sha({}),"total":3385}
    def test_manifest_binds_source(self):
        p={"operations":[{"kind":"update_script"}]};ops=[{"kind":"update_script","source":"return 1"}]
        m=make_manifest(self.target,self.base,p,ops)
        verify_manifest(m,m)
        with self.assertRaises(WorkspaceError):verify_manifest(make_manifest(self.target,self.base,p,[{"kind":"update_script","source":"return 2"}]),m)
    def test_target_and_budget(self):
        with self.assertRaises(WorkspaceError):make_manifest({**self.target,"environment":"production"},self.base,{},[])
        self.base["total"]=4499
        with self.assertRaises(WorkspaceError):require_budget(self.base,[{"kind":"add_part"}])
        self.base["total"]=3385
        self.assertTrue(inventory_budget(self.base,[{"kind":"add_part"}])["allowed"])
