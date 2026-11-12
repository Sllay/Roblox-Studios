-- Independent persisted verification, no mutation or SavePlaceAsync.
local W=workspace
local function v(a)return Vector3.new(table.unpack(a)) end
local function near(a,b,t)return (a-b).Magnitude<(t or .005) end
local function sameCf(a,b)
    local x,y={a:GetComponents()},{b:GetComponents()}
    for i=1,12 do if math.abs(x[i]-y[i])>.005 then return false end end
    return true
end
local root=W:FindFirstChild("RSResourcesP45")
assert(root and root:GetAttribute("RSOwner")=="RSResourcesP45V1" and root:GetAttribute("RSPlanDigest")==cfg.planDigest,"Resource provenance")
local models=root:FindFirstChild("Models");assert(models and #models:GetChildren()==216,"Resource count")
local stones,sticks=0,0
for _,row in cfg.resources do
    local m=models:FindFirstChild(row.id)
    assert(m and m:IsA("Model") and m:GetAttribute("RSManagedId")==row.id and m:GetAttribute("RSModelDigest")==row.sourceDigest and m:GetAttribute("RSResourceState")=="decorative" and m:GetAttribute("RSFutureCollectible")==true,"Resource metadata")
    assert(sameCf(m:GetPivot(),CFrame.new(v(row.position))*CFrame.Angles(0,math.rad(row.yaw),0)),"Resource pivot")
    local _,size=m:GetBoundingBox();assert(near(size,v(row.bounds),.02),"Resource size")
    local meshes=0
    for _,o in m:GetDescendants() do
        assert(o:IsA("MeshPart") or o:IsA("SurfaceAppearance"),"Unsafe resource")
        if o:IsA("MeshPart") then
            meshes+=1
            assert(o.Anchored and not o.CanCollide and not o.CanTouch and not o.CanQuery,"Resource physics")
            if row.category=="stone" then assert(o.MeshId=="rbxassetid://122505516420043","Rock mesh")
            else assert(o.MeshId==cfg.stick.meshId and o.TextureID==cfg.stick.textureId,"Stick geometry") end
        end
    end
    assert(meshes==1,"Resource mesh count")
    if row.category=="stone" then stones+=1 else sticks+=1 end
end
for _,row in cfg.bushMoves do
    local m=W.RSEnvironmentP4.Models:FindFirstChild(row.id)
    assert(m and m:IsA("Model") and m:GetAttribute("RSModelDigest")==row.sourceDigest and near(m:GetPivot().Position,v(row.to),.01) and math.abs(m:GetScale()-row.scale)<.001,"Bush verification")
end
for _,row in cfg.colliders do
    local r=W:FindFirstChild(row.root);assert(r,"Tree root")
    local folder=r:FindFirstChild("Collisions");assert(folder,"Collision folder")
    for _,pair in {{row.id,row.shaft},{row.id.."-cap",row.cap}} do
        local p=folder:FindFirstChild(pair[1]);local s=pair[2]
        assert(p and p:IsA("Part") and p.Shape.Name==s.shape and near(p.Size,v(s.size)) and p.Anchored and p.CanCollide and p.CanQuery and not p.CanTouch and p.Transparency==1 and not p.CastShadow and p.CollisionGroup==row.collisionGroup,"Persisted collider")
        assert(sameCf(p.CFrame,CFrame.new(v(s.position))*(if s.rotation=="Z90" then CFrame.Angles(0,0,math.pi/2) else CFrame.identity)),"Collider transform")
        local phy=p.CustomPhysicalProperties
        assert(phy and math.abs(phy.Friction-.05)<.001 and phy.FrictionWeight==100 and phy.Elasticity==0,"Collider physical properties")
        assert(p:GetAttribute("RSTreeId")==row.id,"Collider identity")
    end
end
local wind=game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("RSWind")
assert(wind and wind:IsA("LocalScript") and wind.Source==cfg.windSource,"Wind source")
return syncResult({schemaVersion=1,verified=true,stones=stones,sticks=sticks,bushes=#cfg.bushMoves,treeProfiles=#cfg.colliders,physicalParts=2*#cfg.colliders,noPlaceWrites=true,runtimeVerified=false})
