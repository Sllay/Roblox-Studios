--!strict
-- T1-R1. Same Place, two server roles:
-- public lobby only reads/creates slots and starts server-only teleport;
-- a reserved server exclusively loads one player's world and writes Terrain.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local services = script.Parent:WaitForChild("Services")
local Saves = require(services:WaitForChild("SaveSlotService"))
local World = require(services:WaitForChild("WorldService"))
local Characters = require(services:WaitForChild("CharacterService"))
local LivingService = require(services:WaitForChild("LivingService"))
local shared = ReplicatedStorage:WaitForChild("Game")
local Profile = require(shared:WaitForChild("RegionalProfile"))
local Slots = require(shared:WaitForChild("SlotModel"))
local Route = require(shared:WaitForChild("WorldRoute"))

local rpc = Instance.new("RemoteFunction")
rpc.Name = "ER_WorldSlots"
rpc.Parent = shared

-- Dedicated destination is a RESERVED server. VIP servers are not world sessions.
local worldServer = Route.isWorldServer(game.PrivateServerId, game.PrivateServerOwnerId)
local busy: {[Player]: boolean} = {}
local activePlayer: Player? = nil
local activeSlot: number? = nil
local pendingTeleport: {[Player]: boolean} = {}

local function stage(player: Player, name: string, progress: number?, message: string?)
    player:SetAttribute("ER_LoadStage", name)
    if progress ~= nil then
        player:SetAttribute("ER_LoadProgress", math.clamp(progress, 0, 1))
    end
    if message then player:SetAttribute("ER_LoadMessage", message) end
end

local anchor: Part? = nil
local lanePlane: Attachment? = nil
if worldServer then
    local root = Instance.new("Part")
    root.Name = "ER_PhysicsLaneAnchor"
    root.Anchored = true
    root.Transparency = 1
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.Size = Vector3.one
    root.CFrame = CFrame.Angles(0, math.pi / 2, 0)
    root.Parent = workspace
    local normal = Instance.new("Attachment")
    normal.Name = "ER_WorldLanePlane"
    normal.Parent = root
    anchor = root
    lanePlane = normal
end

local function attachLane(player: Player, char: Model): (boolean, string?)
    if not worldServer or activePlayer ~= player or player.Character ~= char then
        return false, "character_changed"
    end
    local root = char:WaitForChild("HumanoidRootPart", 10)
    local h = char:WaitForChild("Humanoid", 10)
    if not root or not root:IsA("BasePart") or not h or not h:IsA("Humanoid") then
        return false, "character_not_ready"
    end
    if h.RigType ~= Enum.HumanoidRigType.R6 then return false, "r6_not_ready" end
    if not lanePlane then return false, "plane_unavailable" end
    local data = Saves.get(player)
    if not data or not Slots.validWorld(data) then return false, "no_active_session" end
    if not root:FindFirstChild("ER_XYPlaneLock") then
        local attachment = Instance.new("Attachment")
        attachment.Name = "ER_LaneAttachment"
        attachment.Parent = root
        local lock = Instance.new("PlaneConstraint")
        lock.Name = "ER_XYPlaneLock"
        lock.Attachment0 = lanePlane
        lock.Attachment1 = attachment
        lock.Parent = root
    end
    local recovered=player:GetAttribute("ER_Recovering")==true
        or (player:GetAttribute("ER_WorldLoaded")~=true and data.living and data.living.r3
            and data.living.r3.awaitingRecovery==true)
    local pos=if recovered then Profile.spawn(data.seed) else Slots.spawnPosition(data)
    root.CFrame = CFrame.new(pos.x, pos.y + 1, Profile.LANE_Z)
    h.AutoRotate = false
    player:SetAttribute("ER_GeneratorVersion", Profile.GENERATOR_VERSION)
    player:SetAttribute("ER_Seed", data.seed)
    if recovered then
        player:SetAttribute("ER_Recovering",false)
        LivingService.playerRecovered(player)
    end
    if not h:GetAttribute("ER_DeathBound") then
        h:SetAttribute("ER_DeathBound",true)
        h.Died:Once(function()
            if player.Character~=char or player:GetAttribute("ER_WorldLoaded")~=true then return end
            player:SetAttribute("ER_Recovering",true)
            LivingService.playerDied(player)
        end)
    end
    return true, nil
end

