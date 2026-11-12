-- Reviewed S06.7 staging-only resource transaction. No live terrain rebuild.
local W=workspace
local T=W.Terrain
local F=W.RSResourcesP45.Models
local A=game:GetService("AssetService")
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local function v(a)return Vector3.new(table.unpack(a)) end
local function canonical(x)
    if typeof(x)~="table" then return Http:JSONEncode(x) end
    local keys={};for k in x do table.insert(keys,k) end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    local out={};for _,k in keys do table.insert(out,Http:JSONEncode(tostring(k))..":"..canonical(x[k])) end
    return "{"..table.concat(out,",").."}"
end
local function key(r)return if r.managedId~="" then "managed:"..r.managedId else r.service..":"..canonical(r.path) end
local function snapshot()
    local rows={};local total=0
    for _,name in cfg.services do
        local svc=game:GetService(name);local all=svc:GetDescendants();total+=#all
        assert(total<=6000,"Native inventory bound")
        for _,o in all do table.insert(rows,record(svc,o)) end
    end
    return {objects=rows,total=total,terrain=terrainState(),lighting=lightingState(),workspaceSettings=workspaceSettings()}
end
local function fingerprint(s)
    local hashes={};for _,r in s.objects do table.insert(hashes,hash(canonical(r))) end;table.sort(hashes)
    return hash(table.concat(hashes,";")..canonical(s.terrain)..canonical(s.lighting)..canonical(s.workspaceSettings))
end
local function write(region,d)
    T:WriteVoxelChannels(region,4,{SolidMaterial=d.SolidMaterial,SolidOccupancy=d.SolidOccupancy,LiquidOccupancy=d.LiquidOccupancy})
