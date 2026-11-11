import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("assets_discovery", ROOT / "tools/assets/discover.py")
discovery = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(discovery)


class AssetDiscoveryTests(unittest.TestCase):
    def test_no_external_thumbnails(self):
        self.assertFalse(discovery.check_thumbnail_url("http://tr.rbxcdn.com/image"))
        self.assertFalse(discovery.check_thumbnail_url("https://rbxcdn.com.evil.test/x"))
        self.assertFalse(discovery.check_thumbnail_url("https://user@tr.rbxcdn.com/x"))
        self.assertTrue(discovery.check_thumbnail_url("https://tr.rbxcdn.com/123"))

    def test_search_normalization_and_no_auto_approval(self):
        result = {"creatorStoreAssets": [
            {"asset": {"id": 123, "name": "<Tree>", "categoryPath": "3d__foliage"},
             "creator": {"name": "Artist & Co", "verified": False}},
            {"asset": {"id": 123, "name": "Duplicate"}},
            {"asset": {"id": "bad", "name": "Malformed"}}
        ]}
        with patch.object(discovery, "fetch_json", return_value=result) as mock:
            items = discovery.search_models("tropical tree", 5)
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["id"], "123")
        self.assertEqual(items[0]["status"], "candidate_unreviewed")
        url = mock.call_args.args[0]
        self.assertIn("searchCategoryType=Model", url)

    def test_artifacts_escape_untrusted_asset_names(self):
        items = [{"id": "123", "name": "<script>alert(1)</script>", "creator": "<bad>",
                  "status": "candidate_unreviewed", "url": "https://create.roblox.com/store/asset/123",
                  "thumbnail": None, "localThumbnail": None}]
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            with patch.object(discovery, "thumbnails", return_value={"123":"https://tr.rbxcdn.com/abc"}):
                with patch.object(discovery, "download_thumbnail", return_value=Image.new("RGB", (120, 120), "green")):
                    discovery.render(output, items, game="mapa-principal", query="tropical", biome="praia")
            self.assertTrue((output / "gallery.html").is_file())
            self.assertTrue((output / "contact-sheet.png").is_file())
            self.assertTrue((output / "thumbs/123.png").is_file())
            self.assertIn("&lt;script&gt;", (output / "gallery.html").read_text())
            self.assertNotIn("<script>alert(1)</script>", (output / "gallery.html").read_text())
            self.assertFalse(json.loads((output / "candidates.json").read_text())["automaticApproval"])

    def test_empty_results_fail_closed(self):
        with patch.object(discovery, "fetch_json", return_value={"creatorStoreAssets": []}):
            with self.assertRaises(discovery.DiscoveryError):
                discovery.search_models("invalid search", 8)


if __name__ == "__main__":
    unittest.main()
