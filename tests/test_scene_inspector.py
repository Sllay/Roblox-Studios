import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
SPEC = importlib.util.spec_from_file_location("scene_inspector", ROOT / "tools/scene_inspector.py")
inspector = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(inspector)


class SceneInspectorTests(unittest.TestCase):
    def setUp(self):
        self.scene = {
            "schemaVersion":1, "universeId":"10769712453", "placeId":"118200154785968",
            "objects":[{"name":"Floor", "path":"Demo/Floor", "position":[0,0,0],
                        "size":[24,1,24], "color":[15, 80, 100], "biome":"unclassified"}],
            "stats":{"sampledParts":1,"totalPartsScanned":1,"scanTruncated":False,"objectsTruncated":False}
        }

    def test_read_only_contract(self):
        source = inspector.LUAU.read_text(encoding="utf-8")
        self.assertNotIn("SavePlaceAsync(", source)
        self.assertNotIn("Instance.new(", source)
        self.assertIn("GetDescendants()", source)
        self.assertIn("JSONEncode(payload)", source)

    def test_outputs_map_json_and_report(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)
            inspector.render_report(self.scene, path)
            self.assertTrue((path/"scene.json").exists())
            self.assertTrue((path/"scene-map.png").exists())
            self.assertIn("NOT a Roblox screenshot", (path/"report.md").read_text())
            self.assertEqual(json.loads((path/"scene.json").read_text())["placeId"], "118200154785968")

    def test_malformed_objects_skipped(self):
        data = dict(self.scene)
        data["objects"] = [{"position":[1,2], "size":[1,2,3], "color":[2,3,4]}]
        self.assertEqual(inspector.safe_objects(data), [])


if __name__ == "__main__":
    unittest.main()
