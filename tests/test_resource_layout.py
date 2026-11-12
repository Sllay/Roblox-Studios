import unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from resource_layout import dimensions
from workspace import WorkspaceError
class ResourceTests(unittest.TestCase):
    def test_dimensions(self):
        scale,size=dimensions([184,133,175],1.2,0)
        self.assertAlmostEqual(size[0],1.2)
        self.assertLess(scale,.01)
        with self.assertRaises(WorkspaceError):dimensions([0,1,1],1,0)
    def test_horizontal_stick(self):
        _,size=dimensions([.2,4,.3],1.5,1)
        self.assertAlmostEqual(size[1],1.5)
