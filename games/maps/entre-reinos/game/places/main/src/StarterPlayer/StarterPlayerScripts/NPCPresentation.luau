--!strict
-- Buffered client presentation of the authoritative lane. The visual clock
-- trails by approximately one packet, retaining speed through packet gaps.
local RunService=game:GetService("RunService")
local Presentation={}
local actors: {[Model]: any}={}
local active=false
local BUFFER=0.15
local MAX_LEAD=0.1
-- Official Roblox classic R6 tracks, only for real R6 Humanoid rigs.
-- Never replace their Motor6D.Transform in the custom presentation pass.
local R6_IDLE="rbxassetid://180435571"
local R6_WALK="rbxassetid://180426354"
local R6_TOOL_SLASH="rbxassetid://129967390"

local function loadTrack(animator: Animator,id: string,priority: Enum.AnimationPriority,
        looped: boolean): AnimationTrack?
    local animation=Instance.new("Animation")
    animation.AnimationId=id
    local ok,track=pcall(function(): AnimationTrack
        return animator:LoadAnimation(animation)
    end)
    animation:Destroy()
    if not ok or not track then return nil end
    track.Priority=priority
    track.Looped=looped
    return track
end

local function updateNative(item: any,activity: string,speed: number,now: number)
    local idle=item.idleTrack
    local walk=item.walkTrack
    if not idle or not walk then return end
    if activity=="fallen" then
        if idle.IsPlaying then idle:Stop(0.15) end
        if walk.IsPlaying then walk:Stop(0.15) end
        item.animState=""
        return
    end
    local moving=speed>0.18
    if item.animState~=(if moving then "walking" else "idle") then
        item.animState=if moving then "walking" else "idle"
        if moving then
            idle:Stop(0.2)
            walk:Play(0.2)
        else
            walk:Stop(0.2)
            idle:Play(0.2)
        end
    end
    if moving then walk:AdjustSpeed(math.clamp(speed/7,0.45,1.6)) end
    if (activity=="collect" or activity=="build" or activity=="fabricate" or activity=="farm" or activity=="hunt" or activity=="load" or activity=="strike" or activity=="stagger")
        and now-(item.lastAction or 0)>0.75 and item.actionTrack then
        item.lastAction=now
        item.actionTrack:Play(0.09)
    end
end

local function register(model: Model)
    if actors[model] or model:GetAttribute("ER_NPCVisual")~=true then return end
    local pose=model:GetAttribute("ER_NPCPose")
    if typeof(pose)~="Vector3" then return end
    local now=os.clock()
    local isNative=model:GetAttribute("ER_NativeR6")==true
    local idleTrack: AnimationTrack?=nil
    local walkTrack: AnimationTrack?=nil
    local actionTrack: AnimationTrack?=nil
    if isNative then
        local h=model:FindFirstChildOfClass("Humanoid")
        local animator=if h then h:FindFirstChildOfClass("Animator") else nil
        if animator and animator:IsA("Animator") then
            idleTrack=loadTrack(animator,R6_IDLE,Enum.AnimationPriority.Idle,true)
            walkTrack=loadTrack(animator,R6_WALK,Enum.AnimationPriority.Movement,true)
            actionTrack=loadTrack(animator,R6_TOOL_SLASH,Enum.AnimationPriority.Action,false)
        end
    end
    actors[model]={from=pose,to=pose,position=pose,t0=now,t1=now,
        yaw=0,
        native=isNative,idleTrack=idleTrack,walkTrack=walkTrack,
        actionTrack=actionTrack,animState="",lastAction=0}
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
        if not child:IsA("Model") then return end
        local actor=actors[child]
        if actor then
            for _,key in ipairs({"idleTrack","walkTrack","actionTrack"}) do
                if actor[key] then actor[key]:Destroy() end
            end
            actors[child]=nil
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
            local velocityZ=model:GetAttribute("ER_NPCVelocityZ")
            local speed=if type(velocity)=="number" then velocity else 0
            local speedZ=if type(velocityZ)=="number" then velocityZ else 0
            local fraction=math.clamp((targetTime-item.t0)/math.max(0.001,item.t1-item.t0),0,1)
            local buffered=item.from:Lerp(item.to,fraction)
            local lead=math.clamp(targetTime-item.t1,0,MAX_LEAD)
            local target=buffered+Vector3.new(speed*lead,0,speedZ*lead)
            local old: Vector3=item.position
            local position=if (target-old).Magnitude>12 then target else old:Lerp(target,blend)
            local travel=(Vector2.new(old.X,old.Z)
                -Vector2.new(position.X,position.Z)).Magnitude
            local actualSpeed=travel/step
            if item.native then
                local activity=model:GetAttribute("ER_NPCActivity")
                updateNative(item,if type(activity)=="string" then activity else "",
                    actualSpeed,now)
            end
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
