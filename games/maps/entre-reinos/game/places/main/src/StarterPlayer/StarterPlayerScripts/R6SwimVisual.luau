--!strict
-- R6 classic does not guarantee distinct stock swim/swim-idle clips.
-- Native Humanoid state and physics remain responsible for swimming.
-- This applies an original, low-cost R6 fallback *visual* stroke only while
-- truly inside terrain water; never modifies rig parts or HumanoidRootPart.
local RunService=game:GetService("RunService")
local Visual={}
local character: Model?=nil
local swim=false
local phase=0
local links: {[string]: Motor6D}={}
local originalAnimate: LocalScript?=nil
local originalEnabled=false
local motors={"Right Shoulder","Left Shoulder","Right Hip","Left Hip","RootJoint"}

local function reset()
    for _,motor in pairs(links) do motor.Transform=CFrame.identity end
    if originalAnimate and originalAnimate.Parent and originalEnabled then
        originalAnimate.Enabled=true
    end
    swim=false
    phase=0
end

function Visual.attach(model: Model)
    reset()
    links={}
    character=model
    originalAnimate=nil
    originalEnabled=false
    local torso=model:FindFirstChild("Torso")
    local root=model:FindFirstChild("HumanoidRootPart")
    for _,name in ipairs(motors) do
        local parent=if name=="RootJoint" then root else torso
        local joint=if parent then parent:FindFirstChild(name) else nil
        if joint and joint:IsA("Motor6D") then links[name]=joint end
    end
    local animate=model:FindFirstChild("Animate")
    if animate and animate:IsA("LocalScript") then
        originalAnimate=animate
        originalEnabled=animate.Enabled
    end
end

function Visual.setActive(inWater: boolean)
    if inWater==swim then return end
    if not character then return end
    if inWater then
        -- Suppress walk/fall tracks in water when R6 has no distinct swim clip.
        -- The stock Animate script is turned back on when leaving the river.
        if originalAnimate and originalAnimate.Parent then
            originalEnabled=originalAnimate.Enabled
            originalAnimate.Enabled=false
        end
        local humanoid=character:FindFirstChildOfClass("Humanoid")
        local animator=if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
        if animator then
            for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
                if track.Priority==Enum.AnimationPriority.Core
                    or track.Priority==Enum.AnimationPriority.Movement
                    or track.Priority==Enum.AnimationPriority.Idle then
                    track:Stop(0.16)
                end
            end
        end
        swim=true
    else
        reset()
    end
end

-- Animation evaluation precedes PreSimulation; setting Transform here avoids
-- being overwritten by Animator in the same frame.
RunService.PreSimulation:Connect(function(dt: number)
    if not swim or not character then return end
    local h=character:FindFirstChildOfClass("Humanoid")
    if not h or h.Health<=0 then
        reset()
        return
    end
    phase+=math.min(dt,0.05)*8.2
    local stroke=math.sin(phase)
    local reverse=math.sin(phase+math.pi)
    local right=links["Right Shoulder"]
    local left=links["Left Shoulder"]
    local rightHip=links["Right Hip"]
    local leftHip=links["Left Hip"]
    local root=links.RootJoint
    if root then root.Transform=CFrame.Angles(-0.65,0,0) end
    if right then right.Transform=CFrame.Angles(-0.55+stroke*0.9,0,0.17) end
    if left then left.Transform=CFrame.Angles(-0.55+reverse*0.9,0,-0.17) end
    if rightHip then rightHip.Transform=CFrame.Angles(reverse*0.30,0,0) end
    if leftHip then leftHip.Transform=CFrame.Angles(stroke*0.30,0,0) end
end)

return Visual
