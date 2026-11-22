"""Regression tests for Entre Reinos Rojo wiring; no Roblox runtime is simulated."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "games/maps/entre-reinos"
SRC = GAME / "game/places/main/src"

class EntreReinosWiring(unittest.TestCase):
    def test_rojo_maps_real_script_roots(self):
        project = json.loads((GAME/"game/places/main/default.project.json").read_text(encoding="utf8"))
        tree = project["tree"]
        self.assertEqual(tree["ServerScriptService"]["$path"], "src/ServerScriptService")
        self.assertEqual(tree["StarterPlayer"]["StarterPlayerScripts"]["$path"],
                         "src/StarterPlayer/StarterPlayerScripts")
        self.assertEqual(tree["ReplicatedStorage"]["Game"]["$path"], "src/ReplicatedStorage")

    def test_server_requires_live_service_paths(self):
        server = SRC/"ServerScriptService"
        boot = (server/"Boot.server.luau").read_text(encoding="utf8")
        for name in ("WorldService", "SaveSlotService"):
            path = server/"Services"/f"{name}.luau"
            self.assertTrue(path.is_file(), str(path))
            self.assertIn(f'WaitForChild("{name}")', boot)
        self.assertFalse((SRC/"game/places/main/src/ServerScriptService/Services/WorldService.luau").exists(),
                         "A repeated src/game/places/main/src prefix silently breaks Roblox require")

    def test_client_scripts_have_real_targets(self):
        client = SRC/"StarterPlayer/StarterPlayerScripts"
        entry = (client/"ClientBoot.client.luau").read_text(encoding="utf8")
        for name in ("LaneController", "SideCamera", "SlotMenu"):
            self.assertTrue((client/f"{name}.luau").is_file())
            self.assertIn(f'WaitForChild("{name}")', entry)
        for name in ("WorldProfile", "SlotModel", "SlotLeasePolicy"):
            self.assertTrue((SRC/"ReplicatedStorage"/f"{name}.luau").is_file())

    def test_world_never_clears_unmanaged_terrain(self):
        service = (SRC/"ServerScriptService/Services/WorldService.luau").read_text(encoding="utf8")
        executable = " ".join(line.split("--", 1)[0] for line in service.splitlines())
        self.assertNotIn("Terrain:Clear(", executable)
        self.assertIn("ReadVoxelChannels", service)
        self.assertIn("WriteVoxelChannels", service)
        self.assertIn("nonempty_terrain_refuses_overwrite", service)

    def test_save_is_server_authoritative_and_atomic(self):
        service = (SRC/"ServerScriptService/Services/SaveSlotService.luau").read_text(encoding="utf8")
        self.assertIn("UpdateAsync(", service)
        self.assertIn("Policy.writeDecision", service)
        self.assertIn("abortActivation", service)
        self.assertNotIn("SetAsync(", service)
        self.assertNotIn("RemoveAsync(", service)

if __name__ == "__main__":
    unittest.main()
