import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("asset_catalog", ROOT / "tools" / "assets" / "catalog.py")
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)


class AssetCatalogTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        game_dir = self.root / "games/maps/test-game"
        (game_dir / "game/assets").mkdir(parents=True)
        (game_dir / "game.manifest.json").write_text('{"slug":"test-game"}')
        (game_dir / "game/assets/catalog.json").write_text('{"schemaVersion":1,"assets":[]}')
        self.candidates = self.root / "candidates.json"
        self.candidates.write_text(json.dumps({
            "schemaVersion": 1, "game": "test-game",
            "candidates": [{"id": "123", "name": "Tree", "creator": "Artist",
                            "status": "candidate_unreviewed"}]
        }))
        self.catalog_file = game_dir / "game/assets/catalog.json"

    def tearDown(self):
        self.tmp.cleanup()

    def test_shortlist_is_never_import_or_safety_approval(self):
        catalog.shortlist(self.root, "test-game", self.candidates, "123", "praia", "palmeira costeira")
        item = json.loads(self.catalog_file.read_text())["assets"][0]
        self.assertEqual(item["reviewStatus"], "visual_shortlisted")
        self.assertEqual(item["securityStatus"], "not_inspected")
        self.assertEqual(item["importStatus"], "not_imported")
        with self.assertRaises(catalog.CatalogError):
            catalog.shortlist(self.root, "test-game", self.candidates, "123", "praia", "duplicate")

    def test_reject_wrong_game_or_asset(self):
        with self.assertRaises(catalog.CatalogError):
            catalog.shortlist(self.root, "wrong-game", self.candidates, "123", "praia", "test")
        with self.assertRaises(catalog.CatalogError):
            catalog.shortlist(self.root, "test-game", self.candidates, "456", "praia", "test")


if __name__ == "__main__":
    unittest.main()