end
local function verifyTerrain(rows,expected)
    assert(#rows==49,"Terrain count")
    for _,r in rows do assert(expected[r.id]==r.digest,"Terrain digest "..r.id) end
end
local function pose(m,r,after)
    local want=after and r.to or r.from
    assert((m:GetPivot().Position-v(want)).Magnitude<.005,"Resource position "..r.id)
    assert(math.abs(m:GetScale()-(after and r.targetScale or r.oldScale))<.00001,"Resource scale "..r.id)
    assert(m:GetAttribute("RSManagedId")==r.id and m:GetAttribute("RSResourceType")== (r.category=="stone" and "Stone" or "Stick"),"Resource identity")
    local part=m:FindFirstChildWhichIsA("MeshPart",true)
    assert(part and part.Anchored and part.CanCollide and part.CanQuery and part.CollisionGroup=="RSNaturalResource","Resource policy")
    if after then
        assert(m:GetAttribute("RSBuriedDepth")==0 and m:GetAttribute("RSContactMethod")=="native_terrain_ray" and math.abs(m:GetAttribute("RSExpectedGroundY")-r.groundY)<.001,"Resource support metadata")
    end
end
assert(game.PlaceId==93428341652658 and #cfg.rows==216 and #F:GetChildren()==216,"Target or resource count")
if cfg.mode=="verify" then
    -- Historical read-only session: rehydrate only exact existing channels, no SavePlaceAsync.
    local initial=terrainState();verifyTerrain(initial,cfg.expectedTerrain)
    for _,p in cfg.patches do
        local x,z=p.center[1],p.center[2]
        local region=Region3.new(Vector3.new(x-12,-32,z-12),Vector3.new(x+12,112,z+12))
        local original=T:ReadVoxelChannels(region,4,channels)
        local empty=T:ReadVoxelChannels(region,4,channels)
        for i=1,6 do for j=1,36 do for k=1,6 do
            empty.SolidMaterial[i][j][k]=Enum.Material.Air;empty.SolidOccupancy[i][j][k]=0;empty.LiquidOccupancy[i][j][k]=0
        end end end
        write(region,empty);write(region,original)
    end
    task.wait(1)
    local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances={T};ray.RespectCanCollide=true;ray.IgnoreWater=false
    local op=OverlapParams.new();op.FilterType=Enum.RaycastFilterType.Include;op.FilterDescendantsInstances={F}
    local hits,stones,sticks,rotated=0,0,0,0
    local maxGap=0
    for _,r in cfg.rows do
        local m=F:FindFirstChild(r.id);assert(m and m:IsA("Model"),"Missing resource")
        pose(m,r,true)
        local cf,s=m:GetBoundingBox()
        local e=(math.abs(cf.RightVector.Y)*s.X+math.abs(cf.UpVector.Y)*s.Y+math.abs(cf.LookVector.Y)*s.Z)/2
        local bottom=cf.Position.Y-e;local low,high=math.huge,-math.huge
        for _,a in {{0,0},{-.42,0},{.42,0},{0,-.42},{0,.42}} do
            local p=cf:PointToWorldSpace(Vector3.new(a[1]*s.X,0,a[2]*s.Z))
            local h=W:Raycast(p+Vector3.yAxis*40,-Vector3.yAxis*100,ray)
            assert(h and h.Instance==T and h.Material~=Enum.Material.Water and h.Material~=Enum.Material.Grass,"Dry physical support "..r.id)
            low=math.min(low,h.Position.Y);high=math.max(high,h.Position.Y);hits+=1
        end
        assert(bottom-high>=.005 and bottom-high<=.025 and bottom-low<.22,"Persisted contact "..r.id)
        maxGap=math.max(maxGap,bottom-low)
        for _,part in W:GetPartBoundsInBox(cf,s,op) do
            local other=part:FindFirstAncestorOfClass("Model")
            assert(not other or other==m or other.Parent~=F,"Persisted overlap "..r.id)
        end
        if r.category=="stone" then stones+=1 else sticks+=1 end
        if r.yawAdjustment~=0 then rotated+=1 end
    end
    verifyTerrain(terrainState(),cfg.expectedTerrain)
    return syncResult({verified=true,noPlaceWrites=true,stones=stones,sticks=sticks,hits=hits,rotated=rotated,maxGap=maxGap,all49Restored=true,clientRenderVerified=false})
end
assert(cfg.mode=="preview" or cfg.mode=="apply","Mode")
local before=snapshot();local bf=fingerprint(before)
assert(before.total==cfg.baseTotal,"Inventory baseline")
if cfg.mode=="apply" then assert(cfg.confirmStaging and bf==cfg.beforeFingerprint,"Reviewed baseline") end
verifyTerrain(before.terrain,cfg.terrainExpected)
local paint={}
for _,r in cfg.extraPaint do
    local region=Region3.new(Vector3.new(r.x,-32,r.z),Vector3.new(r.x+4,112,r.z+4))
    local original=T:ReadVoxelChannels(region,4,channels)
    local d=T:ReadVoxelChannels(region,4,channels)
    for y=1,36 do assert(d.LiquidOccupancy[1][y][1]<=.02,"Wet paint column") end
    for _,y in r.indices do
        assert(d.SolidMaterial[1][y][1]==Enum.Material.Grass,"Paint baseline")
        d.SolidMaterial[1][y][1]=Enum.Material.Ground
    end
    write(region,d);table.insert(paint,{region=region,original=original})
end
local originals,clones={},{}
for _,r in cfg.rows do
    local old=F:FindFirstChild(r.id);assert(old and old:IsA("Model"),"Missing resource")
    pose(old,r,false)
    local pivot=old:GetPivot();local m=old:Clone();assert(m,"Clone")
    m:ScaleTo(r.targetScale)
    m:PivotTo(CFrame.new(v(r.to))*CFrame.Angles(0,math.rad(r.yawAdjustment),0)*pivot.Rotation)
    m:SetAttribute("RSVoxelGroundY",r.voxelGroundY)
    m:SetAttribute("RSExpectedGroundY",r.groundY)
    m:SetAttribute("RSBuriedDepth",0);m:SetAttribute("RSContactMethod","native_terrain_ray")
    local radius=old:GetAttribute("RSSupportRadius")
    assert(typeof(radius)=="number" and radius>0,"Support radius")
    m:SetAttribute("RSSupportRadius",radius*r.scaleRatio)
    table.insert(originals,old);old.Parent=nil
    m.Parent=F;table.insert(clones,m)
    pose(m,r,true)
end
local after=snapshot();local af=fingerprint(after)
assert(after.total==before.total,"Inventory count changed")
verifyTerrain(after.terrain,cfg.expectedTerrain)
for i,r in after.terrain do
    assert(r.solidVoxels==before.terrain[i].solidVoxels and r.waterVoxels==before.terrain[i].waterVoxels,"Terrain volume")
end
local oldMap,newMap={},{}
for _,r in before.objects do oldMap[key(r)]=r end
for _,r in after.objects do newMap[key(r)]=r end
local changed,removed={},{}
for k,r in newMap do if not oldMap[k] or canonical(r)~=canonical(oldMap[k]) then table.insert(changed,r) end end
for k,r in oldMap do if not newMap[k] then table.insert(removed,{service=r.service,path=r.path,managedId=r.managedId}) end end
assert(#removed==0,"Removed records")
if cfg.mode=="preview" then
    for _,m in clones do m:Destroy() end
    for _,m in originals do m.Parent=F end
    for _,r in paint do write(r.region,r.original) end
    assert(fingerprint(snapshot())==bf,"Exact inverse")
    return syncResult({noPlaceWrites=true,inverseVerified=true,beforeFingerprint=bf,afterFingerprint=af,afterTotal=after.total,changed=changed,removed=removed,terrain=after.terrain,lighting=after.lighting,workspaceSettings=after.workspaceSettings})
end
assert(af==cfg.afterFingerprint,"Reviewed after state")
A:SavePlaceAsync({SaveWithoutPublish=false})
return syncResult({saved=true,afterFingerprint=af,afterTotal=after.total})
