--!strict
-- T1-R1. True R6 character generated server-side with the supported Roblox Players API.
-- The game intentionally does not mutate Humanoid.RigType or require manual Avatar Settings.
local Players = game:GetService("Players")
local Service = {}
local spawning: {[Player]: boolean} = {}

local function isRealR6(character: Model?): boolean
    if not character then return false end
    local h = character:FindFirstChildOfClass("Humanoid")
    return h ~= nil
        and h.RigType == Enum.HumanoidRigType.R6
        and character:FindFirstChild("HumanoidRootPart") ~= nil
        and character:FindFirstChild("Torso") ~= nil
end

local function buildR6(description: HumanoidDescription): (boolean, any)
    return pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(
            description, Enum.HumanoidRigType.R6
        )
    end)
end

function Service.ensureR6(player: Player): (boolean, string?)
    if player.Parent ~= Players then return false, "player_disconnected" end
    if isRealR6(player.Character) then return true, nil end
    if spawning[player] then return false, "r6_spawn_in_progress" end
    spawning[player] = true

    local old = player.Character
    -- Preserve the player's classic clothing and body colors when the engine can
    -- convert them. Layered R15 geometry is not applied to a classic R6 skeleton.
    local description = Instance.new("HumanoidDescription")
    local appliedDescription: HumanoidDescription? = nil
    local existingHumanoid = if old then old:FindFirstChildOfClass("Humanoid") else nil
    if existingHumanoid then
        local okDesc, result = pcall(function()
            return existingHumanoid:GetAppliedDescription()
        end)
        if okDesc and result and result:IsA("HumanoidDescription") then
            appliedDescription = result
        end
    end

    local ok, model = buildR6(appliedDescription or description)
    if not ok and appliedDescription then
        warn("[EntreReinos] Player appearance not R6-compatible; using classic avatar.")
        ok, model = buildR6(description)
    end
    if appliedDescription then appliedDescription:Destroy() end
    description:Destroy()

    if not ok or typeof(model) ~= "Instance" or not model:IsA("Model")
        or not isRealR6(model) then
        if ok and typeof(model) == "Instance" then model:Destroy() end
        spawning[player] = nil
        warn("[EntreReinos] Official R6 model creation failed: ", if ok then "invalid_rig" else tostring(model))
        return false, "r6_creation_failed"
    end
    if player.Parent ~= Players then
        model:Destroy()
        spawning[player] = nil
        return false, "player_disconnected"
    end

    model.Name = player.Name
    model:SetAttribute("ER_RigSource", "ServerOfficialR6")
    local root = model:FindFirstChild("HumanoidRootPart")
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    assert(root and root:IsA("BasePart") and humanoid)
    root.Anchored = false
    humanoid.AutoRotate = false
    -- Neutral position until the selected world finishes generating.
    local startArea = workspace:FindFirstChild("StartArea")
    local spawn = if startArea then startArea:FindFirstChild("Spawn") else nil
    local position = if spawn and spawn:IsA("BasePart")
        then spawn.Position + Vector3.new(0, 6, 0) else Vector3.new(0, 23, 0)
    model:PivotTo(CFrame.new(position))

    -- The server changes the entire character model, not Humanoid.RigType.
    -- Assigning Player.Character raises CharacterAdded for client controls.
    local successAssign, assignError = pcall(function()
        model.Parent = workspace
        player.Character = model
    end)
    if not successAssign then
        model:Destroy()
        spawning[player] = nil
        warn("[EntreReinos] Could not assign R6 character: ", assignError)
        return false, "r6_assignment_failed"
    end
    if old and old ~= model then old:Destroy() end
    player:SetAttribute("ER_RigType", "R6")
    spawning[player] = nil
    return true, nil
end

return Service
