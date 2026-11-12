-- Physical death: preserve body connectivity on both legacy and AJU rigs.
-- No anchoring, teleporting, or manually loading a replacement character.
local Ragdoll={}
local function bodyPart(character,part)
    return part and part:IsA("BasePart") and part.Parent==character
end
local function rootJoint(a,b)
    return a.Name=="HumanoidRootPart" or b.Name=="HumanoidRootPart"
end
local function pair(character,a,b)
    return bodyPart(character,a) and bodyPart(character,b) and not rootJoint(a,b)
end
local function jointLimits(name)
    if string.find(name,"Neck") then return 35,35 end
    if string.find(name,"Waist") then return 40,30 end
    if string.find(name,"Elbow") or string.find(name,"Knee") then return 75,15 end
    if string.find(name,"Wrist") or string.find(name,"Ankle") then return 40,25 end
    return 70,45
end
function Ragdoll.prepare(humanoid)
    humanoid.BreakJointsOnDeath=false
end
function Ragdoll.activate(character,humanoid,group)
    if character:FindFirstChild("RSRagdollPhysics") then return nil end
    assert(humanoid.BreakJointsOnDeath==false,"Ragdoll must be prepared before death")
    humanoid.RequiresNeck=false
    humanoid.AutoRotate=false
    humanoid.PlatformStand=true
    local folder=Instance.new("Folder");folder.Name="RSRagdollPhysics";folder.Parent=character
    local sockets,motors,animations,colliders=0,0,0,0
    local known={}
    local function mark(a,b)
        known[a]=known[a] or {};known[b]=known[b] or {}
        known[a][b]=true;known[b][a]=true
    end
    local function has(a,b) return known[a] and known[a][b] end
    local function socket(name,a,b,frame)
        local a0=Instance.new("Attachment");a0.Name="RSRagdoll_"..name;a0.CFrame=a.CFrame:ToObjectSpace(frame);a0.Parent=a
        local a1=Instance.new("Attachment");a1.Name="RSRagdoll_"..name;a1.CFrame=b.CFrame:ToObjectSpace(frame);a1.Parent=b
        local c=Instance.new("BallSocketConstraint");c.Name="RSJoint_"..name;c.Attachment0=a0;c.Attachment1=a1
        local cone,twist=jointLimits(name)
        c.LimitsEnabled=true;c.UpperAngle=cone;c.TwistLimitsEnabled=true;c.TwistLowerAngle=-twist;c.TwistUpperAngle=twist
        c.MaxFrictionTorque=3;c.Parent=folder;mark(a,b);sockets+=1
    end
    local descendants=character:GetDescendants()
    -- AJU already has anatomically configured BallSocketConstraints.
    for _,j in descendants do
        if j:IsA("BallSocketConstraint") and j.Attachment0 and j.Attachment1 then
            local a,b=j.Attachment0.Parent,j.Attachment1.Parent
            if pair(character,a,b) then j.Enabled=true;mark(a,b);sockets+=1 end
        end
    end
    for _,j in descendants do
        if j:IsA("Motor6D") and pair(character,j.Part0,j.Part1) then
            local a,b=j.Part0,j.Part1
            if not has(a,b) then socket(j.Name,a,b,b.CFrame*j.C1) end
            j.Enabled=false;motors+=1
        elseif j:IsA("AnimationConstraint") and j.Attachment0 and j.Attachment1 then
            local a,b=j.Attachment0.Parent,j.Attachment1.Parent
            if pair(character,a,b) then
                if not has(a,b) then socket(j.Name,a,b,j.Attachment1.WorldCFrame) end
                j.IsKinematic=false;j.MaxForce=0;j.MaxTorque=0;j.Enabled=false;animations+=1
            end
        end
    end
    -- Root joint stays connected to the torso, not to the world. Do not
    -- modify accessory welds or add collision to cosmetic accessories.
    local animator=humanoid:FindFirstChildOfClass("Animator")
    if animator then for _,track in animator:GetPlayingAnimationTracks() do track:Stop(0) end end
    for _,limb in character:GetChildren() do
        if limb:IsA("BasePart") then
            limb.CanCollide=false;limb.CollisionGroup=group
            if limb.Name~="HumanoidRootPart" and not limb.Anchored then
                local proxy=Instance.new("Part");proxy.Name="RSBody_"..limb.Name
                proxy.Size=Vector3.new(math.max(0.15,limb.Size.X*0.9),math.max(0.15,limb.Size.Y*0.9),math.max(0.15,limb.Size.Z*0.9))
                proxy.CFrame=limb.CFrame;proxy.Transparency=1;proxy.CanCollide=true;proxy.CanQuery=false;proxy.CanTouch=false
                proxy.CastShadow=false;proxy.Massless=true;proxy.CollisionGroup=group;proxy.Parent=folder
                local weld=Instance.new("WeldConstraint");weld.Part0=limb;weld.Part1=proxy;weld.Parent=proxy
                colliders+=1
            end
        end
    end
    return {sockets=sockets,motors=motors,animations=animations,colliders=colliders,
        rig=if animations>0 then "AJU" elseif motors>0 then "Motor6D" else "unknown"}
end
return Ragdoll
