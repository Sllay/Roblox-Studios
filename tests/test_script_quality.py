import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("script_quality", ROOT / "tools" / "script_quality.py")
quality = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(quality)


class QualityTests(unittest.TestCase):
    def test_discovers_all_kinds_of_source(self):
        files = [p.relative_to(ROOT).as_posix() for p in quality.list_sources(ROOT)]
        self.assertIn("packages/roblox-common/src/Version.luau", files)
        self.assertIn("games/maps/_template/game/places/main/src/ServerScriptService/Boot.server.luau", files)
        self.assertIn("games/maps/mapa-principal/game/places/main/src/ServerScriptService/CloudFloatController.server.luau", files)
        self.assertIn("games/maps/mapa-principal/game/places/main/src/StarterPlayer/StarterPlayerScripts/CloudFloatClient.client.luau", files)

    def test_empty_source_not_silently_accepted(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "games/maps").mkdir(parents=True)
            (root / "packages").mkdir()
            with self.assertRaises(ValueError):
                quality.list_sources(root)

    def test_compiler_failure_blocks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            fake = root / "fake-compiler"
            fake.write_text(
                "#!/usr/bin/env python3\n"
                "import pathlib,sys\n"
                "assert sys.argv[1]=='--null'\n"
                "sys.exit(1 if 'BAD_CODE' in pathlib.Path(sys.argv[2]).read_text() else 0)\n"
            )
            fake.chmod(0o755)
            good = root / "good.luau"
            bad = root / "bad.luau"
            good.write_text("local value=1\n")
            bad.write_text("BAD_CODE\n")
            self.assertEqual(quality.check_sources([good, bad], str(fake), root), (1, 1))

    def test_missing_compiler_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            self.assertEqual(quality.main(["--compiler", str(Path(temp) / "missing")]), 2)


if __name__ == "__main__":
    unittest.main()
