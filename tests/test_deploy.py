import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("deploy", ROOT / "tools" / "deploy.py")
import sys
sys.path.insert(0, str(ROOT / "tools"))
deploy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(deploy)


class DeployTests(unittest.TestCase):
    def test_all_configs_validate(self):
        games, targets = deploy.load_all()
        self.assertIn("sandbox-demo", games)
        self.assertEqual(set(targets["sandbox-demo"]["environments"]), {"staging", "production"})

    def test_missing_ids_prevent_publication(self):
        games, targets = deploy.load_all()
        with self.assertRaisesRegex(deploy.WorkspaceError, "not configured"):
            deploy.resolve(games, targets, "sandbox-demo", "lobby", "staging")

    def test_id_validation(self):
        self.assertEqual(deploy.normalized_id("12345", "test"), "12345")
        self.assertEqual(deploy.normalized_id(12345, "test"), "12345")
        self.assertIsNone(deploy.normalized_id(None, "test"))
        for invalid in (0, -2, True, 1.3, "00", "123abc", "../../secret"):
            with self.subTest(value=invalid), self.assertRaises(deploy.WorkspaceError):
                deploy.normalized_id(invalid, "test")

    def test_reject_duplicate_place_ids_and_universe(self):
        games, original = deploy.load_all()
        config = json.loads(json.dumps(original["sandbox-demo"]))
        config["environments"]["staging"]["universeId"] = "12345"
        config["environments"]["staging"]["placeIds"]["lobby"] = "7777"
        config["environments"]["staging"]["placeIds"]["arena"] = "7777"
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            (path / "sandbox-demo").mkdir()
            (path / "sandbox-demo" / "deploy.targets.json").write_text(json.dumps(config), encoding="utf-8")
            base = deploy.MAPS
            try:
                deploy.MAPS = path
                with self.assertRaisesRegex(deploy.WorkspaceError, "duplicate Place ID"):
                    deploy.load_targets("sandbox-demo", games["sandbox-demo"])
            finally:
                deploy.MAPS = base

    def test_multipart_body_contains_required_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "test.rbxlx"
            file.write_bytes(b"<roblox></roblox>")
            content_type, payload = deploy.multipart_place_file("12345", file)
            self.assertTrue(content_type.startswith("multipart/form-data; boundary="))
            self.assertIn(b'"assetId": 12345', payload)
            self.assertIn(b'"assetType": "Place"', payload)
            self.assertIn(b'"published": true', payload)
            self.assertIn(b"<roblox></roblox>", payload)


if __name__ == "__main__":
    unittest.main()