local function makeDestination(player: Player, index: number): (boolean, string?)
    if worldServer then return false, "already_in_world_server" end
    if pendingTeleport[player] then return false, "teleport_in_progress" end
    pendingTeleport[player] = true
    local id = HttpService:GenerateGUID(false)
    local options = Instance.new("TeleportOptions")
    options.ReservedServerId = id
    options:SetTeleportData({
        kind = "EntreReinosWorld",
        protocol = 1,
        slot = index,
        ownerUserId = player.UserId,
        reservedId = id,
        sourcePlaceId = game.PlaceId,
    })
    player:SetAttribute("ER_TeleportError", "")
    player:SetAttribute("ER_LobbyTransfer", "starting")
    local ok, reason = pcall(function()
        TeleportService:TeleportAsync(game.PlaceId, {player}, options)
    end)
    options:Destroy()
    if not ok then
        pendingTeleport[player] = nil
        player:SetAttribute("ER_LobbyTransfer", "failed")
        player:SetAttribute("ER_TeleportError", "teleport_request_failed")
        warn("[EntreReinos][Lobby] TeleportAsync failed: ", reason)
        return false, "teleport_request_failed"
    end
    player:SetAttribute("ER_LobbyTransfer", "accepted")
    return true, nil
end

TeleportService.TeleportInitFailed:Connect(function(player, _result, message, placeId, _options)
    if not worldServer and placeId == game.PlaceId then
        pendingTeleport[player] = nil
        player:SetAttribute("ER_LobbyTransfer", "failed")
        player:SetAttribute("ER_TeleportError", "teleport_init_failed")
        warn("[EntreReinos][Lobby] TeleportInitFailed: ", message)
    end
end)

local function startWorld(player: Player)
    stage(player, "validating", 0.02, "Validando a entrada no seu mundo...")
    local join = player:GetJoinData()
    local ticket = if type(join) == "table" then join.TeleportData else nil
    -- TeleportData is a routing hint, never a source of saved seed or ownership.
    -- The record is always fetched by the destination from player.UserId.
    if not Route.validArrival(ticket, player.UserId, game.PlaceId, game.PrivateServerId) then
        player:Kick("Entrada no servidor do mundo inválida. Abra seu mundo pelo lobby.")
        return
    end
    local index: number = ticket.slot
    activePlayer = player
    activeSlot = index

    stage(player, "character", 0.08, "Preparando personagem R6...")
    local avatarInvoked, avatarOk, avatarReason = pcall(Characters.ensureR6, player)
    if not avatarInvoked or not avatarOk then
        local code = if avatarInvoked then (avatarReason or "r6_creation_failed")
            else "r6_creation_exception"
        player:SetAttribute("ER_LoadError", code)
        stage(player, "failed", nil, "Falha no personagem R6; seu save não foi alterado.")
        warn("[EntreReinos][World] R6 error ", code)
        return
    end

    stage(player, "slot", 0.14, "Abrindo seu save persistente...")
    -- Independent game-server UpdateAsync ownership; lobby never holds this lease.
    local opened, openOk, record = pcall(Saves.open, player, index)
    if not opened or not openOk or type(record) ~= "table" then
        local code = if opened then tostring(record) else "slot_open_exception"
        player:SetAttribute("ER_LoadError", code)
        stage(player, "failed", nil, "Não foi possível abrir o save. Ele não será apagado.")
        warn("[EntreReinos][World] Slot open failure: ", code)
        return
    end
    if player.Parent~=Players then
        Saves.abortActivation(player)
        return
    end
    -- IMPORTANT: no conditional expression returning multiple values;
    -- explicit branch above checks (success, record) separately.

    stage(player, "terrain", 0.18, "Gerando as primeiras regiões...")
    local terrainInvoked, terrainOk, terrainReason = pcall(World.activate,
        record.seed, function(fraction: number, message: string)
            stage(player, "terrain", 0.18 + fraction * 0.66, message)
        end, Profile)
    if not terrainInvoked or not terrainOk then
        local failureCode = if terrainInvoked then (terrainReason or World.getFailure()
            or "terrain_failed") else "terrain_activation_exception"
        if not terrainInvoked then
            warn("[EntreReinos][Terrain] Exception at phase ", World.getPhase(), ": ", terrainOk)
            World.reportException()
        end
        player:SetAttribute("ER_LoadError", failureCode)
        stage(player, "failed", nil,
            "Falha na geração do terreno (" .. tostring(failureCode) .. "). Save preservado.")
        local releaseOk, releaseReason = Saves.abortActivation(player)
        if not releaseOk then
            warn("[EntreReinos][World] Could not release failed lease: ", releaseReason)
        end
        return
    end

    local returnPosition=Slots.spawnPosition(record)
    local loaded,streamReason=World.ensureNear(record.seed,returnPosition.x)
    if not loaded then
        player:SetAttribute("ER_LoadError",streamReason or "terrain_resume_failed")
        stage(player,"failed",nil,"Região do save indisponível. Seu mundo foi preservado.")
        Saves.abortActivation(player)
        return
    end
    stage(player,"terrain",0.88,"Preparando a paisagem até o horizonte...")
    local prepared,viewReason=World.prefetch(record.seed,returnPosition.x,0,true)
    if not prepared then
        player:SetAttribute("ER_LoadError",viewReason or "terrain_prefetch_failed")
        stage(player,"failed",nil,"O terreno ainda não está disponível. Seu save foi preservado.")
        Saves.abortActivation(player)
        return
    end
    stage(player, "spawn", 0.91, "Posicionando personagem no terreno...")
    local char = player.Character
    if not char then
        player:SetAttribute("ER_LoadError", "character_not_ready")
        stage(player, "failed", nil, "Personagem não carregado; o save está preservado.")
        Saves.abortActivation(player)
        return
    end
    local attached, okLane, reasonLane = pcall(attachLane, player, char)
    if not attached or not okLane then
        local errorCode = if attached then reasonLane else "lane_setup_exception"
        player:SetAttribute("ER_LoadError", errorCode or "lane_setup_failed")
        stage(player, "failed", nil, "Falha na física do personagem; o save foi preservado.")
        warn("[EntreReinos][World] XY lane failed: ", reasonLane or okLane)
        Saves.abortActivation(player)
        return
    end

    -- T1-R2 lives in this reserved server and in the SAME leased world record.
    -- Do not proceed if the optional population schema is unknown/corrupt.
    stage(player, "population", 0.96, "Carregando moradores e trabalhos...")
    local livingInvoked, livingOk, livingError = pcall(LivingService.start,
        player, record, function(fraction: number, message: string)
            stage(player,"population",0.96+0.035*fraction,message)
        end)
    if not livingInvoked or not livingOk then
        local reason = if livingInvoked then livingError else "living_start_exception"
        player:SetAttribute("ER_LoadError", reason or "living_start_failed")
        stage(player, "failed", nil, "Falha ao carregar moradores; save preservado.")
        warn("[EntreReinos][Living] Startup failed: ", livingError or livingOk)
        Saves.abortActivation(player)
        return
    end
    -- Simulation only starts after terrain, R6 and living state are ready.
    player:SetAttribute("ER_WorldLoaded", true)
    stage(player, "ready", 1, "Mundo carregado")
    task.spawn(function()
        local lastSafe: CFrame?=nil
        while player.Parent == Players and activePlayer == player do
            task.wait(0.28)
            local character = player.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            if root and root:IsA("BasePart") and player:GetAttribute("ER_TravelPending")~=true then
                if World.isLoadedAt(root.Position.X) and root.Position.Y> -16 then
                    lastSafe=root.CFrame
                elseif lastSafe then
                    root.CFrame=lastSafe
                    root.AssemblyLinearVelocity=Vector3.zero
                end
                local velocity=root.AssemblyLinearVelocity.X
                local travelVelocity=player:GetAttribute("ER_TravelVelocity")
                if type(travelVelocity)=="number" then velocity=travelVelocity end
                local generated,reason=World.prefetch(record.seed,root.Position.X,velocity)
                if not generated and reason ~= "world_generation_in_progress" then
                    warn("[EntreReinos][Streaming] Could not load nearby region: ", reason)
                    player:SetAttribute("ER_StreamError", tostring(reason))
                end
            end
        end
    end)
    print("[EntreReinos] Reserved world started: slot=", index, " seed=", record.seed)
