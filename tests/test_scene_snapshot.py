import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from scene_snapshot import snapshot,compare,WorkspaceError

class SnapshotTests(unittest.TestCase):
    def data(self,rows,version=2):
        return dict(schemaVersion=1,universeId="1",placeId="2",loadedVersion=version,objects=rows,truncated=False)
    def test_order_independent_and_duplicate_preserved(self):
        a={"path":"A","class":"Part"}; b={"path":"B","class":"Model"}
        self.assertTrue(compare(self.data([a,b]),self.data([b,a],3))["sameStructure"])
        self.assertEqual(compare(self.data([a]),self.data([a,a],3))["added"],[a])
    def test_truncated_and_wrong_target_rejected(self):
        d=self.data([]);d["truncated"]=True
        with self.assertRaises(WorkspaceError): snapshot(d)
        d=self.data([]);d["placeId"]="3"
        with self.assertRaises(WorkspaceError): compare(self.data([]),d)
    def test_changed_geometry(self):
        a=self.data([{"path":"A","size":[1,1,1]}])
        b=self.data([{"path":"A","size":[2,1,1]}],3)
        self.assertFalse(compare(a,b)["sameStructure"])
