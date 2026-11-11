import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("scaffold", ROOT / "tools" / "scaffold.py")
scaffold = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scaffold)

class ScaffoldTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.maps = Path(self.temp.name) / "maps"
        self.maps.mkdir()
        shutil.copytree(ROOT / "games" / "maps" / "_template", self.maps / "_template")

    def tearDown(self):
        self.temp.cleanup()

    def test_new_game(self):
        path = scaffold.new_game(self.maps, "sample-game", "Sample Game")
        self.assertEqual(json.loads((path / "game.manifest.json").read_text())["slug"], "sample-game")
        self.assertIsNone(json.loads((path / "deploy.targets.json").read_text())["environments"]["production"]["universeId"])
        place = path / "game" / "places" / "main"
        self.assertEqual(json.loads((place / "default.project.json").read_text())["name"], "sample_game_main")
        self.assertIn("sample_game_main", (place / "src" / "ServerScriptService" / "Boot.server.luau").read_text())

    def test_new_place(self):
        path = scaffold.new_game(self.maps, "sample-game", "Sample Game")
        scaffold.add_place(self.maps, "sample-game", "boss-arena")
        manifest = json.loads((path / "game.manifest.json").read_text())
        targets = json.loads((path / "deploy.targets.json").read_text())
        self.assertEqual([p["slug"] for p in manifest["places"]], ["main", "boss-arena"])
        self.assertIsNone(targets["environments"]["staging"]["placeIds"]["boss-arena"])
        self.assertIsNone(targets["environments"]["production"]["placeIds"]["boss-arena"])
        self.assertTrue((path / "game" / "places" / "boss-arena" / "default.project.json").is_file())

    def test_id_safety(self):
        path = scaffold.new_game(self.maps, "sample-game", "Sample Game")
        scaffold.add_place(self.maps, "sample-game", "boss-arena")
        scaffold.set_ids(self.maps, "sample-game", "main", "production", "1234", "5678")
        scaffold.set_ids(self.maps, "sample-game", "boss-arena", "production", "1234", "5679")
        with self.assertRaises(scaffold.ScaffoldError):
            scaffold.set_ids(self.maps, "sample-game", "main", "staging", "1234", "5680")
        with self.assertRaises(scaffold.ScaffoldError):
            scaffold.set_ids(self.maps, "sample-game", "boss-arena", "staging", "9999", "5678")
        with self.assertRaises(scaffold.ScaffoldError):
            scaffold.set_ids(self.maps, "sample-game", "main", "production", "9999", "5678")
        self.assertEqual(json.loads((path / "deploy.targets.json").read_text())["environments"]["production"]["placeIds"]["main"], "5678")

    def test_reject_overwrite_and_unsafe_slug(self):
        for invalid in ("../unsafe", "MyGame", "_template", "bad space"):
            with self.subTest(invalid=invalid), self.assertRaises(scaffold.ScaffoldError):
                scaffold.new_game(self.maps, invalid, "Bad")
        scaffold.new_game(self.maps, "existing-game", "Existing")
        with self.assertRaises(scaffold.ScaffoldError):
            scaffold.new_game(self.maps, "existing-game", "Replace")
        with self.assertRaises(scaffold.ScaffoldError):
            scaffold.add_place(self.maps, "existing-game", "main")

    def test_bad_ids(self):
        scaffold.new_game(self.maps, "sample-game", "Sample Game")
        for bad in ("0", "-1", "abc", "01", "../2"):
            with self.subTest(bad=bad), self.assertRaises(scaffold.ScaffoldError):
                scaffold.set_ids(self.maps, "sample-game", "main", "production", bad, "123")

if __name__ == "__main__":
    unittest.main()
