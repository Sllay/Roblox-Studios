import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class PropTests(unittest.TestCase):
    def test_no_terrain_write(self):
        s=(ROOT/"tools/sync/prop_reconcile.luau").read_text()
        self.assertNotIn("WriteVoxel",s)
        self.assertIn('cfg.intent=="sculpt"',s)
        self.assertIn('counts.review==0 and counts.unmanaged==0',s)
        self.assertIn("moveSupported(o.model,o.collider",s)
    def test_paint_preserves_transforms(self):
        s=(ROOT/"tools/terrain_paint.py").read_text()
        self.assertIn("Paint moved object",s)
