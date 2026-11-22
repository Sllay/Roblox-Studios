--!strict
-- T1-R2: visual-only 60 Hz NPC presentation. The server remains authoritative
-- for positions, work, resources and saves. These R6 rigs have no collisions.
-- A 10 Hz replicated position is insufficient for visible motion on mobile:
-- interpolate and slightly extrapolate between authoritative pose snapshots.
local RunService=game:GetService("RunService")
local Presentation={}
local active=false
local actors: {[Model]: any}={}
local R6_WALK="rbxassetid://180426354" -- official classic R6 walk loop

local function remove(model: Model)
    local entry=actors[model]
    if not entry then return end
    if entry.walk then
        entry.walk:Stop(0.1)
        entry.walk:Destroy()
    end
    actors[model]=nil
end

local function findModel(inst: Instance): Model?
    if inst:IsA("Model") and inst:GetAttribute("ER_NPCVisual")==true then
        return inst
    end
    return nil
end

local function register(model: Model)
    if actors[model] then return end
    local pose=model:GetAttribute("ER_NPCPose")
    if typeof(pose)~="Vector3" then return end
    local hum=model:FindFirstChildOfClass("Humanoid")
    local track: AnimationTrack?=nil
    if hum then
        local animator=hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator=Instance.new("Animator")
            animator.Parent=hum
        end
        local clip=Instance.new("Animation")
        clip.Name="ER_StockR6Walk"
        clip.AnimationId=R6_WALK
        local ok,loaded=pcall(function() return animator:LoadAnimation(clip) end)
        if ok and loaded then
            track=loaded
            track.Priority=Enum.AnimationPriority.Movement
            track.Looped=true
        else
            warn("[EntreReinos][NPCPresentation] Stock R6 walk unavailable: ",loaded)
        end
        clip:Destroy()
    end
    actors[model]={
        render=CFrame.new(pose),
        snapshot=pose,
        arrivedAt=os.clock(),
        walk=track,
    }
    model.Destroying:Connect(function() remove(model) end)
end

function Presentation.start()
    if active then return end
    active=true
    local folder=workspace:WaitForChild("ER_LivingWorld",15)
    if not folder then
        warn("[EntreReinos] NPC world folder not replicated")
        return
    end
    for _,child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("ER_NPCVisual")==true then
            register(child)
        end
    end
    folder.ChildAdded:Connect(function(child)
        if child:IsA("Model") then task.defer(register,child) end
    end)
    folder.ChildRemoved:Connect(function(child)
        if child:IsA("Model") then remove(child) end
    end)
    RunService:BindToRenderStep("ER_NPCPresentation",Enum.RenderPriority.Last.Value, function(dt: number)
        local t=os.clock()
        for model,item in pairs(actors) do
            if model.Parent~=folder then
                remove(model)
                continue
            end
            local pose=model:GetAttribute("ER_NPCPose")
            if typeof(pose)~="Vector3" then continue end
            if pose~=item.snapshot then
                item.snapshot=pose
                item.arrivedAt=t
            end
            local velocity=model:GetAttribute("ER_NPCVelocityX")
            if type(velocity)~="number" then velocity=0 end
            local facing=model:GetAttribute("ER_NPCFacing")
            if type(facing)~="number" then facing=0 end
            -- Limit extrapolation to one server snapshot interval, avoiding
            -- runaway on network stalls or when a worker stops for a job.
            local ahead=math.clamp(t-item.arrivedAt,0,0.13)
            local predicted=pose+Vector3.new(velocity*ahead,0,0)
            local desired=CFrame.new(predicted)*CFrame.Angles(0,facing,0)
            local blend=1-math.exp(-17*math.clamp(dt,0,0.10))
            if (item.render.Position-desired.Position).Magnitude>10 then
                -- Teleport/streaming recovery, not normal NPC movement.
                item.render=desired
            else
                item.render=item.render:Lerp(desired,blend)
            end
            model:PivotTo(item.render)
            local track=item.walk
            if track then
                local moving=math.abs(velocity)>0.35
                if moving and not track.IsPlaying then track:Play(0.15,1,1) end
                if moving then
                    track:AdjustSpeed(math.clamp(math.abs(velocity)/6,0.6,1.5))
                elseif track.IsPlaying then
                    track:Stop(0.18)
                end
            end
        end
    end)
end
return Presentation
