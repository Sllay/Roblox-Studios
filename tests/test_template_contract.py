import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "games" / "maps" / "_template"
SPEC = ROOT / "docs" / "architecture" / "GAME_TEMPLATE_ARCHITECTURE.md"


class TemplateContractTests(unittest.TestCase):
    def test_spec_contains_exact_current_source_of_all_runtime_files(self):
        text = SPEC.read_text(encoding="utf-8")
        source_paths = [
            TEMPLATE / "game.manifest.json",
            TEMPLATE / "deploy.targets.json",
            TEMPLATE / "game" / "places" / "main" / "default.project.json",
            TEMPLATE / "game" / "places" / "main" / "src" / "ReplicatedStorage" / "Config.luau",
            TEMPLATE / "game" / "places" / "main" / "src" / "ServerScriptService" / "Boot.server.luau",
            TEMPLATE / "game" / "places" / "main" / "src" / "StarterPlayer" / "StarterPlayerScripts" / "ClientBoot.client.luau",
            TEMPLATE / "game" / "places" / "main" / "src" / "Workspace" / "StartArea.model.json",
            ROOT / "packages" / "roblox-common" / "src" / "Version.luau"
        ]
        for path in source_paths:
            with self.subTest(path=path.relative_to(ROOT)):
                self.assertTrue(path.is_file(), f"Missing source: {path}")
                self.assertIn(path.read_text(encoding="utf-8").strip(), text,
                              f"Documentation out of sync with: {path}")

    def test_every_required_template_document_exists(self):
        for path in (
            "README.md", "AGENTS.md", "ARCHITECTURE.md", "GDD.md",
            "game.manifest.json", "deploy.targets.json",
            "agents/README.md", "agents/WORKFLOW.md",
            "docs/README.md", "game/assets/README.md", "game/tests/README.md"
        ):
            with self.subTest(path=path):
                self.assertTrue((TEMPLATE / path).is_file())


if __name__ == "__main__":
    unittest.main()
