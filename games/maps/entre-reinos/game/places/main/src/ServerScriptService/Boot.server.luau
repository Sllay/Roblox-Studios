--!strict
-- Entre Reinos T1-R1. One world per solo server; recoverable, idempotent slot activation.
-- A Place/character failure must never silently orphan an already saved world.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = script.Parent:WaitForChild("Services")
local SaveSlotService = require(services:WaitForChild("SaveSlotService"))
local WorldService = require(services:WaitForChild("WorldService"))
local CharacterService = require(services:WaitForChild("CharacterService"))
local gameFolder = ReplicatedStorage:WaitForChild("Game")
local WorldProfile = require(gameFolder:WaitForChild("WorldProfile"))
local SlotModel = require(gameFolder:WaitForChild("SlotModel"))

local remote = Instance.new("RemoteFunction")
remote.Name = "ER_WorldSlots"
remote.Parent = gameFolder

-- The X axis of Attachment0 points along Z, so the PlaneConstraint permits XY.
local planeAnchor = Instance.new("Part")
planeAnchor.Name = "ER_PhysicsLaneAnchor"
planeAnchor.Anchored = true
planeAnchor.Transparency = 1
planeAnchor.CanCollide = false
planeAnchor.CanQuery = false
planeAnchor.CanTouch = false
planeAnchor.Size = Vector3.one
planeAnchor.CFrame = CFrame.Angles(0, math.pi / 2, 0)
planeAnchor.Parent = workspace
local planeAttachment = Instance.new("Attachment")
planeAttachment.Name = "ER_WorldLanePlane"
planeAttachment.Parent = planeAnchor

local activePlayer: Player? = nil
local inFlight: {[Player]: boolean} = {}
local lastAction: {[Player]: number} = {}
local stages: {[Player]: string} = {}

local function setStage(player: Player, stage: string)
    stages[player] = stage
    player:SetAttribute("ER_LoadStage", stage)
end

local function attachLane(player: Player, character: Model): (boolean, string?)
    if activePlayer ~= player or player.Character ~= character then
        return false, "character_changed"
    end
    local root = character:WaitForChild("HumanoidRootPart", 8)
    local humanoid = character:WaitForChild("Humanoid", 8)
    if not root or not root:IsA("BasePart") or not humanoid or not humanoid:IsA("Humanoid") then
        return false, "character_not_ready"
    end
    if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
        return false, "r6_not_ready"
    end
    local record = SaveSlotService.get(player)
    if not record then return false, "no_active_session" end

    if not root:FindFirstChild("ER_XYPlaneLock") then
        local laneAttachment = root:FindFirstChild("ER_LaneAttachment")
        if not laneAttachment then
            local newAttachment = Instance.new("Attachment")
            newAttachment.Name = "ER_LaneAttachment"
            newAttachment.Parent = root
            laneAttachment = newAttachment
        end
        if not laneAttachment:IsA("Attachment") then return false, "invalid_lane_attachment" end
        local plane = Instance.new("PlaneConstraint")
        plane.Name = "ER_XYPlaneLock"
        plane.Attachment0 = planeAttachment
        plane.Attachment1 = laneAttachment
        plane.Parent = root
    end

    -- Reapplying the same persisted spawn is safe while recovering an incomplete start.
    local p = record.position
    root.CFrame = CFrame.new(p.x, p.y + 1, WorldProfile.LANE_Z)
    humanoid.AutoRotate = false
    player:SetAttribute("ER_GeneratorVersion", WorldProfile.GENERATOR_VERSION)
    player:SetAttribute("ER_Seed", record.seed)
    player:SetAttribute("ER_WorldLoaded", true)
    setStage(player, "ready")
    return true, nil
end

local function worldResponse(index: number, record: any)
    return {
        ok = true,
        slot = index,
        seed = record.seed,
        spawn = record.position,
        signature = WorldProfile.signature(record.seed),
    }
end

