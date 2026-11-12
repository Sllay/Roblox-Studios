--!strict
-- First-party procedural visuals; no external scripts, remote requires or physics.
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local module=ReplicatedStorage:WaitForChild("RSWindPolicy",15)
if not module or not module:IsA("ModuleScript") then return end
local Policy=require(module)
local player=Players.LocalPlayer
local roots={RSSceneBuilder="RSSceneBuilderV1",RSWorldVegetation="RSWorldV1",RSEnvironmentP4="RSEnvironmentP4V1",RSEnvironmentP4Detail="RSEnvironmentP4DetailV1",RSManagedAssets="RobloxStudiosStaticV1"}
local diagnostic=Instance.new("Folder")
diagnostic.Name="RSWindDiagnostics";diagnostic.Parent=player
type Entry={part:MeshPart,rest:CFrame,pivot:Vector3,phase:number,bush:boolean,active:boolean}
local entries:{[MeshPart]:Entry}={}
local function eligible(part:MeshPart): boolean
    return part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery
end
local function scan()
    local seen:{[MeshPart]:boolean}={}
    for name,owner in roots do
        local root=Workspace:FindFirstChild(name)
        if not root or root:GetAttribute("RSOwner")~=owner then continue end
        local models=if name=="RSManagedAssets" then root else root:FindFirstChild("Models")
        if not models then continue end
        for _,model in models:GetChildren() do
            if not model:IsA("Model") then continue end
            local asset=model:GetAttribute("RSAssetId")
            if typeof(asset)~="string" then continue end
            local species=model:GetAttribute("RSSpecies")
            if typeof(species)~="string" then
                local id=model:GetAttribute("RSManagedId")
                if id=="yasu-tree-01" then species="Tree_01"
                elseif typeof(id)=="string" then
                    local lower=string.match(id,"^forest%-([a-z]+_%d+)%-%d+$")
                    if lower then species=string.upper(string.sub(lower,1,1))..string.sub(lower,2) end
                end
            end
            if typeof(species)~="string" then continue end
            local bush=string.sub(species,1,4)=="Bush"
            for _,obj in model:GetChildren() do
                if not obj:IsA("MeshPart") or not eligible(obj) then continue end
                -- Only audited per-species canopy names + authored foliage material.
                -- Unknown mesh layouts fail closed; never infer from height alone.
                if not Policy.foliage(asset,species,obj.Name,obj.Material.Name,obj.MeshId) then continue end
                seen[obj]=true
                if not entries[obj] then
                    local rest=obj.CFrame
                    entries[obj]={part=obj,rest=rest,pivot=rest.Position-Vector3.yAxis*(obj.Size.Y*0.34),
                        phase=Policy.phase(rest.Position.X,rest.Position.Z),bush=bush,active=false}
                end
            end
        end
    end
    local count=0
    for _ in seen do count+=1 end
    diagnostic:SetAttribute("Eligible",count)
    for part,e in entries do
        if not seen[part] then
            if e.active and part:IsDescendantOf(Workspace) and eligible(part) then part.CFrame=e.rest end
            entries[part]=nil
        end
    end
end
local folder=Instance.new("Folder")
folder.Name="RSLocalWindVisuals"
folder.Parent=Workspace
type Line={part:Part,trail:Trail,age:number,life:number,position:Vector3,speed:number}
local lines:{Line}={}
local rng=Random.new()
for _=1,6 do
    local part=Instance.new("Part")
    part.Name="WindLine";part.Size=Vector3.new(0.1,0.1,0.1)
    part.Transparency=1;part.Anchored=true;part.CanCollide=false
    part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
    local a=Instance.new("Attachment");a.Position=Vector3.new(0,0.09,0);a.Parent=part
    local b=Instance.new("Attachment");b.Position=Vector3.new(0,-0.09,0);b.Parent=part
    local trail=Instance.new("Trail");trail.Attachment0=a;trail.Attachment1=b
    trail.Color=ColorSequence.new(Color3.fromRGB(205,231,237))
    trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.90),NumberSequenceKeypoint.new(0.25,0.64),NumberSequenceKeypoint.new(1,1)})
    trail.WidthScale=NumberSequence.new(1,0);trail.Lifetime=0.45
    trail.MinLength=0.15;trail.FaceCamera=true;trail.LightInfluence=0;trail.Enabled=false
    trail.Parent=part;part.Parent=folder
    table.insert(lines,{part=part,trail=trail,age=0,life=0,position=Vector3.zero,speed=1})
