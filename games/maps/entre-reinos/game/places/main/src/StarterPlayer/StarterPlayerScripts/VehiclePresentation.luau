--!strict
local RunService=game:GetService("RunService")
local Presentation={}
local started=false
type AnimatedRig={joints: {Motor6D}, phase: number, rowing: boolean}

function Presentation.start()
    if started then return end
    local world=workspace:WaitForChild("ER_LivingWorld",20)
    local folder=if world then world:WaitForChild("ER_Travel",20) else nil
    if not folder then return end
    started=true
    local rigs: {[Model]: AnimatedRig}={}
    local function watch(instance: Instance)
        if not instance:IsA("Model") then return end
        local kind=instance:GetAttribute("ER_GaitKind")
        if kind~="mount" and kind~="boat" then return end
        local joints: {Motor6D}={}
        for _,descendant in ipairs(instance:GetDescendants()) do
            if descendant:IsA("Motor6D") then
                local index=descendant:GetAttribute("ER_GaitIndex")
                if type(index)=="number" then joints[index]=descendant end
            end
        end
        rigs[instance]={joints=joints,phase=0,rowing=kind=="boat"}
    end
    for _,child in ipairs(folder:GetChildren()) do watch(child) end
    folder.ChildAdded:Connect(watch)
    folder.ChildRemoved:Connect(function(instance)
        if instance:IsA("Model") then rigs[instance]=nil end
    end)
    RunService.PreSimulation:Connect(function(dt)
        local view=workspace.CurrentCamera
        if not view then return end
        for model,rig in pairs(rigs) do
            if (model:GetPivot().Position-view.CFrame.Position).Magnitude>220 then continue end
            local speed=model:GetAttribute("ER_GaitSpeed")
            if type(speed)~="number" then continue end
            local gain=math.clamp(math.abs(speed)/10,0,1)
            rig.phase+=math.min(dt,0.05)*math.abs(speed)*1.5
            for index,joint in ipairs(rig.joints) do
                if rig.rowing then
                    local side=if index==1 then -1 else 1
                    joint.Transform=CFrame.Angles(math.cos(rig.phase)*gain*0.16,
                        side*math.sin(rig.phase)*gain*0.38,0)
                else
                    local leg=math.ceil(index/2)
                    local cycle=rig.phase+(if leg==1 or leg==4 then 0 else math.pi)
                    local angle=if index%2==1 then math.sin(cycle)*gain*0.54
                        else math.max(0,math.cos(cycle))*gain*0.68
                    joint.Transform=CFrame.Angles(angle,0,0)
                end
            end
        end
    end)
end

return Presentation
