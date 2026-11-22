"""Regression gates for Entre Reinos Rojo lobby/reserved-world architecture.

These tests inspect real source and deployment paths, not a fake Roblox runtime.
The pure Luau routing/seed/slot assertions are executed separately in GitHub CI.
"""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "games/maps/entre-reinos"
SRC = GAME / "game/places/main/src"


def read(relative: str) -> str:
    return (SRC / relative).read_text(encoding="utf8")


class EntreReinosWiring(unittest.TestCase):
    def test_rojo_mounts_actual_scripts(self):
        tree = json.loads((GAME / "game/places/main/default.project.json").read_text())["tree"]
        self.assertEqual(tree["ServerScriptService"]["$path"], "src/ServerScriptService")
        self.assertEqual(tree["StarterPlayer"]["StarterPlayerScripts"]["$path"],
                         "src/StarterPlayer/StarterPlayerScripts")
        self.assertEqual(tree["ReplicatedStorage"]["Game"]["$path"], "src/ReplicatedStorage")
        self.assertFalse((SRC/"game/places/main/src").exists(), "duplicate Rojo source root")

    def test_server_and_client_require_all_live_modules(self):
        boot = read("ServerScriptService/Boot.server.luau")
        client = read("StarterPlayer/StarterPlayerScripts/ClientBoot.client.luau")
        for name in ("WorldService", "SaveSlotService", "CharacterService"):
            self.assertTrue((SRC/"ServerScriptService/Services"/f"{name}.luau").is_file())
            self.assertIn(f'WaitForChild("{name}")', boot)
        for name in ("WorldProfile", "WorldRoute", "SlotModel", "SlotLeasePolicy"):
            self.assertTrue((SRC/"ReplicatedStorage"/f"{name}.luau").is_file())
            self.assertIn(f'WaitForChild("{name}")', boot if name != "SlotLeasePolicy"
                          else read("ServerScriptService/Services/SaveSlotService.luau"))
        for name in ("LaneController", "SideCamera", "SlotMenu", "WorldLoadingUI"):
            self.assertTrue((SRC/"StarterPlayer/StarterPlayerScripts"/f"{name}.luau").is_file())
            self.assertIn(f'WaitForChild("{name}")', client)

    def test_lobby_never_generates_or_opens_world(self):
        boot = read("ServerScriptService/Boot.server.luau")
        self.assertIn("local worldServer = Route.isWorldServer(", boot)
        self.assertIn('if worldServer then', boot)
        self.assertIn("Saves.createDetached(player, index)", boot)
        self.assertIn("Saves.inspect(player, index)", boot)
        self.assertIn("local ok: boolean", boot)
        self.assertIn("local record: any", boot)
        self.assertNotIn("local success, record = if", boot)
        self.assertNotIn("local ok, record = if", boot)
        self.assertIn("Saves.open, player, index", boot)
        self.assertIn("World.activate,", boot)

    def test_each_world_gets_its_own_reserved_server(self):
        boot = read("ServerScriptService/Boot.server.luau")
        route = read("ReplicatedStorage/WorldRoute.luau")
        self.assertIn("options.ReservedServerId = id", boot)
        self.assertIn("TeleportService:TeleportAsync(game.PlaceId, {player}, options)", boot)
        self.assertIn("Route.validArrival(ticket, player.UserId", boot)
        self.assertIn("ticket.reservedId == privateServerId", route)
        self.assertIn("ticket.ownerUserId == userId", route)
        self.assertIn("ticket.sourcePlaceId == placeId", route)
        self.assertIn("Saves.open, player, index", boot)
        self.assertNotIn("ReserveServerAsync(", boot)
        self.assertNotIn("ShouldReserveServer =", boot)

    def test_single_player_is_enforced_without_changing_read_only_maxplayers(self):
        boot = read("ServerScriptService/Boot.server.luau")
        self.assertIn("#Players:GetPlayers() > 1", boot)
        self.assertIn("player:Kick(", boot)
        self.assertNotIn("Players.MaxPlayers =", boot)
        self.assertIn('action == "return"', boot)
        self.assertIn("options.ForcePublicServer = true", boot)

    def test_initial_chunk_streaming_and_seed_preservation(self):
        world = read("ServerScriptService/Services/WorldService.luau")
        profile = read("ReplicatedStorage/WorldProfile.luau")
        boot = read("ServerScriptService/Boot.server.luau")
        self.assertIn("WorldProfile.CHUNK_STUDS = 64", profile)
        self.assertIn("WorldProfile.CHUNK_COUNT = 4", profile)
        self.assertIn("WorldProfile.INITIAL_CHUNKS = {2, 3, 4}", profile)
        self.assertIn("for order, id in ipairs(Profile.INITIAL_CHUNKS)", world)
        self.assertIn("function World.ensureNear(seed: number, x: number)", world)
        self.assertIn("World.ensureNear(record.seed, root.Position.X)", boot)
        self.assertIn("ReadVoxelChannels(", world)
        self.assertIn("WriteVoxelChannels(", world)
        self.assertIn("nonempty_terrain_refuses_overwrite", world)
        self.assertNotIn("Terrain:Clear(", "\n".join(
            line.split("--", 1)[0] for line in world.splitlines()))

    def test_different_server_owns_the_slot_lease(self):
        saves = read("ServerScriptService/Services/SaveSlotService.luau")
        boot = read("ServerScriptService/Boot.server.luau")
        self.assertIn("function SaveSlotService.createDetached(", saves)
        self.assertIn("function SaveSlotService.inspect(", saves)
        self.assertIn("record.lastWriteId = token .. \":create_detached\"", saves)
        self.assertIn("s.lastClock = now", saves)
        self.assertIn('player:GetAttribute("ER_WorldLoaded") ~= true', saves)
        self.assertIn("DataStoreService:GetDataStore(", saves)
        self.assertIn("UpdateAsync(", saves)
        self.assertNotIn("SetAsync(", saves)
        self.assertNotIn("RemoveAsync(", saves)
        self.assertIn("Saves.createDetached(player, index)", boot)
        self.assertIn("Saves.open, player, index", boot)
        self.assertIn("player.UserId", saves)

    def test_opaque_lobby_and_real_progress_loading(self):
        lobby = read("StarterPlayer/StarterPlayerScripts/SlotMenu.luau")
        loading = read("StarterPlayer/StarterPlayerScripts/WorldLoadingUI.luau")
        client = read("StarterPlayer/StarterPlayerScripts/ClientBoot.client.luau")
        self.assertIn("overlay.BackgroundTransparency = 0", lobby)
        self.assertIn("transit.BackgroundTransparency = 0", lobby)
        self.assertIn("shade.BackgroundTransparency = 0", loading)
        self.assertIn('player:GetAttribute("ER_LoadProgress")', loading)
        self.assertIn('player:GetAttribute("ER_LoadStage")', loading)
        self.assertIn('player:GetAttribute("ER_WorldLoaded") == true', loading)
        self.assertIn('mode == "world"', client)
        self.assertIn("Loading.start(player, slots,", client)
        self.assertIn("Menu.start(slots,", client)
        self.assertIn('startTransfer(index, not summary.exists)', lobby)

    def test_no_client_authoritative_teleport_or_save(self):
        client = read("StarterPlayer/StarterPlayerScripts/ClientBoot.client.luau")
        loading = read("StarterPlayer/StarterPlayerScripts/WorldLoadingUI.luau")
        lobby = read("StarterPlayer/StarterPlayerScripts/SlotMenu.luau")
        self.assertNotIn("TeleportAsync(", client+loading+lobby)
        self.assertNotIn("UpdateAsync(", client+loading+lobby)
        self.assertIn('remote:InvokeServer("return")', loading)

    def test_native_mobile_joystick_and_original_jump_not_replaced(self):
        lane = read("StarterPlayer/StarterPlayerScripts/LaneController.luau")
        pure = read("ReplicatedStorage/InputProjection.luau")
        self.assertIn('controls:GetMoveVector()', lane)
        self.assertIn('Projection.toLane(vector.X, vector.Z)', lane)
        self.assertIn('h:Move(Vector3.new(x, 0, 0), false)', lane)
        self.assertIn('h:Move(Vector3.zero, false)', lane)
        self.assertIn('Projection.facing(x, y, swimming, lastFacing)', lane)
        self.assertIn('RunService:BindToRenderStep("ER_Lane"', lane)
        self.assertNotIn('ContextActionService', lane)
        self.assertNotIn('BindActionAtPriority(', lane)
        self.assertNotIn('SetPosition(', lane)
        self.assertNotIn('SetTitle(', lane)
        self.assertNotIn('true, 2200', lane)
        self.assertNotIn('controls:Disable()\n', lane.replace('-- NEVER call controls:Disable():', ''))
        self.assertNotIn('Humanoid.Jump =', lane)
        self.assertNotIn('h.Jump =', lane)
        self.assertIn('math.clamp(-z, -1, 1)', pure)

    def test_debug_panel_respects_coreui_safe_area_and_native_controls(self):
        client = read("StarterPlayer/StarterPlayerScripts/ClientBoot.client.luau")
        self.assertIn('gui.IgnoreGuiInset = false', client)
        self.assertIn('gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets', client)
        self.assertIn('stats.AnchorPoint = Vector2.new(1, 0)', client)
        self.assertIn('stats.Position = UDim2.new(1, -12, 0, 10)', client)
        self.assertNotIn('stats.Position = UDim2.fromOffset(12, 16)', client)
        self.assertNotIn('gui.IgnoreGuiInset = true', client)

    def test_r1_native_r6_animation_controller_preserved(self):
        service = read("ServerScriptService/Services/CharacterService.luau")
        lane = read("StarterPlayer/StarterPlayerScripts/LaneController.luau")
        self.assertIn('old:FindFirstChild("Animate")', service)
        self.assertIn('animateSource:Clone()', service)
        self.assertIn('animate.Parent = model', service)
        self.assertIn('Enum.HumanoidStateType.Swimming', lane)
        self.assertNotIn('Humanoid.RigType =', service)
        self.assertNotIn('h.Jump =', lane)

    def test_r2_live_npc_construction_is_server_only_and_saved(self):
        boot = read("ServerScriptService/Boot.server.luau")
        living = read("ServerScriptService/Services/LivingService.luau")
        saves = read("ServerScriptService/Services/SaveSlotService.luau")
        slots = read("ReplicatedStorage/SlotModel.luau")
        client = read("StarterPlayer/StarterPlayerScripts/ClientBoot.client.luau")
        for name in ("LivingModel", "Inventory", "ItemDefs", "ProfessionDefs",
                     "StructureDefs", "WorkEngine"):
            self.assertTrue((SRC/"ReplicatedStorage/Living"/(name+".luau")).is_file())
        self.assertIn('WaitForChild("LivingService")', boot)
        self.assertIn('pcall(LivingService.start,', boot)
        self.assertIn('LivingService.snapshot(player)', boot)
        self.assertIn('Saves.setLivingProvider(function(player: Player)', boot)
        self.assertIn('if worldServer then', boot)
        self.assertIn('LivingService.stop(player)', boot)
        self.assertIn('s.data.living = LivingModel.clone(state)', saves)
        self.assertIn('if data.living ~= nil and not Living.valid(data.living)', slots)
        self.assertIn('actions.OnServerInvoke=function(player: Player,action: any,typeId: any)', living)
        self.assertIn('owner~=player', living)
        self.assertIn('Work.place(state,typeId,x)', living)
        self.assertIn('RunService.Heartbeat:Connect', living)
        self.assertIn('Players:CreateHumanoidModelFromDescriptionAsync(', living)
        self.assertIn('BuildMenu.start(player)', client)

    def test_r2_no_client_minting_no_future_economy(self):
        menu = read("StarterPlayer/StarterPlayerScripts/BuildMenu.luau")
        engine = read("ReplicatedStorage/Living/WorkEngine.luau")
        inventory = read("ReplicatedStorage/Living/Inventory.luau")
        self.assertIn('remote:InvokeServer(action,arg)', menu)
        self.assertNotIn('DataStoreService', menu)
        self.assertNotIn('UpdateAsync(', menu)
        self.assertIn('site.remaining-=n', engine)
        self.assertIn('Inventory.add(npc.inventory,item,n)', engine)
        self.assertIn('Inventory.take(npc.inventory,item,n)', engine)
        self.assertIn('b.delivered[item]', engine)
        self.assertIn('claimed', engine)
        self.assertIn('function Inv.transfer(source: any, dest: any, id: string, amount: number)', inventory)
        self.assertNotIn('currency', engine.lower())
        self.assertNotIn('portal', engine.lower())

    def test_user_production_target_is_unset(self):
        targets = json.loads((GAME / "deploy.targets.json").read_text())["environments"]
        self.assertEqual(str(targets["staging"]["universeId"]), "10769712413")
        self.assertEqual(str(targets["staging"]["placeIds"]["main"]), "90623742498445")
        self.assertIsNone(targets["production"]["universeId"])
        self.assertIsNone(targets["production"]["placeIds"]["main"])


if __name__ == "__main__":
    unittest.main()
