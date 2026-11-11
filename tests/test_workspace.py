import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("workspace", ROOT / "tools" / "workspace.py")
workspace = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(workspace)


class WorkspaceTests(unittest.TestCase):
    def test_demo_has_two_places(self):
        games = workspace.load_games()
        self.assertEqual({p["slug"] for p in games["sandbox-demo"]["places"]}, {"arena", "lobby"})

    def test_project_paths_resolve(self):
        games = workspace.load_games()
        for slug, game in games.items():
            for place in game["places"]:
                path = workspace.MAPS / slug / place["project"]
                self.assertTrue(path.is_file())

    def test_slug_rules(self):
        self.assertTrue(workspace.SLUG.fullmatch("my-new-game"))
        self.assertFalse(workspace.SLUG.fullmatch("../outside"))
        self.assertFalse(workspace.SLUG.fullmatch("MyGame"))

    def test_game_documents_present(self):
        for slug in workspace.load_games():
            for name in ("AGENTS.md", "GDD.md", "ARCHITECTURE.md"):
                self.assertTrue((workspace.MAPS / slug / name).is_file())


if __name__ == "__main__":
    unittest.main()
