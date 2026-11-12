import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from environment_layout import dispatch
from scene_sync import compose_dispatch,SOURCE
class SurfaceIntegrationTests(unittest.TestCase):
    def test_composed_layout(self):
        s=compose_dispatch(SOURCE.read_text(),dispatch())
        self.assertIn("local Surface=(function()",s)
        self.assertIn("Surface.support(tile,x,z,support)",s)
        self.assertNotIn("-- __RS_SURFACE_FIELDS__",s)
        self.assertNotIn("-- __RS_ASSET_HELPERS__",s)
