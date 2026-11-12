-- Independent persisted geometry, physics and source verification.
local W=workspace
local function v(a)return Vector3.new(table.unpack(a)) end
local function near(a,b,t)return (a-b).Magnitude<(t or .02) end
local function cf(a,b)
    local x,y={a:GetComponents()},{b:GetComponents()};for i=1,12 do if math.abs(x[i]-y[i])>.005 then return false end end;return true
end
local root=W:FindFirstChild("RSVegetationS06")
assert(root and root:GetAttribute("RSOwner")=="RSVegetationS06V1" and root:GetAttribute("RSPlanDigest")==cfg.planDigest,"Forest provenance")
assert(#root.Models:GetChildren()==212 and #root.Collisions:GetChildren()==264,"Forest count")
local trees,pines=0,0
for _,r in cfg.forest do
    local m=root.Models:FindFirstChild(r.id)
    assert(m and m:IsA("Model") and m:GetAttribute("RSManagedId")==r.id and m:GetAttribute("RSSpecies")==r.species,"Forest identity")
    assert(cf(m:GetPivot(),CFrame.new(table.unpack(r.pivot))) and math.abs(m:GetScale()-r.scale)<.001,"Forest pose")
    if r.action=="reuse" then
        local old=W:FindFirstChild(r.sourceRoot)
        local folder=if r.sourceRoot=="RSManagedAssets" then old else old:FindFirstChild("Models")
        assert(folder and not folder:FindFirstChild(r.id),"Old competing vegetation")
    end
    if r.collider then
        for _,pair in {{r.id,r.collider.shaft},{r.id.."-cap",r.collider.cap}} do
            local p=root.Collisions:FindFirstChild(pair[1]);local s=pair[2]
            assert(p and p:IsA("Part") and p.Shape.Name==s.shape and near(p.Size,v(s.size)) and near(p.Position,v(s.position)) and p.Anchored and p.CanCollide and p.CanQuery and not p.CanTouch and p.CollisionGroup==r.collider.group,"Tree collider")
            assert(cf(p.CFrame,CFrame.new(v(s.position))*(if s.rotation=="Z90" then CFrame.Angles(0,0,math.pi/2) else CFrame.identity)),"Collider orientation")
            assert(p.CustomPhysicalProperties and math.abs(p.CustomPhysicalProperties.Friction-.05)<.001,"Collider friction")
        end
        trees+=1
        if r.kind=="pine" then pines+=1 end
    end
end
local rf=W.RSResourcesP45.Models
assert(#rf:GetChildren()==216,"Resource count")
for _,r in cfg.resources do
    local m=rf:FindFirstChild(r.id);assert(m and m:IsA("Model") and m:GetAttribute("RSModelDigest")==r.sourceDigest,"Resource identity")
    local _,size=m:GetBoundingBox();assert(near(size,v(r.bounds)) and near(m:GetPivot().Position,v(r.position)),"Resource pose")
    local p=m:FindFirstChildWhichIsA("MeshPart",true)
    assert(p and p.Anchored and p.CanCollide and p.CanQuery and not p.CanTouch and p.CollisionGroup=="RSNaturalResource","Resource physical")
end
local api=if pcall(function()return W:GetRegisteredCollisionGroups()end) then W else game:GetService("PhysicsService")
assert(not api:CollisionGroupsAreCollidable("RSPlayerBody","RSNaturalResource") and api:CollisionGroupsAreCollidable("RSNaturalResource","RSNaturalResource") and api:CollisionGroupsAreCollidable("RSNaturalResource",W.Terrain.CollisionGroup) and api:CollisionGroupsAreCollidable("RSPlayerBody","Default"),"Persisted matrix")
local rocks=0
for _,m in W.RSEnvironmentP4Detail.Models:GetChildren() do
    if m:IsA("Model") and m:GetAttribute("RSSpecies")=="Mossy_Rock1_M_Mossy_Rock_0_Node" then
        for _,p in m:GetDescendants() do if p:IsA("MeshPart") then assert(p.CanCollide and p.CanQuery and p.CollisionGroup=="Default","Rock physical") end end
        rocks+=1
    end
end
for _,r in cfg.scripts do
    local parent=game:GetService(r.service);if r.folder then parent=parent:FindFirstChild(r.folder) end
    local s=parent:FindFirstChild(r.name);assert(s and s.ClassName==r.class and s.Source==r.source,"Script persisted")
end
local painted=0
for _,patch in cfg.patches do for _,c in patch.cells do
    local d=W.Terrain:ReadVoxelChannels(Region3.new(Vector3.new(c.x,-32,c.z),Vector3.new(c.x+4,112,c.z+4)),4,{"SolidMaterial","SolidOccupancy","LiquidOccupancy"})
    local top=0;for y=1,36 do assert(d.LiquidOccupancy[1][y][1]<=.02,"Wet");if d.SolidOccupancy[1][y][1]>.02 then top=y end end
    assert(top>0 and d.SolidMaterial[1][top][1]==Enum.Material.Ground and math.abs(-32+(top-1+d.SolidOccupancy[1][top][1])*4-c.height)<.001,"Paint persisted")
    painted+=1
end end
assert(trees==132 and pines==12 and rocks==6 and painted==144,"Counts")
return syncResult({verified=true,trees=trees,pines=pines,rocks=rocks,resources=216,painted=painted,collisionMatrix=true,noPlaceWrites=true,clientVerified=false})
