-- First-party deterministic policy probe; no LocalScript execution, no writes.
local module=game:GetService("ReplicatedStorage"):FindFirstChild("RSWindPolicy")
assert(module and module:IsA("ModuleScript") and module.Source==cfg.policySource,"Published wind policy changed")
-- __RS_WIND_POLICY__
local counts={};local eligible=0;local flags=0;local unmapped=0
local roots={"RSSceneBuilder","RSWorldVegetation","RSEnvironmentP4","RSEnvironmentP4Detail","RSManagedAssets"}
local function species(m)
    local s=m:GetAttribute("RSSpecies")
    if typeof(s)=="string" then return s end
    local id=m:GetAttribute("RSManagedId")
    if id=="yasu-tree-01" then return "Tree_01" end
    if typeof(id)=="string" then
        local a=string.match(id,"^forest%-([a-z]+_%d+)%-%d+$")
        if a then return string.upper(string.sub(a,1,1))..string.sub(a,2) end
    end
    return ""
end
for _,name in roots do
    local r=workspace:FindFirstChild(name);assert(r,"Root")
    local models=if name=="RSManagedAssets" then r else r:FindFirstChild("Models")
    assert(models,"Models")
    for _,m in models:GetChildren() do
        if not m:IsA("Model") then continue end
        local sp=species(m);local asset=m:GetAttribute("RSAssetId")
        for _,obj in m:GetChildren() do
            if not obj:IsA("MeshPart") then continue end
            if not (obj.Anchored and not obj.CanCollide and not obj.CanTouch and not obj.CanQuery) then flags+=1;continue end
            if not Policy.foliage(asset,sp,obj.Name,obj.Material.Name,obj.MeshId) then unmapped+=1;continue end
            eligible+=1;counts[sp]=(counts[sp] or 0)+1
        end
    end
end
local peakTree,peakBush=0,0
local direction=Vector3.new(1,0,0)
local axis=Vector3.yAxis:Cross(direction)
local maxPivotDrift=0
for i=0,240 do
    local t=i/30
    local a=Policy.angle(t,0,8.5,10,false);local b=Policy.angle(t,0,8.5,10,true)
    peakTree=math.max(peakTree,math.deg(a));peakBush=math.max(peakBush,math.deg(b))
    local pivot=Vector3.new(1,2,3)
    local tf=CFrame.new(pivot)*CFrame.fromAxisAngle(axis,a)*CFrame.new(-pivot)
    maxPivotDrift=math.max(maxPivotDrift,(tf:PointToWorldSpace(pivot)-pivot).Magnitude)
    assert((tf:PointToWorldSpace(pivot+Vector3.yAxis*5)-pivot).X>=-0.00001,"Wind direction")
end
assert(peakTree>1 and peakTree<=3.00001 and peakBush>0.5 and peakBush<=1.50001,"Wind amplitude")
assert(Policy.angle(0,0,0,0,false)==0 and Policy.angle(0,0,8.5,Policy.radius,false)==0,"Wind fade")
assert(maxPivotDrift<0.00001,"Pivot drift")
return syncResult({schemaVersion=1,eligible=eligible,counts=counts,flagRejected=flags,unmapped=unmapped,peakTreeDegrees=peakTree,peakBushDegrees=peakBush,maxPivotDrift=maxPivotDrift,maxActive=Policy.maxActive,updateInterval=Policy.updateInterval,noPlaceWrites=true,clientMotionVerified=false})
