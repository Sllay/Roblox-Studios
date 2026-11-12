import sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from scene_sync import reconcile,sha,key_for
class SyncTests(unittest.TestCase):
    def test_external_not_deleted(self):
        d=reconcile({"records":{"a":1}},{"records":{"a":1,"new":2}})
        self.assertEqual(d["external"],[{"key":"new","change":"added"}])
        self.assertFalse(d["local"])
    def test_three_way(self):
        d=reconcile({"records":{"a":1,"b":1}},{"records":{"a":2,"b":1}},{"a":3,"b":2})
        self.assertEqual(d["conflicts"],["a"]);self.assertEqual(d["local"],["b"])
        self.assertEqual(reconcile({"records":{"a":1}},{"records":{"a":2}},{"a":2})["converged"],["a"])
    def test_identity(self):
        r={"managedId":"stable","service":"Workspace","path":[{"name":"A"}]}
        self.assertEqual(key_for(r),"managed:stable")
        r["managedId"]=""
        self.assertNotEqual(key_for(r),key_for({**r,"path":[{"name":"B"}]}))

    def test_stale_guard(self):
        from unittest.mock import patch
        from scene_sync import require_current,WorkspaceError
        import tempfile,json
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/"state.json"
            base={"universeId":"1","placeId":"2","loadedVersion":6,"records":{"a":1},"stateDigest":sha({"a":1})}
            path.write_text(json.dumps(base))
            with patch("scene_sync.state_path",return_value=path),patch("scene_sync.capture",return_value=base):
                self.assertEqual(require_current({},"key",6),base)
                with self.assertRaises(WorkspaceError):require_current({},"key",5)
            with patch("scene_sync.state_path",return_value=path),patch("scene_sync.capture",return_value={**base,"loadedVersion":7}):
                with self.assertRaises(WorkspaceError):require_current({},"key")
