--!strict
-- T1-R1: physics-driven XY lane, context actions for keyboard/gamepad/touch.
-- The server creates a PlaneConstraint with Z-normal; no per-frame CFrame teleport.
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Controller = {}

local actions = {
    ER_Left = {Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.DPadLeft},
    ER_Right = {Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight},
    ER_Up = {Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.DPadUp},
    ER_Down = {Enum.KeyCode.S, Enum.KeyCode.Down, Enum.KeyCode.DPadDown},
    ER_Jump = {Enum.KeyCode.Space, Enum.KeyCode.ButtonA},
}
local labels = {ER_Left = "◀", ER_Right = "▶", ER_Up = "▲", ER_Down = "▼", ER_Jump = "Pular"}
local positions = {
    ER_Left = UDim2.new(0, 65, 1, -112),
    ER_Right = UDim2.new(0, 155, 1, -112),
    ER_Up = UDim2.new(1, -176, 1, -196),
    ER_Down = UDim2.new(1, -176, 1, -106),
    ER_Jump = UDim2.new(1, -82, 1, -118),
}
local pressed: {[string]: boolean} = {}
local active = false
local playerRef: Player? = nil
local root: BasePart? = nil
local humanoid: Humanoid? = nil
local turn: AlignOrientation? = nil
local swim: LinearVelocity? = nil
local swimFiltered = Vector2.zero
local lastSwimming = -1e9
local lastFacing = -math.pi / 2

local function cleanCharacter()
    root = nil
    humanoid = nil
    turn = nil
    swim = nil
    swimFiltered = Vector2.zero
end

local function attachCharacter(character: Model)
    cleanCharacter()
    local h = character:WaitForChild("Humanoid", 10)
    local r = character:WaitForChild("HumanoidRootPart", 10)
    if not h or not h:IsA("Humanoid") or not r or not r:IsA("BasePart") then return end
    local laneAttachment = r:WaitForChild("ER_LaneAttachment", 10)
    if not laneAttachment or not laneAttachment:IsA("Attachment") then
        warn("[EntreReinos] Missing server-owned XY lane constraint")
        return
    end
    humanoid = h
    root = r
    h.AutoRotate = false
    h.WalkSpeed = 13

    local orientation = Instance.new("AlignOrientation")
    orientation.Name = "ER_TurnSmooth"
    orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orientation.Attachment0 = laneAttachment
    orientation.RigidityEnabled = false
    orientation.Responsiveness = 20
    orientation.MaxTorque = 100000
    orientation.CFrame = CFrame.Angles(0, lastFacing, 0)
    orientation.Parent = r
    turn = orientation

    local velocity = Instance.new("LinearVelocity")
    velocity.Name = "ER_SwimXY"
    velocity.Attachment0 = laneAttachment
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

local function handleAction(name: string, input: Enum.UserInputState, _inputObject: InputObject)
    if not active then return Enum.ContextActionResult.Pass end
    if input == Enum.UserInputState.Begin then
        pressed[name] = true
        if name == "ER_Jump" and humanoid then
            humanoid.Jump = true
        end
    elseif input == Enum.UserInputState.End or input == Enum.UserInputState.Cancel then
        pressed[name] = false
    end
    return Enum.ContextActionResult.Sink
end

local function startBindings()
    for name, keys in pairs(actions) do
        ContextActionService:BindActionAtPriority(name, handleAction, true, 2200, table.unpack(keys))
        ContextActionService:SetTitle(name, labels[name])
        ContextActionService:SetPosition(name, positions[name])
    end
end

local function update(dt: number)
    local h = humanoid
    local r = root
    local o = turn
    local v = swim
    if not h or not r or not o or not v or h.Health <= 0 then return end
    local x = (if pressed.ER_Right then 1 else 0) - (if pressed.ER_Left then 1 else 0)
    local y = (if pressed.ER_Up then 1 else 0) - (if pressed.ER_Down then 1 else 0)
    local inWaterNow = h:GetState() == Enum.HumanoidStateType.Swimming
    if inWaterNow then lastSwimming = os.clock() end
    local swimming = inWaterNow or (os.clock() - lastSwimming < 0.22)
    if swimming then
        local raw = Vector2.new(x, y)
        if raw.Magnitude > 1 then raw = raw.Unit end
        local target = raw * 12
        swimFiltered = swimFiltered:Lerp(target, 1 - math.exp(-8 * math.min(dt, 0.1)))
        v.PlaneVelocity = swimFiltered
        v.Enabled = true
        h:Move(Vector3.zero, false)
    else
        v.Enabled = false
        swimFiltered = Vector2.zero
        h:Move(Vector3.new(x, 0, 0), false)
    end
    if x > 0 then
        lastFacing = -math.pi / 2
    elseif x < 0 then
        lastFacing = math.pi / 2
    elseif not swimming and y > 0 then
        lastFacing = 0
    elseif not swimming and y < 0 then
        lastFacing = math.pi
    end
    o.CFrame = CFrame.Angles(0, lastFacing, 0)
end

function Controller.start(player: Player)
    if active then return end
    active = true
    playerRef = player
    local scripts = player:WaitForChild("PlayerScripts")
    local playerModule = scripts:WaitForChild("PlayerModule", 8)
    if playerModule then
        local success, module = pcall(require, playerModule)
        if success and module and type(module.GetControls) == "function" then
            module:GetControls():Disable()
        else
            warn("[EntreReinos] Default PlayerModule could not be disabled")
        end
    end
    startBindings()
    player.CharacterAdded:Connect(attachCharacter)
    if player.Character then task.spawn(attachCharacter, player.Character) end
    RunService:BindToRenderStep("ER_Lane", Enum.RenderPriority.Input.Value + 1, update)
end

function Controller.mode(): string
    if not active then return "Menu" end
    if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Swimming then return "Swim" end
    return "Ground"
end

return Controller
