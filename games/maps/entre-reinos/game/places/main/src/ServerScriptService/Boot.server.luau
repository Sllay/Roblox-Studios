--!strict
-- Entre Reinos T1-R1: authoritative world/session bootstrap for one-player servers.
-- No Place publishing or remote Terrain mutation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SaveSlotService = require(script.Parent:WaitForChild("Services"):WaitForChild("SaveSlotService"))
local WorldService = require(script.Parent:WaitForChild("Services"):WaitForChild("WorldService"))
local WorldProfile = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("WorldProfile"))

local gameFolder = ReplicatedStorage:WaitForChild("Game")
local remote = Instance.new("RemoteFunction")
remote.Name = "ER_WorldSlots"
remote.Parent = gameFolder

local planeAnchor = Instance.new("Part")
planeAnchor.Name = "ER_PhysicsLaneAnchor"
planeAnchor.Anchored = true
planeAnchor.Transparency = 1
planeAnchor.CanCollide = false
planeAnchor.CanQuery = false
planeAnchor.CanTouch = false
planeAnchor.Size = Vector3.new(1, 1, 1)
planeAnchor.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
planeAnchor.Parent = workspace
local planeAttachment = Instance.new("Attachment")
planeAttachment.Name = "ER_WorldLanePlane"
planeAttachment.Parent = planeAnchor

local activePlayer: Player? = nil
local inFlight: {[Player]: boolean} = {}
local lastAction: {[Player]: number} = {}

local function respawnOnLane(player: Player, character: Model)
    if activePlayer ~= player then return end
    local root = character:WaitForChild("HumanoidRootPart", 10)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not root or not root:IsA("BasePart") or not humanoid or not humanoid:IsA("Humanoid") then
        warn("[EntreReinos] Missing character root/humanoid")
        return
    end
    local laneAttachment = Instance.new("Attachment")
    laneAttachment.Name = "ER_LaneAttachment"
    laneAttachment.Parent = root
    local plane = Instance.new("PlaneConstraint")
    plane.Name = "ER_XYPlaneLock"
    plane.Attachment0 = planeAttachment
    plane.Attachment1 = laneAttachment
    plane.Parent = root

    local data = SaveSlotService.get(player)
    if data and data.position then
        local position = data.position
        -- A one-time spawn placement, never a per-frame teleport.
        root.CFrame = CFrame.new(position.x, position.y + 1, WorldProfile.LANE_Z)
    end
    humanoid.AutoRotate = false
    player:SetAttribute("ER_WorldLoaded", true)
    player:SetAttribute("ER_GeneratorVersion", WorldProfile.GENERATOR_VERSION)
    if data then player:SetAttribute("ER_Seed", data.seed) end
end

local function activate(player: Player, record: any)
    local ok, message = WorldService.activate(record.seed)
    if not ok then
        warn("[EntreReinos] World did not activate: ", message)
        local released, releaseReason = SaveSlotService.abortActivation(player)
        if not released then warn("[EntreReinos] Lease release not confirmed: ", releaseReason) end
        return {ok = false, error = message}
    end
    activePlayer = player
    if player.Character then
        respawnOnLane(player, player.Character)
    end
    return {
        ok = true,
        seed = record.seed,
        slot = record.position and record.slot or nil,
        spawn = record.position,
        signature = WorldProfile.signature(record.seed),
    }
end

remote.OnServerInvoke = function(player: Player, action: any, index: any)
    if typeof(action) ~= "string" then return {ok = false, error = "invalid_action"} end
    if #Players:GetPlayers() > 1 then return {ok = false, error = "solo_server_required"} end
    if inFlight[player] then return {ok = false, error = "request_busy"} end
    local now = os.clock()
    if lastAction[player] and now - lastAction[player] < 0.35 then
        return {ok = false, error = "rate_limited"}
    end
    lastAction[player] = now
    inFlight[player] = true
    local ok, answer = pcall(function()
        if action == "list" then
            local success, slots = SaveSlotService.list(player)
            return if success then {ok = true, slots = slots} else {ok = false, error = slots}
        end
        if action ~= "create" and action ~= "open" and action ~= "delete" and action ~= "save" then
            return {ok = false, error = "unknown_action"}
        end
        if action == "save" then
            local saved, reason = SaveSlotService.save(player, false)
            return if saved then {ok = true} else {ok = false, error = reason}
        end
        local Slots = require(gameFolder:WaitForChild("SlotModel"))
        if not Slots.validIndex(index) then
            return {ok = false, error = "invalid_slot"}
        end
        if action == "delete" then
            local success, result = SaveSlotService.delete(player, index)
            return if success then {ok = true, summary = result} else {ok = false, error = result}
        end
        if activePlayer or WorldService.isActive() or SaveSlotService.active(player) then
            return {ok = false, error = "world_already_active"}
        end
        -- Roblox Avatar Settings must specify the R6 rig. Never change Humanoid.RigType mid-game.
        local character = player.Character
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
            return {ok = false, error = "configure_R6_avatar_in_experience_settings"}
        end
        local created, record = if action == "create"
            then SaveSlotService.create(player, index) else SaveSlotService.open(player, index)
        if not created then
            return {ok = false, error = record}
        end
        local started = activate(player, record)
        if started.ok then
            started.slot = index
        end
        return started
    end)
    inFlight[player] = nil
    if not ok then
        warn("[EntreReinos] World slots request error: ", answer)
        return {ok = false, error = "server_operation_failed"}
    end
    return answer
end

local function register(player: Player)
    if #Players:GetPlayers() > 1 then
        player:Kick("Entre Reinos: esta versão usa servidores solo.")
        return
    end
    player:SetAttribute("ER_WorldLoaded", false)
    player.CharacterAdded:Connect(function(char)
        task.defer(respawnOnLane, player, char)
    end)
end
Players.PlayerAdded:Connect(register)
for _, player in ipairs(Players:GetPlayers()) do register(player) end

Players.PlayerRemoving:Connect(function(player)
    inFlight[player] = nil
    lastAction[player] = nil
    if SaveSlotService.active(player) then
        local ok, errorReason = SaveSlotService.save(player, true)
        if not ok then warn("[EntreReinos] Leave save not confirmed: ", errorReason) end
    end
    if activePlayer == player then activePlayer = nil end
end)
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if SaveSlotService.active(player) then
            local success, reason = SaveSlotService.save(player, true)
            if not success then warn("[EntreReinos] Shutdown save not confirmed: ", reason) end
        end
    end
end)
SaveSlotService.startAutosave()
print("[EntreReinos] T1-R1 server bootstrap ready; world remains unloaded until slot selected")
