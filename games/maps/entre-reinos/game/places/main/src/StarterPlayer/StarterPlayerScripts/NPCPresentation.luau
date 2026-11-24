--!strict
-- Buffered client presentation of the authoritative lane. The visual clock
-- trails by approximately one packet, retaining speed through packet gaps.
local RunService=game:GetService("RunService")
local Presentation={}
local actors: {[Model]: any}={}
local active=false
local BUFFER=0.15
local MAX_LEAD=0.1

local function register(model: Model)
    if actors[model] or model:GetAttribute("ER_NPCVisual")~=true then return end
    local pose=model:GetAttribute("ER_NPCPose")
    if typeof(pose)~="Vector3" then return end
    local joints: {[string]: Motor6D}={}
    local aliases: {[string]: string}={
        ["Left Hip"]="leftLeg",["Right Hip"]="rightLeg",
        ["Left Shoulder"]="leftArm",["Right Shoulder"]="rightArm",
        ["ER_Left Leg"]="leftLeg",["ER_Right Leg"]="rightLeg",
        ["ER_Left Arm"]="leftArm",["ER_Right Arm"]="rightArm",
    }
    for _,joint in ipairs(model:GetDescendants()) do
        if joint:IsA("Motor6D") and aliases[joint.Name] then joints[aliases[joint.Name]]=joint end
    end
    local now=os.clock()
    actors[model]={from=pose,to=pose,position=pose,t0=now,t1=now,
        yaw=0,stride=0,motion=0,joints=joints,anchorY=pose.Y}
end

local function poseLimbs(item: any, activity: string, now: number)
    local stride=math.sin(item.stride)*item.motion
    local left,right=stride*0.34,-stride*0.34
    if activity=="collect" or activity=="build" then
        right=-0.9+math.sin(now*9)*0.72
        left=-0.34
    elseif activity=="load" then
        right=-0.78+math.sin(now*8)*0.16
        left=right
    elseif activity=="strike" then
        right=-1.06+math.sin(now*16)*0.33
        left=-0.55
    elseif activity=="stagger" then
        right=-0.8+math.sin(now*10)*0.25
        left=right
    elseif activity=="crown" then
        left=-0.42
        right=-0.42
    end
    local joints=item.joints
    if joints.leftArm then joints.leftArm.Transform=CFrame.Angles(left,0,0) end
    if joints.rightArm then joints.rightArm.Transform=CFrame.Angles(right,0,0) end
    if joints.leftLeg then joints.leftLeg.Transform=CFrame.Angles(-stride*0.46,0,0) end
    if joints.rightLeg then joints.rightLeg.Transform=CFrame.Angles(stride*0.46,0,0) end
end

function Presentation.start()
    if active then return end
    active=true
    local folder=workspace:WaitForChild("ER_LivingWorld",15)
    if not folder then active=false; return end
    for _,child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") then register(child) end
    end
    folder.ChildAdded:Connect(function(child)
        if child:IsA("Model") then task.defer(register,child) end
    end)
    folder.ChildRemoved:Connect(function(child)
        if child:IsA("Model") then actors[child]=nil end
    end)
    RunService.PreSimulation:Connect(function()
        local now=os.clock()
        for model,item in pairs(actors) do
            local activity=model:GetAttribute("ER_NPCActivity")
            poseLimbs(item,if type(activity)=="string" then activity else "",now)
        end
    end)
    RunService:BindToRenderStep("ER_NPCPresentation",Enum.RenderPriority.Last.Value,function(dt: number)
        local now=os.clock()
        local targetTime=now-BUFFER
        local step=math.clamp(dt,1/240,1/20)
        local blend=1-math.exp(-18*step)
        for model,item in pairs(actors) do
            local pose=model:GetAttribute("ER_NPCPose")
            if typeof(pose)~="Vector3" then continue end
            if pose~=item.to then
                item.from,item.t0=item.to,item.t1
                item.to,item.t1=pose,now
            end
            local velocity=model:GetAttribute("ER_NPCVelocityX")
            local speed=if type(velocity)=="number" then velocity else 0
            local fraction=math.clamp((targetTime-item.t0)/math.max(0.001,item.t1-item.t0),0,1)
            local buffered=item.from:Lerp(item.to,fraction)
            local lead=math.clamp(targetTime-item.t1,0,MAX_LEAD)
            local target=buffered+Vector3.new(speed*lead,0,0)
            local old: Vector3=item.position
            local position=if (target-old).Magnitude>12 then target else old:Lerp(target,blend)
            local travel=math.abs(old.X-position.X)
            item.stride=(item.stride+travel*2.2)%(2*math.pi)
            item.motion+=(math.min(1,travel/step/5)-item.motion)*blend
            item.position=position
            local facing=model:GetAttribute("ER_NPCFacing")
            if type(facing)=="number" then
                local difference=(facing-item.yaw+math.pi)%(2*math.pi)-math.pi
                item.yaw+=difference*blend
            end
            local activity=model:GetAttribute("ER_NPCActivity")
            local tilt=if activity=="fallen" then math.pi*0.46 else 0
            local render=CFrame.new(position)*CFrame.Angles(0,item.yaw,tilt)
            if render~=item.render then
                item.render=render
                model:PivotTo(item.render)
            end
        end
    end)
end
return Presentation