end

local function closeWorldSave(player: Player): (boolean, string?)
    if player:GetAttribute("ER_WorldLoaded")~=true then
        return Saves.abortActivation(player)
    end
    for attempt=1,3 do
        if not Saves.active(player) then return true,nil end
        local saved,reason=Saves.save(player,true)
        if saved or (reason~="datastore_unavailable" and reason~="backup_unavailable") then
            return saved,reason
        end
        if attempt==3 then return false,reason end
        task.wait(attempt)
    end
    return false,"datastore_unavailable"
end

local function returnLobby(player: Player): (boolean, string?)
    if not worldServer then return false, "not_in_world_server" end
    if player:GetAttribute("ER_WorldLoaded")==true then
        local saved,reason=Saves.save(player,false)
        if not saved then return false,reason end
    end
    local options = Instance.new("TeleportOptions")
    options.ForcePublicServer = true
    local ok, reason = pcall(function()
        TeleportService:TeleportAsync(game.PlaceId, {player}, options)
    end)
    options:Destroy()
    if not ok then
        warn("[EntreReinos] Return lobby teleport failed: ", reason)
        return false, "teleport_request_failed"
    end
    return true, nil
end

rpc.OnServerInvoke = function(player: Player, action: any, index: any): any
    if type(action) ~= "string" then return {ok = false, error = "invalid_action"} end
    if worldServer then
        if action == "status" then
            return {ok = true, stage = player:GetAttribute("ER_LoadStage"),
                progress = player:GetAttribute("ER_LoadProgress"),
                error = player:GetAttribute("ER_LoadError"), serverRevision = game.PlaceVersion}
        end
        if action == "return" then
            if busy[player] then return {ok=false,error="request_busy"} end
            busy[player]=true
            local invoked,ok,reason=pcall(returnLobby,player)
            busy[player]=nil
            return if invoked and ok then {ok = true, teleporting = true}
                else {ok = false, error = if invoked then reason else "server_operation_failed"}
        end
        return {ok = false, error = "world_server_lobby_disabled"}
    end
    if not Players:FindFirstChild(player.Name) or #Players:GetPlayers() > 1 then
        return {ok = false, error = "solo_server_required"}
    end
    if busy[player] then return {ok = false, error = "request_busy"} end
    busy[player] = true
    local invoked, result = pcall(function()
        if action == "list" then
            local ok, slots = Saves.list(player)
            return if ok then {ok = true, slots = slots,
                serverRevision = game.PlaceVersion, activeSlot = nil, worldActive = false}
                else {ok = false, error = slots}
        end
        if not Slots.validIndex(index) then
            return {ok = false, error = "invalid_slot"}
        end
        if action == "delete" then
            local ok, summary = Saves.delete(player, index)
            return if ok then {ok = true, summary = summary}
                else {ok = false, error = summary}
        end
        if action ~= "create" and action ~= "open" then
            return {ok = false, error = "unknown_action"}
        end

        local ok: boolean
        local record: any
        if action == "create" then
            -- FIX for Boot:101: preserve both result values by explicit branch.
            ok, record = Saves.createDetached(player, index)
        else
            ok, record = Saves.inspect(player, index)
        end
        if not ok then return {ok = false, error = record, stage = "slot"} end
        if type(record) ~= "table" then
            return {ok = false, error = "slot_record_invalid", stage = "slot"}
        end
        local transferred, transferReason = makeDestination(player, index)
        return if transferred then {ok = true, teleporting = true, slot = index}
            else {ok = false, error = transferReason, stage = "teleport"}
    end)
    busy[player] = nil
    if not invoked then
        warn("[EntreReinos][Lobby] RPC operation error: ", result)
        return {ok = false, error = "server_operation_failed", stage = "lobby"}
    end
    return result
