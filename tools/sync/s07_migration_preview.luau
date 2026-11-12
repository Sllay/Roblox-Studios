-- Disposable integrated S07 migration preview. No save operation exists here.
local W=workspace
local T=W.Terrain
local F=W.RSResourcesP45.Models
local V=W.RSVegetationS06
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local function write(region,d)
    T:WriteVoxelChannels(region,4,{SolidMaterial=d.SolidMaterial,SolidOccupancy=d.SolidOccupancy,LiquidOccupancy=d.LiquidOccupancy})
end
assert(game.PlaceId==93428341652658 and #F:GetChildren()==216 and #cfg.rows==2000,"Target/count")
local before=terrainState()
for _,r in before do assert(cfg.terrainExpected[r.id]==r.digest,"Terrain baseline") end
local templates={}
for _,id in cfg.sources do
    local m=F:FindFirstChild(id);assert(m and m:IsA("Model"),"Source")
    templates[id]=m:Clone()
end
local old=F:GetChildren()
for _,m in old do m.Parent=nil end
local created={}
local counts={Branch=0,Stone=0}
for _,r in cfg.rows do
    local m=templates[r.source]:Clone()
    local p=m:FindFirstChildWhichIsA("MeshPart",true)
    assert(p and #m:GetDescendants()==1,"Single mesh source")
    m.Name=r.id;m:SetAttribute("RSManagedId",r.id)
    p:SetAttribute("RSManagedId",nil)
    m:SetAttribute("RSResourceType",if r.kind=="Branch" then "Stick" else "Stone")
    m:SetAttribute("RSResourceState","decorative")
    m:SetAttribute("RSResourceChunk",r.tile)
    m:SetAttribute("RSExpectedGroundY",r.groundY)
    m:SetAttribute("RSBuriedDepth",0)
    m:SetAttribute("RSContactMethod","native_terrain_ray")
    m:SetAttribute("RSSupportRadius",r.radius)
    p.Size=Vector3.new(table.unpack(r.size))
    p.CFrame=CFrame.new(table.unpack(r.frame))
    p.Anchored=true;p.CanCollide=true;p.CanQuery=true;p.CanTouch=false;p.CollisionGroup="RSNaturalResource"
    m.Parent=F;created[#created+1]=m;counts[r.kind]+=1
end
assert(counts.Branch==1000 and counts.Stone==1000,"Population")
local paint={}
local changed=0
for _,c in cfg.columns do
    local region=Region3.new(Vector3.new(c.x,-32,c.z),Vector3.new(c.x+4,112,c.z+4))
    local original=T:ReadVoxelChannels(region,4,channels)
    local d=T:ReadVoxelChannels(region,4,channels)
    for y=1,36 do
        assert(math.abs(d.SolidOccupancy[1][y][1]-c.solid[y])<.000001 and math.abs(d.LiquidOccupancy[1][y][1]-c.liquid[y])<.000001,"Occupancy changed")
        local target=Enum.Material[c.material[y]]
        if d.SolidMaterial[1][y][1]~=target then
            assert(target==Enum.Material.Grass and d.SolidMaterial[1][y][1]==Enum.Material.Ground,"Unexpected material delta")
            d.SolidMaterial[1][y][1]=target;changed+=1
        end
    end
    write(region,d);paint[#paint+1]={region=region,original=original}
end
local rotated={}
for _,m in V.Models:GetChildren() do
    if m:IsA("Model") then
        local pivot=m:GetPivot()
        local seed=73007;for i=1,#m.Name do seed=(seed*131+string.byte(m.Name,i))%2147483647 end
        local yaw=Random.new(seed):NextNumber(0,360)
        local target=CFrame.new(pivot.Position)*CFrame.Angles(0,math.rad(yaw),0)*pivot.Rotation
        local delta=target*pivot:Inverse()
        local saved={m=m,pivot=pivot,colliders={}}
        for _,name in {m.Name,m.Name.."-cap"} do
            local p=V.Collisions:FindFirstChild(name)
            if p then saved.colliders[#saved.colliders+1]={p=p,cf=p.CFrame};p.CFrame=delta*p.CFrame end
        end
        m:PivotTo(target);rotated[#rotated+1]=saved
    end
end
local op=OverlapParams.new();op.FilterType=Enum.RaycastFilterType.Include;op.FilterDescendantsInstances={F};op.MaxParts=0
for _,m in created do
    local p=m:FindFirstChildWhichIsA("MeshPart",true)
    for _,other in W:GetPartBoundsInBox(p.CFrame,p.Size,op) do assert(other==p,"Resource overlap "..m.Name) end
end
local after=terrainState()
for i,r in after do assert(r.solidVoxels==before[i].solidVoxels and r.waterVoxels==before[i].waterVoxels,"Terrain volume") end
for _,r in rotated do r.m:PivotTo(r.pivot);for _,c in r.colliders do c.p.CFrame=c.cf end end
for _,m in created do m:Destroy() end
for _,m in old do m.Parent=F end
for _,m in templates do m:Destroy() end
for _,r in paint do write(r.region,r.original) end
local restored=terrainState()
for i,r in restored do assert(r.digest==before[i].digest,"Terrain inverse") end
assert(#F:GetChildren()==216,"Resource inverse")
return syncResult({preview=true,noPlaceWrites=true,counts=counts,vegetationRotated=#rotated,restoredMaterialVoxels=changed,terrain=after,all49Restored=#restored==49,resourceInverse=true,clientRenderVerified=false})
