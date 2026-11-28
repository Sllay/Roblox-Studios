--!strict
-- T1-R1 camera: perspective rendered from real 3D layers, never 2D parallax.
local RunService = game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Scenery=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("SceneryProfile"))
local Camera = {}
local enabled = false
local currentDistance = 88
local desiredDistance = 88
local conversationActor: Model?=nil

function Camera.focusActor(actor: Model?)
    conversationActor=actor
end

function Camera.setWide(wide: boolean)
    desiredDistance = if wide then Scenery.CAMERA_DISTANCE else 88
end

function Camera.start(player: Player)
    if enabled then return end
    enabled = true
    task.spawn(function()
        local lastChunk: number?=nil
        while player.Parent do
            local character=player.Character
            local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
            if root and root:IsA("BasePart") and workspace.StreamingEnabled
                and player:GetAttribute("ER_WorldLoaded")==true then
                local speed=player:GetAttribute("ER_TravelVelocity")
                local velocity=if type(speed)=="number" then speed else root.AssemblyLinearVelocity.X
                local ahead=root.Position+Vector3.new(math.clamp(velocity*2,-56,56),0,0)
                local chunk=math.floor((ahead.X+32)/64)
                if chunk~=lastChunk then
                    lastChunk=chunk
                    local streamed=pcall(function() player:RequestStreamAroundAsync(ahead,1.25) end)
                    if not streamed then lastChunk=nil end
                end
            end
            task.wait(0.8)
        end
    end)
    RunService:BindToRenderStep("ER_SideCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
        local camera = workspace.CurrentCamera
        if not camera then return end
        camera.CameraType = Enum.CameraType.Scriptable
        local aspect=camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y)
        local tangent=math.tan(math.rad(Scenery.VERTICAL_FOV/2))
        local field=math.deg(2*math.atan(tangent*math.min(1,Scenery.MAX_ASPECT/math.max(aspect,1))))
        if camera.FieldOfView~=field then camera.FieldOfView=field end
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