end

local function register(player: Player)
    -- Hard single-player guard even if Creator Dashboard matchmaking capacity
    -- is greater than 1. Actual Players.MaxPlayers is Dashboard-only.
    if #Players:GetPlayers() > 1 then
        player:Kick("Entre Reinos: este servidor aceita um jogador por enquanto.")
        return
    end
    player:SetAttribute("ER_ServerMode", if worldServer then "world" else "lobby")
    player:SetAttribute("ER_WorldLoaded", false)
    player:SetAttribute("ER_LoadError", "")
    stage(player, if worldServer then "connecting" else "lobby", 0, "Bem-vindo ao Entre Reinos")
    if worldServer then
        player.CharacterAdded:Connect(function(char)
            task.defer(function()
                if activePlayer ~= player or player.Character ~= char
                    or not World.isActive() then return end
                local human = char:WaitForChild("Humanoid", 10)
                if not human or not human:IsA("Humanoid") then return end
                if human.RigType ~= Enum.HumanoidRigType.R6 then
                    local converted, ok, reason = pcall(Characters.ensureR6, player)
                    if not converted or not ok then
                        player:SetAttribute("ER_WorldLoaded", false)
                        player:SetAttribute("ER_LoadError", "r6_respawn_failed")
                        warn("[EntreReinos] Respawn conversion failed ", reason or ok)
                    end
                    return
                end
                local attached, ok, why = pcall(attachLane, player, char)
                if not attached or not ok then
                    warn("[EntreReinos] Respawn plane not attached: ", why or ok)
                end
            end)
        end)
        task.spawn(function() startWorld(player) end)
    end
end

Players.PlayerAdded:Connect(register)
for _, player in ipairs(Players:GetPlayers()) do register(player) end
Players.PlayerRemoving:Connect(function(player)
    busy[player] = nil
    pendingTeleport[player] = nil
    if worldServer and Saves.active(player) then
        local ok, reason = closeWorldSave(player)
        if not ok then warn("[EntreReinos][World] Exit save not confirmed: ", reason) end
    end
    if worldServer then LivingService.stop(player) end
    if activePlayer == player then
        activePlayer = nil
        activeSlot = nil
    end
end)
game:BindToClose(function()
    if not worldServer then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if Saves.active(player) then
            local ok, reason = closeWorldSave(player)
            if not ok then warn("[EntreReinos] Shutdown save not confirmed: ", reason) end
        end
    end
end)
if worldServer then
    Saves.setLivingProvider(function(player: Player)
        return LivingService.snapshot(player)
    end)
    Saves.startAutosave()
end
print("[EntreReinos] Role=", if worldServer then "reserved-world" else "lobby",
    " Place=", game.PlaceId, " Rev=", game.PlaceVersion)
