import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from capabilities import load
from scene_sync import compose_dispatch
from workspace import WorkspaceError
class CapabilityTests(unittest.TestCase):
    def test_registry(self):
        rows=load()
        self.assertGreaterEqual(len(rows),15)
        self.assertTrue(all(r["entry"] is None for r in rows if r["status"]=="planned"))
    def test_dispatch_contract(self):
        self.assertEqual(compose_dispatch("a\n-- __RS_SYNC_DISPATCH__\nb","do end"),"a\ndo end\nb")
        for bad in ("no marker","-- __RS_SYNC_DISPATCH__\n-- __RS_SYNC_DISPATCH__"):
            with self.assertRaises(WorkspaceError):compose_dispatch(bad,"do end")
