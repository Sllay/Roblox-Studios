import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
SPEC = importlib.util.spec_from_file_location("cloud_smoke", ROOT / "tools" / "cloud_smoke.py")
smoke = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(smoke)


class CloudSmokeTests(unittest.TestCase):
    def test_identity_checks_both_ids(self):
        value = smoke.identity_script("10769712453", "118200154785968")
        self.assertIn('game.GameId', value)
        self.assertIn('game.PlaceId', value)
        self.assertIn('assert(object:GetAttribute("SmokeOwner")', value)

    def test_script_embedding_preserves_source(self):
        for sample in ('hello', 'a]=]b', 'a"]]==]"b', 'line1\nline2'):
            with self.subTest(sample=sample):
                encoded = smoke.long_literal(sample)
                opening = encoded.index('[' , 1) + 1
                closing = encoded.rfind(']')
                self.assertIn(sample, encoded)
                self.assertTrue(len(encoded) > len(sample))

    def test_apply_never_replaces_entire_place(self):
        s = smoke.apply_script("10769712453", "118200154785968",
                               smoke.SERVER_FILE.read_text(encoding="utf-8"),
                               smoke.CLIENT_FILE.read_text(encoding="utf-8"))
        self.assertIn("SavePlaceAsync", s)
        self.assertIn("serverScript.Source", s)
        self.assertIn("localScript.Source", s)
        self.assertIn("FloatingPlatform", s)
        self.assertNotIn("Destroy()", s)
        self.assertNotIn("require(0", s)

    def test_verification_is_read_only(self):
        s = smoke.verification_script("10769712453", "118200154785968")
        self.assertIn("VERIFIED_PERSISTED", s)
        self.assertNotIn("SavePlaceAsync", s)

    def test_local_dry_run_does_not_require_key(self):
        self.assertEqual(smoke.main([]), 0)


if __name__ == "__main__":
    unittest.main()
