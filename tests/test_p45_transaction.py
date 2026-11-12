import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from p45_transaction import equal,scope,dispatch
from workspace import WorkspaceError
class P45TransactionTests(unittest.TestCase):
    def test_composition(self):
        s=dispatch()
        self.assertNotIn("-- __RS_ROCK_HELPERS__",s)
        self.assertNotIn("-- __RS_STICK_HELPER__",s)
        self.assertEqual(s.count("SavePlaceAsync("),1)
    def test_compare(self):
        self.assertTrue(equal({"x":[1,2.001]},{"x":[1,2]}))
        self.assertFalse(equal({"x":[1,2.02]},{"x":[1,2]}))
        self.assertFalse(equal(True,1))
    def test_scope_rejects_unrelated(self):
        base={"records":{"terrain:x":{"digest":"abc"}}}
        with self.assertRaises(WorkspaceError):scope(base,{"records":{"terrain:x":{"digest":"def"}}},{"resources":[],"bushMoves":[],"colliders":[]})
