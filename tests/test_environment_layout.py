import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from environment_layout import validate, read, SPEC, verify_layout
from workspace import WorkspaceError
class EnvironmentLayoutTests(unittest.TestCase):
    def test_plan(self):
        p=validate(read(SPEC))
        self.assertEqual(sum(a["count"] for a in p["assets"]),24)
        self.assertTrue(p["importAuthorized"] and all(a["importAuthorized"] and a["rightsStatus"]=="reviewed_platform_use" for a in p["assets"]))
    def test_incomplete_layout(self):
        with self.assertRaises(WorkspaceError):
            verify_layout(read(SPEC),[])

    def test_invalid_root(self):
        p=read(SPEC);p["rootName"]="Workspace"
        with self.assertRaises(WorkspaceError):validate(p)
