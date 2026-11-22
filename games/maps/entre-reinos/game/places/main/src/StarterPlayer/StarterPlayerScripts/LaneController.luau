--!strict
-- T1-R1: use Roblox's ORIGINAL joystick, jump button, keyboard and gamepad.
-- Do not bind touch buttons, disable PlayerModule, or override native jump.
-- Only project the standard movement vector onto our physics-driven XY lane.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Projection = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("InputProjection"))
local Water = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("WaterRules"))
local SwimVisual = require(script.Parent:WaitForChild("R6SwimVisual"))
local Controller = {}

local active = false
local controls: any = nil
local root: BasePart? = nil
local humanoid: Humanoid? = nil
local turn: AlignOrientation? = nil
local swim: LinearVelocity? = nil
local swimFiltered = Vector2.zero
local lastSwimming = -1e9
local lastStateRequest = -1e9
local currentSeed: number? = nil
local swimmingVisual=false
local lastFacing = -math.pi / 2

local function cleanCharacter()
    root = nil
    humanoid = nil
    turn = nil
    swim = nil
    swimFiltered = Vector2.zero
    swimmingVisual=false
    SwimVisual.setActive(false)
end

local function attachCharacter(character: Model)
    cleanCharacter()
    local h = character:WaitForChild("Humanoid", 10)
    local r = character:WaitForChild("HumanoidRootPart", 10)
    if not h or not h:IsA("Humanoid") or not r or not r:IsA("BasePart") then return end
    local attachment = r:WaitForChild("ER_LaneAttachment", 10)
    if not attachment or not attachment:IsA("Attachment") then
        warn("[EntreReinos] Missing server-owned XY lane constraint")
        return
    end
    humanoid = h
    root = r
    SwimVisual.attach(character)
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

    local velocity = Instance.new("LinearVelocity")
    velocity.Name = "ER_SwimXY"
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
    velocity.PrimaryTangentAxis = Vector3.xAxis
    velocity.SecondaryTangentAxis = Vector3.yAxis
    velocity.MaxForce = 100000
    velocity.ForceLimitsEnabled = false
    velocity.PlaneVelocity = Vector2.zero
    velocity.Enabled = false
    velocity.Parent = r
    swim = velocity
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
    -- Robust fallback for changed/missing PlayerModule implementations:
    -- the Roblox default controller still drives Humanoid.MoveDirection.
    local motion = h.MoveDirection
    return Projection.toLane(motion.X, motion.Z)
end

local function update(dt: number)
    local h = humanoid
    local r = root
    local o = turn
    local v = swim
    if not h or not r or not o or not v or h.Health <= 0 then return end
    local x, y = readNativeInput(h)
    local now=os.clock()
    local state=h:GetState()
    local inWaterNow=state==Enum.HumanoidStateType.Swimming
    if currentSeed==nil then
        local id=game:GetService("Players").LocalPlayer:GetAttribute("ER_Seed")
        if type(id)=="number" then currentSeed=id end
    end
    local volumeWet=currentSeed~=nil
        and Water.submerged(currentSeed,r.Position.X,r.Position.Y,r.Position.Z)
    if inWaterNow or volumeWet then lastSwimming=now end
    local swimming=inWaterNow or volumeWet or (now-lastSwimming<0.18)
    -- Humanoid state can transition to Freefall at voxel boundaries.
    -- Request the real Roblox Swimming state only while actually submerged.
    if volumeWet and not inWaterNow and now-lastStateRequest>0.55 then
        lastStateRequest=now
        h:ChangeState(Enum.HumanoidStateType.Swimming)
    end
    if swimmingVisual~=swimming then
        swimmingVisual=swimming
        SwimVisual.setActive(swimming)
    end
    if swimming then
        -- Native joystick up/down becomes upward/downward water movement.
        -- A diagonal thumbstick gesture is a normalized diagonal X/Y swim.
        local target = Vector2.new(x, y) * 12
        swimFiltered = swimFiltered:Lerp(target, 1 - math.exp(-8 * math.min(dt, 0.1)))
        v.PlaneVelocity = swimFiltered
        v.Enabled = true
        h:Move(Vector3.zero, false)
    else
        v.Enabled = false
        swimFiltered = Vector2.zero
        -- On land, X moves and Y only turns the character toward/away from
        -- the 3D background. Never allow an independent Z walking direction.
        h:Move(Vector3.new(x, 0, 0), false)
    end
    lastFacing = Projection.facing(x, y, swimming, lastFacing)
    o.CFrame = CFrame.Angles(0, lastFacing, 0)
    -- Native Roblox TouchJump/spacebar/gamepad jump are handled by PlayerModule.
    -- We deliberately do not write Humanoid.Jump here.
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
            -- NEVER call controls:Disable(): that hides Roblox joystick/jump.
            -- The native control module remains enabled.
        else
            warn("[EntreReinos] PlayerModule unavailable; using Humanoid.MoveDirection")
        end
    else
        warn("[EntreReinos] PlayerModule missing; using native Humanoid.MoveDirection")
    end
    player.CharacterAdded:Connect(attachCharacter)
    if player.Character then task.spawn(attachCharacter, player.Character) end
    -- PlayerModule's normal control step runs at Input priority. Project its
    -- analog movement one step later, while retaining its jump handling.
    RunService:BindToRenderStep("ER_Lane", Enum.RenderPriority.Input.Value + 1, update)
end

function Controller.mode(): string
    if not active then return "Menu" end
    if swimmingVisual then
        return "Swim"
    end
    return "Ground"
end

return Controller