local function completeEntry(player: Player, index: number, record: any): any
    if not SaveSlotService.active(player) then
        return {ok = false, error = "no_active_session", stage = "slot"}
    end
    if not WorldService.isActive() then
        setStage(player, "terrain")
        local invoked, worldOk, reason = pcall(WorldService.activate, record.seed)
        if not invoked or not worldOk then
            if not invoked then
                warn("[EntreReinos][terrain] Engine exception at ", WorldService.getPhase(), ": ", worldOk)
                WorldService.reportException()
            else
                warn("[EntreReinos][terrain] Generation failed: ", reason)
            end
            -- The recorded lease can survive a partial terrain write.
            -- Only release the lease; NEVER remove, recreate or modify the world seed.
            local released, releaseError = SaveSlotService.abortActivation(player)
            if not released then
                warn("[EntreReinos][terrain] Lease release not confirmed: ", releaseError)
            end
            player:SetAttribute("ER_WorldLoaded", false)
            setStage(player, "terrain_failed")
            local safeCode = WorldService.getFailure() or "terrain_activation_exception"
            return {ok = false, error = safeCode, stage = "terrain",
                terrainPhase = WorldService.getPhase(),
                retryInNewServer = true, leaseReleased = released}
        end
    end
    -- Do not rerun Terrain generation on retries: it may have already succeeded.
    activePlayer = player
    setStage(player, "character")
    local character = player.Character
    local h = if character then character:FindFirstChildOfClass("Humanoid") else nil
    if not h or h.RigType ~= Enum.HumanoidRigType.R6 then
        local okCharacter, rigOk, rigError = pcall(CharacterService.ensureR6, player)
        if not okCharacter then
            warn("[EntreReinos][character] Unexpected avatar error: ", rigOk)
            return {ok = false, error = "character_setup_exception",
                stage = "character", recoverable = true, slot = index}
        end
        if not rigOk then
            return {ok = false, error = rigError or "r6_creation_failed",
                stage = "character", recoverable = true, slot = index}
        end
        character = player.Character
    end
    if not character then
        return {ok = false, error = "character_not_ready", stage = "character",
            recoverable = true, slot = index}
    end

    setStage(player, "lane")
    local attached, laneOk, laneReason = pcall(attachLane, player, character)
    if not attached then
        warn("[EntreReinos][lane] Failed to attach XY physics: ", laneOk)
        return {ok = false, error = "lane_setup_exception", stage = "lane",
            recoverable = true, slot = index}
    end
    if not laneOk then
        warn("[EntreReinos][lane] Character not ready for play: ", laneReason)
        return {ok = false, error = laneReason or "lane_setup_failed",
            stage = "lane", recoverable = true, slot = index}
    end
    return worldResponse(index, record)
end

local function resume(player: Player, index: any): any
    local actual = SaveSlotService.index(player)
    if not actual then
        return {ok = false, error = "no_active_session", stage = "slot"}
    end
    if index ~= actual then
        return {ok = false, error = "other_slot_active", activeSlot = actual, stage = "slot"}
    end
    if not WorldService.isActive() then
        -- The first diagnostic must never be replaced with a generic resume error.
        -- A broken session releases only its lease. A partially written Terrain
        -- is not retried on this same server.
        local reason = WorldService.getFailure() or "terrain_incomplete"
        local released, releaseError = SaveSlotService.abortActivation(player)
        if not released then
            warn("[EntreReinos][terrain] Recovery lease release not confirmed: ", releaseError)
        end
        player:SetAttribute("ER_WorldLoaded", false)
        setStage(player, "terrain_failed")
        return {ok = false, error = reason, stage = "terrain",
            terrainPhase = WorldService.getPhase(),
            retryInNewServer = true, leaseReleased = released}
    end
    if activePlayer and activePlayer ~= player then
        return {ok = false, error = "another_player_world_active"}
    end
    local data = SaveSlotService.get(player)
    if not data then return {ok = false, error = "no_active_session"} end
    return completeEntry(player, actual, data)
end

