--!strict
-- Use the Roblox joystick, jump and Humanoid swimming controller unchanged.
-- Entre Reinos only remaps 2.5D input: on land X walks, in native water
-- joystick forward/backward becomes Humanoid:Move's vertical Y direction.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Projection = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("InputProjection"))
local Controller = {}

local active = false
local controls: any = nil
local humanoid: Humanoid? = nil
local turn: AlignOrientation? = nil
local lastFacing = -math.pi / 2

local function attachCharacter(character: Model)
    humanoid = nil
    if turn then turn:Destroy() end
    turn = nil
    local h = character:WaitForChild("Humanoid", 10)
    local r = character:WaitForChild("HumanoidRootPart", 10)
    if not h or not h:IsA("Humanoid") or not r or not r:IsA("BasePart") then return end
    local attachment = r:WaitForChild("ER_LaneAttachment", 10)
    if not attachment or not attachment:IsA("Attachment") then
        warn("[EntreReinos] Missing server-owned XY lane constraint")
        return
    end
    humanoid = h
    h.AutoRotate = false
    h.WalkSpeed = 13

    local orientation = Instance.new("AlignOrientation")
    orientation.Name = "ER_TurnSmooth"
    orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orientation.Attachment0 = attachment
    orientation.RigidityEnabled = false
    orientation.Responsiveness = 20
    orientation.MaxTorque = 100000
    orientation.CFrame = CFrame.Angles(0, lastFacing, 0)
    orientation.Parent = r
    turn = orientation
end

local function readNativeInput(h: Humanoid): (number, number)
    if controls and type(controls.GetMoveVector) == "function" then
        local ok, vector = pcall(function()
            return controls:GetMoveVector()
        end)
        if ok and typeof(vector) == "Vector3" then
            return Projection.toLane(vector.X, vector.Z)
        end
    end
    local motion = h.MoveDirection
    return Projection.toLane(motion.X, motion.Z)
end

local function update(_dt: number)
    local h = humanoid
    local o = turn
    if not h or not o or h.Health <= 0 then return end
    local x, y = readNativeInput(h)
    local swimming = h:GetState() == Enum.HumanoidStateType.Swimming

    -- Native Roblox Humanoid controls all water physics, transitions,
    -- buoyancy and the character's own Animate script. No LinearVelocity,
    -- manual ChangeState, Motor6D transforms, or animation suppression.
    -- Y remap is only sent while Roblox itself reports Swimming.
    h:Move(Vector3.new(x, if swimming then y else 0, 0), false)
    lastFacing = Projection.facing(x, y, swimming, lastFacing)
    o.CFrame = CFrame.Angles(0, lastFacing, 0)
    -- Leave jump and native Swimming state fully owned by Roblox.
end

function Controller.start(player: Player)
    if active then return end
    active = true
    local scripts = player:WaitForChild("PlayerScripts")
    local playerModule = scripts:WaitForChild("PlayerModule", 8)
    if playerModule then
        local ok, module = pcall(require, playerModule)
        if ok and module and type(module.GetControls) == "function" then
            controls = module:GetControls()
        else
            warn("[EntreReinos] PlayerModule unavailable; using Humanoid.MoveDirection")
        end
    else
        warn("[EntreReinos] PlayerModule missing; using native Humanoid.MoveDirection")
    end
    player.CharacterAdded:Connect(attachCharacter)
    if player.Character then task.spawn(attachCharacter, player.Character) end
    RunService:BindToRenderStep("ER_Lane", Enum.RenderPriority.Input.Value + 1, update)
end

function Controller.mode(): string
    if not active then return "Menu" end
    if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Swimming then
        return "Swim"
    end
    return "Ground"
end

return Controller