end
local function resetLine(line:Line,center:Vector3,direction:Vector3)
    line.trail.Enabled=false;line.trail:Clear()
    local right=direction:Cross(Vector3.yAxis)
    line.position=center-direction*rng:NextNumber(12,32)+right*rng:NextNumber(-24,24)+Vector3.yAxis*rng:NextNumber(2,8)
    line.part.CFrame=CFrame.new(line.position)
    line.age=0;line.life=rng:NextNumber(1.7,3.0);line.speed=rng:NextNumber(0.8,1.3)
    line.trail.Enabled=true
end
local scanElapsed=2
local elapsed=0
local connection:RBXScriptConnection?
connection=RunService.Heartbeat:Connect(function(dt)
    scanElapsed+=dt;elapsed+=dt
    if scanElapsed>=2 then scanElapsed=0;scan() end
    if elapsed<Policy.updateInterval then return end
    local step=math.min(elapsed,0.12);elapsed=0
    local camera=Workspace.CurrentCamera
    local character=player.Character
    local hrp=character and character:FindFirstChild("HumanoidRootPart")
    local wind=Workspace.GlobalWind
    local horizontal=Vector3.new(wind.X,0,wind.Z)
    local strength=horizontal.Magnitude
    local center=if camera then camera.CFrame.Position else nil
    local direction=if strength>0.01 then horizontal.Unit else Vector3.xAxis
    local active:{Entry}={}
    if center then
        for part,e in entries do
            if part:IsDescendantOf(Workspace) and eligible(part) and (e.rest.Position-center).Magnitude<Policy.radius and strength>0.01 then
                table.insert(active,e)
            end
        end
        local c=center
        table.sort(active,function(a,b) return (a.rest.Position-c).Magnitude<(b.rest.Position-c).Magnitude end)
    end
    local selected:{[MeshPart]:boolean}={}
    local parts:{BasePart}={}
    local frames:{CFrame}={}
    local now=Workspace:GetServerTimeNow()
    local axis=Vector3.yAxis:Cross(direction)
    if center then
        for i=1,math.min(#active,Policy.maxActive) do
            local e=active[i];selected[e.part]=true;e.active=true
            local angle=Policy.angle(now,e.phase,strength,(e.rest.Position-center).Magnitude,e.bush)
            local tilt=CFrame.fromAxisAngle(axis,angle)
            table.insert(parts,e.part)
            table.insert(frames,CFrame.new(e.pivot)*tilt*CFrame.new(-e.pivot)*e.rest)
        end
    end
    for part,e in entries do
        if e.active and not selected[part] then
            e.active=false
            if part:IsDescendantOf(Workspace) and eligible(part) then
                table.insert(parts,part);table.insert(frames,e.rest)
            end
        end
    end
    if #parts>0 then Workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged) end
    diagnostic:SetAttribute("Active",math.min(#active,Policy.maxActive))
    diagnostic:SetAttribute("WindStrength",strength)
    for _,line in lines do
        if not hrp or not hrp:IsA("BasePart") or strength<0.01 then
            line.trail.Enabled=false;line.life=0
            continue
        end
        line.age+=step
        if line.age>=line.life or (line.position-hrp.Position).Magnitude>65 then resetLine(line,hrp.Position,direction) end
        line.position+=direction*math.min(strength*1.4,24)*line.speed*step
        line.part.CFrame=CFrame.new(line.position)
    end
end)
script.Destroying:Connect(function()
    if connection then connection:Disconnect() end
    for part,e in entries do
        if e.active and part:IsDescendantOf(Workspace) and eligible(part) then part.CFrame=e.rest end
    end
    folder:Destroy()
    diagnostic:Destroy()
end)
