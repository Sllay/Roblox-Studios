--!strict
-- T1-R1 camera: perspective rendered from real 3D layers, never 2D parallax.
local RunService = game:GetService("RunService")
local Camera = {}
local enabled = false
local currentDistance = 88
local desiredDistance = 88
local conversationActor: Model?=nil

function Camera.focusActor(actor: Model?)
    conversationActor=actor
end

function Camera.setWide(wide: boolean)
    desiredDistance = if wide then 118 else 88
end

function Camera.start(player: Player)
    if enabled then return end
    enabled = true
    RunService:BindToRenderStep("ER_SideCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
        local camera = workspace.CurrentCamera
        if not camera then return end
        camera.CameraType = Enum.CameraType.Scriptable
        camera.FieldOfView = 46
        local talking=conversationActor~=nil and conversationActor.Parent~=nil
        local distance=if talking then 30 else desiredDistance
        currentDistance += (distance - currentDistance) * (1 - math.exp(-5 * math.min(dt, 0.1)))
        local character = player.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        if not root or not root:IsA("BasePart") then return end
        local p = root.Position
        local actor=conversationActor
        local aim=if talking and actor then (p+actor:GetPivot().Position)/2 else p
        local focus = Vector3.new(aim.X, aim.Y + (if talking then 0.5 else 7), if talking then -0.5 else -10)
        local targetCamera = CFrame.lookAt(
            Vector3.new(aim.X, aim.Y + (if talking then 3 else 14), currentDistance),
            focus
        )
        local alpha = 1 - math.exp(-7 * math.min(dt, 0.1))
        camera.CFrame = camera.CFrame:Lerp(targetCamera, alpha)
        camera.Focus = CFrame.new(focus)
    end)
end

return Camera