remote.OnServerInvoke = function(player: Player, action: any, index: any)
    if typeof(action) ~= "string" then return {ok = false, error = "invalid_action"} end
    if #Players:GetPlayers() > 1 then return {ok = false, error = "solo_server_required"} end
    if inFlight[player] then return {ok = false, error = "request_busy"} end
    local now = os.clock()
    -- A recovery request must not be rate-limited immediately after a failed response.
    if action ~= "resume" and lastAction[player] and now - lastAction[player] < 0.35 then
        return {ok = false, error = "rate_limited"}
    end
    if action ~= "resume" then lastAction[player] = now end

    inFlight[player] = true
    local stage = "request"
    local ok, answer = pcall(function()
        if action == "list" then
            stage = "list"
            local success, slots = SaveSlotService.list(player)
            return if success then {
                ok = true, slots = slots, activeSlot = SaveSlotService.index(player),
                worldActive = WorldService.isActive(),
                serverRevision = game.PlaceVersion,
            } else {ok = false, error = slots}
        end
        if action == "save" then
            stage = "save"
            local success, reason = SaveSlotService.save(player, false)
            return if success then {ok = true} else {ok = false, error = reason}
        end
        if action ~= "create" and action ~= "open" and action ~= "delete" and action ~= "resume" then
            return {ok = false, error = "unknown_action"}
        end
        if not SlotModel.validIndex(index) then
            return {ok = false, error = "invalid_slot"}
        end
        if action == "resume" then
            stage = "resume"
            return resume(player, index)
        end
        if action == "delete" then
            stage = "delete"
            local success, result = SaveSlotService.delete(player, index)
            return if success then {ok = true, summary = result} else {ok = false, error = result}
        end
        -- Critical fix: create/open a slot already active in THIS server means CONTINUE,
        -- not a permanent world_already_active denial.
        if SaveSlotService.active(player) then
            stage = "resume"
            return resume(player, index)
        end
        if WorldService.isActive() or activePlayer then
            return {ok = false, error = "world_needs_new_server", stage = "terrain"}
        end

        stage = "avatar"
        setStage(player, "avatar")
        local avatarOk, avatarReason = CharacterService.ensureR6(player)
        if not avatarOk then
            return {ok = false, error = avatarReason or "r6_creation_failed", stage = "avatar"}
        end

        stage = "slot"
        setStage(player, "slot")
        local success, record = if action == "create"
            then SaveSlotService.create(player, index) else SaveSlotService.open(player, index)
        if not success then
            return {ok = false, error = record, stage = "slot"}
        end

        stage = "enter"
        return completeEntry(player, index, record)
    end)
    inFlight[player] = nil
    if not ok then
        local stageName = stages[player] or stage
        warn("[EntreReinos] RPC operation error stage=", stageName,
            " action=", action, " index=", tostring(index), " reason=", answer)
        return {ok = false, error = "server_operation_failed", stage = stageName,
            recoverable = SaveSlotService.active(player) and WorldService.isActive()}
    end
    return answer
end

local function register(player: Player)
    if #Players:GetPlayers() > 1 then
        player:Kick("Entre Reinos: esta versão usa servidores solo.")
        return
    end
    player:SetAttribute("ER_WorldLoaded", false)
    setStage(player, "menu")
    player.CharacterAdded:Connect(function(character)
        task.defer(function()
            if activePlayer ~= player or player.Character ~= character then return end
            local humanoid = character:WaitForChild("Humanoid", 10)
            if humanoid and humanoid:IsA("Humanoid")
                and humanoid.RigType ~= Enum.HumanoidRigType.R6 then
                local conversionOk, success, reason = pcall(CharacterService.ensureR6, player)
                if not conversionOk or not success then
                    player:SetAttribute("ER_WorldLoaded", false)
                    warn("[EntreReinos][respawn] R6 conversion failed: ", reason or success)
                end
                return
            end
            local invoked, attached, reason = pcall(attachLane, player, character)
            if not invoked or not attached then
                player:SetAttribute("ER_WorldLoaded", false)
                setStage(player, "respawn_failed")
                warn("[EntreReinos][respawn] XY lane reattachment failed: ",
                    if invoked then reason else attached)
            end
        end)
    end)
end
Players.PlayerAdded:Connect(register)
for _, player in ipairs(Players:GetPlayers()) do register(player) end

Players.PlayerRemoving:Connect(function(player)
    inFlight[player] = nil
    lastAction[player] = nil
    stages[player] = nil
    if SaveSlotService.active(player) then
        local saved, reason = SaveSlotService.save(player, true)
        if not saved then warn("[EntreReinos] Leave save not confirmed: ", reason) end
    end
    if activePlayer == player then activePlayer = nil end
end)
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if SaveSlotService.active(player) then
            local saved, reason = SaveSlotService.save(player, true)
            if not saved then warn("[EntreReinos] Shutdown save not confirmed: ", reason) end
        end
    end
end)
SaveSlotService.startAutosave()
print("[EntreReinos] Recoverable T1-R1 world boot ready")
