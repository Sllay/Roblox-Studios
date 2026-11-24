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
        self.assertIn("s.lastClock = capturedAt", saves)
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
        self.assertIn('h:Move(Vector3.new(x, if swimming then y else 0, 0), false)', lane)
        self.assertNotIn('h:Move(Vector3.zero, false)', lane)
        self.assertNotIn('LinearVelocity', lane.split('local function update')[0])
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
        self.assertIn('record.living = LivingModel.clone(state)', saves)
        self.assertIn('not Living.valid(data.living) or data.living.seed ~= data.seed', slots)
        self.assertIn('actions.OnServerInvoke=function(player: Player,action: any,arg: any,candidateX: any)', living)
        self.assertIn('owner~=player', living)
        self.assertIn('Work.canPlace(state,typeId,x)', living)
        self.assertIn('Work.place(state,plan.typeId,plan.x,height)', living)
        self.assertIn('local function actorX(npc: any)', living)
        self.assertIn('RunService.Heartbeat:Connect', living)
        self.assertIn('Players:CreateHumanoidModelFromDescriptionAsync(', living)
        self.assertIn('R3HUD.start(player)', client)
        self.assertNotIn('BuildMenu.start(player)', client)

    def test_t1_f1_manual_build_preview_and_confirmation(self):
        engine = read("ReplicatedStorage/Living/WorkEngine.luau")
        living = read("ServerScriptService/Services/LivingService.luau")
        ui = read("StarterPlayer/StarterPlayerScripts/BuildMenu.luau")
        pure = (GAME / "game/tests/living_work_r2.luau").read_text()
        self.assertIn('local valid,reason=Engine.canPlace(state,typeId,x)', engine)
        self.assertIn('sample.wet or sample.shore', engine)
        self.assertIn('no_worker_route', engine)
        self.assertIn('local available,height=placementGround(plan.typeId,plan.x,root)', living)
        self.assertIn('local placed,result=Work.place(state,plan.typeId,plan.x,height)', living)
        self.assertIn('return buildPreview.result', living)
        self.assertIn('call("build_preview",id,candidate)', ui)
        self.assertIn('call("build",previewId)', ui)
        self.assertIn('if busy then return end', ui)
        self.assertIn('ENTRE_REINOS_T1_F1_PLACEMENT:', pure)
        self.assertIn('ENTRE_REINOS_T1_F1_CANCEL:', pure)

    def test_r2_no_client_minting_no_future_economy(self):
        menu = read("StarterPlayer/StarterPlayerScripts/BuildMenu.luau")
        engine = read("ReplicatedStorage/Living/WorkEngine.luau")
        inventory = read("ReplicatedStorage/Living/Inventory.luau")
        self.assertIn('call("build",previewId)', menu)
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

    def test_v9_r6_npc_feet_ray_and_client_per_frame_visual_smoothing(self):
        living = read("ServerScriptService/Services/LivingService.luau")
        visual = read("StarterPlayer/StarterPlayerScripts/NPCPresentation.luau")
        client = read("StarterPlayer/StarterPlayerScripts/ClientBoot.client.luau")
        self.assertIn('local function pivotToFoot(model: Model)', living)
        self.assertIn('left', living.lower())
        self.assertIn('groundCast.FilterDescendantsInstances={workspace.Terrain}', living)
        self.assertIn('model:SetAttribute("ER_FeetOffset",feetOffset)', living)
        self.assertIn('model:SetAttribute("ER_NPCPose",target)', living)
        self.assertIn('model:SetAttribute("ER_NPCVelocityX",vx)', living)
        self.assertNotIn('model:PivotTo(desired)', living)
        self.assertIn('RunService:BindToRenderStep("ER_NPCPresentation"', visual)
        self.assertIn('model:PivotTo(item.render)', visual)
        self.assertIn("animator:LoadAnimation(animation)", visual)
        self.assertNotIn(".Transform=", visual)
        self.assertIn('NPCPresentation.start()', client)

    def test_v9_minimal_3d_world_text_and_water_state_separation(self):
        living = read("ServerScriptService/Services/LivingService.luau")
        lane = read("StarterPlayer/StarterPlayerScripts/LaneController.luau")
        npc = read("StarterPlayer/StarterPlayerScripts/NPCPresentation.luau")
        work = read("ReplicatedStorage/Living/WorkEngine.luau")
        camera = read("StarterPlayer/StarterPlayerScripts/SideCamera.luau")
        world = read("ServerScriptService/Services/WorldService.luau")
        self.assertIn('caption.BackgroundTransparency=1', living)
        self.assertIn('caption.TextStrokeTransparency=0.08', living)
        self.assertIn('bill.MaxDistance=40', living)
        self.assertIn('gui.MaxDistance=23', living)
        self.assertIn('h:GetState() == Enum.HumanoidStateType.Swimming', lane)
        self.assertIn('h:Move(Vector3.new(x, if swimming then y else 0, 0), false)', lane)
        self.assertNotIn('h:ChangeState(', lane)
        self.assertNotIn('LinearVelocity', lane.split('local function update')[0])
        self.assertFalse((SRC/"StarterPlayer/StarterPlayerScripts/R6SwimVisual.luau").exists())
        self.assertFalse((SRC/"ReplicatedStorage/WaterRules.luau").exists())
        self.assertIn('npc.motionX=0', work)
        self.assertIn('npc.motionX=(bestX-npc.x)/dt', work)
        self.assertIn('npc.motionZ=(bestZ-z)/dt', work)
        self.assertIn('npc.z=z+dz/distance*travel', work)
        self.assertIn('wander(npc,state,dt)', work)
        self.assertNotIn('return -2.9+((npc.id-1)%4)*1.8', living)
        self.assertIn('return npc.z or 0', living)
        self.assertIn('model:SetAttribute("ER_NativeR6",true)', living)
        self.assertIn('loadTrack(animator,R6_WALK', npc)
        self.assertIn('if not item.native then', npc)
        self.assertIn('ER_NPCVelocityZ', npc)
        self.assertIn('SKIN_TONES={', living)
        self.assertIn('PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP,GHOST_GROUP,false)', living)
        self.assertIn('PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP,"Default",false)', living)
        self.assertIn('item.from:Lerp(item.to,fraction)', npc)
        self.assertIn('local x,z=actorX(npc),actorZ(npc)', living)
        self.assertIn('desiredDistance = if wide then 118 else 88', camera)
        self.assertNotIn('BlackForegroundGrass', world)
        self.assertIn('DarkTreeSilhouette_', world)
        self.assertIn('ER_VisualLayer', world)

    def test_r3_combat_raid_ledger_and_prologue_are_server_owned(self):
        server = read("ServerScriptService/Services/LivingService.luau")
        combat = read("ServerScriptService/Services/CombatService.luau")
        engine = read("ReplicatedStorage/Living/R3Engine.luau")
        living = read("ReplicatedStorage/Living/LivingModel.luau")
        client = read("StarterPlayer/StarterPlayerScripts/ClientBoot.client.luau")
        ui = read("StarterPlayer/StarterPlayerScripts/R3HUD.luau")
        self.assertIn('pcall(R3.ensure,loaded,worldRecord.living==nil)', server)
        self.assertIn('Combat.start(player,state,folder)', server)
        self.assertIn('Combat.tick(dt)', server)
        self.assertIn('R3.step(state,0.1,x,Combat.fireResident,y)', server)
        self.assertIn('h:TakeDamage(damage)', server)
        self.assertIn('Lighting.ClockTime=', server)
        self.assertIn('return Combat.action(player,action,arg)', server)
        self.assertIn('if state.r3~=nil and not R3.valid(state.r3)', living)
        self.assertIn('function R3.pickup(', engine)
        self.assertIn('function R3.trade(', engine)
        self.assertIn('function R3.craftArrows(', engine)
        self.assertIn('function R3.command(', engine)
        self.assertIn('function R3.step(', engine)
        self.assertIn('function R3.spawnWave(', engine)
        self.assertIn('function R3.valid(', engine)
        self.assertIn('R3HUD.start(player)', client)
        self.assertIn('RunService:BindToRenderStep("ER_CoinVFX"', ui)
        self.assertIn('remote:InvokeServer(action,arg)', ui)
        self.assertIn('root.Position.X', combat)
        self.assertIn('local target,alpha=sweep(a.p,nextPos)', combat)
        self.assertNotIn('DataStoreService', ui)
        self.assertNotIn('UpdateAsync(', ui)
        self.assertNotIn('Humanoid:TakeDamage(', ui)

    def test_v13_immersive_hud_shows_real_village_inventory_and_never_dev_overlay(self):
        client = read("StarterPlayer/StarterPlayerScripts/ClientBoot.client.luau")
        lobby = read("StarterPlayer/StarterPlayerScripts/SlotMenu.luau")
        hud = read("StarterPlayer/StarterPlayerScripts/R3HUD.luau")
        build = read("StarterPlayer/StarterPlayerScripts/BuildMenu.luau")
        server = read("ServerScriptService/Services/LivingService.luau")
        work = read("ReplicatedStorage/Living/WorkEngine.luau")
        self.assertIn('BuildMenu.mount(content,remote,notify,', hud)
        self.assertIn('gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets', hud)
        self.assertIn('gui.Name="ER_R3HUD"', hud)
        self.assertNotIn('UIGridLayout', hud)
        self.assertIn('local combat=Instance.new("Frame")', hud)
        self.assertIn('local interact=button(gui,"ContextAction","INTERAGIR")', hud)
        self.assertIn('local journal=panel(gui,"VillageJournal"', hud)
        self.assertIn('local stockBar=panel(gui,"VillageStock"', hud)
        self.assertIn('pages.resources=resourcesPage', hud)
        self.assertIn('pages.villagers=villagersPage', hud)
        self.assertIn('pages.workshop=workshop', hud)
        self.assertIn('local refreshStatus: ()->()', hud)
        self.assertIn('task.wait(3)', hud)
        self.assertIn('contextKind="story"', hud)
        self.assertIn('item=="wood"', server)
        self.assertIn('nearby.canTrade=R3.marketNear(state,x,y)', server)
        self.assertIn('return {ok=true,data=overview,hud=R3.summary(state),nearby=nearby}', server)
        self.assertIn('resources={sources=sources,carried=carried,reserved=reserved,', work)
        self.assertIn('committed=committed,stored=deposited,isolated=isolated,markedTrees=markedTrees}', work)
        self.assertIn('record.living = LivingModel.clone(state)',
                      read("ServerScriptService/Services/SaveSlotService.luau"))
        self.assertIn('local options = {wide = false, debug = false}', lobby)
        self.assertIn('savedOptions = {wide = false, debug = false}', client)
        self.assertNotIn('BuildMenu.start(player)', client)
        self.assertNotIn('Instance.new("ScreenGui")', build)
        self.assertIn('function Menu.mount(', build)
        self.assertIn('tostring(b.progress)', build)
        self.assertNotIn('DataStoreService', hud)
        self.assertNotIn('Humanoid:Move', hud)
        self.assertNotIn('Humanoid:TakeDamage', hud)

    def test_t1_f1_arrow_crafting_has_real_player_inventory_and_clickable_ui(self):
        r3 = read("ReplicatedStorage/Living/R3Engine.luau")
        combat = read("ServerScriptService/Services/CombatService.luau")
        living = read("ServerScriptService/Services/LivingService.luau")
        hud = read("StarterPlayer/StarterPlayerScripts/R3HUD.luau")
        for fragment in [
            'playerBag=Inventory.new(24)',
            'if state.r3.playerBag==nil then',
            'function R3.takeWood(state: any,x: number,y: number)',
            'Inventory.add(d.playerBag,"wood",2)',
            'Inventory.transfer(b.stored,d.playerBag,"wood",2)',
            'if Inventory.count(state.r3.playerBag,"wood")>=cost then',
            'Inventory.take(source,"wood",recipe.wood)',
            'playerWood=if d.playerBag then Inventory.count(d.playerBag,"wood")',
        ]:
            self.assertIn(fragment,r3)
        self.assertIn('elseif action=="take_wood" then',combat)
        self.assertIn('R3.takeWood(state,root.Position.X,root.Position.Y)',combat)
        self.assertIn('or action=="take_wood"',living)
        self.assertIn('nearby.nearestWoodDistance=',living)
        self.assertIn('collectButton=button(workshop,"TakeWood"',hud)
        self.assertIn('craftButton.Active=true',hud)
        self.assertIn('request("take_wood",nil)',hud)
        self.assertIn('redraw()\n        updateVillage()',hud)
        self.assertIn('hud.playerWood or 0',hud)
        self.assertIn('player_bag_full=',hud)

    def test_t1_f1_save_and_return_uses_world_slot_rpc(self):
        boot = read("ServerScriptService/Boot.server.luau")
        hud = read("StarterPlayer/StarterPlayerScripts/R3HUD.luau")
        self.assertIn('"SaveAndReturn","SALVAR E VOLTAR"', hud)
        self.assertIn('slots:InvokeServer("return")', hud)
        return_path = boot.split("local function returnLobby", 1)[1].split("rpc.OnServerInvoke", 1)[0]
        self.assertLess(return_path.index("Saves.save(player,false)"), return_path.index("TeleportService:TeleportAsync"))

    def test_user_production_target_is_unset(self):
        targets = json.loads((GAME / "deploy.targets.json").read_text())["environments"]
        self.assertEqual(str(targets["staging"]["universeId"]), "10769712413")
        self.assertEqual(str(targets["staging"]["placeIds"]["main"]), "90623742498445")
        self.assertIsNone(targets["production"]["universeId"])
        self.assertIsNone(targets["production"]["placeIds"]["main"])


if __name__ == "__main__":
    unittest.main()
