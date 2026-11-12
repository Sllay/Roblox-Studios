-- Exact reviewed integrated staging transaction. No default-module deletion.
local W=workspace
local A=game:GetService("AssetService")
local T=W.Terrain
local function v(a)return Vector3.new(table.unpack(a)) end
local function near(a,b,t)return (a-b).Magnitude<(t or .02) end
local function canonical(x)
    if typeof(x)~="table" then return Http:JSONEncode(x) end
    local keys={};for k in x do table.insert(keys,k) end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
    local out={};for _,k in keys do table.insert(out,Http:JSONEncode(tostring(k))..":"..canonical(x[k])) end
    return "{"..table.concat(out,",").."}"
end
local function key(r)return if r.managedId~="" then "managed:"..r.managedId else r.service..":"..canonical(r.path) end
local function snapshot()
    local rows={};local total=0
    for _,name in cfg.services do
        local svc=game:GetService(name);local all=svc:GetDescendants();total+=#all
        assert(total<=6000,"Dedicated native inventory bound")
        for _,o in all do table.insert(rows,record(svc,o)) end
    end
    return {objects=rows,total=total,terrain=terrainState(),lighting=lightingState(),workspaceSettings=workspaceSettings()}
end
local function fingerprint(s)
    local hashes={};for _,r in s.objects do table.insert(hashes,hash(canonical(r))) end;table.sort(hashes)
    return hash(table.concat(hashes,";")..canonical(s.terrain)..canonical(s.lighting)..canonical(s.workspaceSettings))
end
local before=snapshot();local bf=fingerprint(before)
assert(before.total==cfg.baseTotal and cfg.mode~="apply" or before.total==cfg.baseTotal and bf==cfg.beforeFingerprint,"Baseline")
for _,r in before.terrain do assert(cfg.terrainExpected[r.id]==r.digest,"Terrain baseline") end
assert(not W:FindFirstChild("RSVegetationS06"),"Existing new root")
local detached={};local created={};local scriptRest={}
local function detach(o) table.insert(detached,{obj=o,parent=o.Parent});o.Parent=nil end
local function track(o) table.insert(created,o);return o end
local function modelAt(root,id)
    local r=W:FindFirstChild(root);assert(r,"Root")
    local folder=if root=="RSManagedAssets" then r else r:FindFirstChild("Models")
    local m=folder and folder:FindFirstChild(id)
    assert(m and m:IsA("Model") and m:GetAttribute("RSManagedId")==id,"Model "..id)
    return m,r
end
local function closeCF(a,b)
    local x,y={a:GetComponents()},{b:GetComponents()}
    for i=1,12 do if math.abs(x[i]-y[i])>.005 then return false end end
    return true
end
local templates={}
for _,r in cfg.forest do
    if not templates[r.sourceId] then
        local m,root=modelAt(r.sourceRoot,r.sourceId)
        assert(closeCF(m:GetPivot(),CFrame.new(table.unpack(r.sourcePivot))) and math.abs(m:GetScale()-r.sourceScale)<.001,"Tree source pose")
        templates[r.sourceId]={model=m,root=root}
    end
end
local new=track(Instance.new("Folder"));new.Name="RSVegetationS06";new:SetAttribute("RSOwner","RSVegetationS06V1");new:SetAttribute("RSPlanDigest",cfg.planDigest)
local models=Instance.new("Folder");models.Name="Models";models.Parent=new
local collisions=Instance.new("Folder");collisions.Name="Collisions";collisions.Parent=new
local function collider(r,s,name)
    local p=Instance.new("Part");p.Name=name;p.Shape=Enum.PartType[s.shape];p.Size=v(s.size)
    p.CFrame=CFrame.new(v(s.position))*(if s.rotation=="Z90" then CFrame.Angles(0,0,math.pi/2) else CFrame.identity)
    p.Anchored=true;p.CanCollide=true;p.CanQuery=true;p.CanTouch=false;p.Transparency=1;p.CastShadow=false;p.CollisionGroup=r.collider.group
    p.CustomPhysicalProperties=PhysicalProperties.new(1,.05,0,100,1);p:SetAttribute("RSOwner","RSVegetationS06V1");p:SetAttribute("RSTreeId",r.id)
    p.Parent=collisions;assert(near(p.Size,v(s.size)) and near(p.Position,v(s.position)),"Collider")
end
local reused=0;local treeCount=0
for _,r in cfg.forest do
    local src=templates[r.sourceId];local m=src.model:Clone();assert(m and 1+#m:GetDescendants()==r.sourceRecords,"Clone")
    m.Name=r.id;m:SetAttribute("RSManagedId",r.id);m:SetAttribute("RSSpecies",r.species)
    m:SetAttribute("RSExpectedGroundY",r.groundY);m:SetAttribute("RSSupportRadius",r.supportRadius);m:SetAttribute("RSChunk",r.tile)
    m:ScaleTo(r.scale);m:PivotTo(CFrame.new(table.unpack(r.pivot)))
    assert(closeCF(m:GetPivot(),CFrame.new(table.unpack(r.pivot))),"Tree pose")
    if r.action=="reuse" then
        detach(src.model);reused+=1
        if r.collider then
            local cf=src.root:FindFirstChild("Collisions");assert(cf,"Old collider folder")
            for _,name in {r.id,r.id.."-cap"} do local p=cf:FindFirstChild(name);assert(p and p:IsA("Part"),"Old collider");detach(p) end
        end
    end
    m.Parent=models
    if r.collider then collider(r,r.collider.shaft,r.id);collider(r,r.collider.cap,r.id.."-cap");treeCount+=1 end
end
assert(reused==138 and treeCount==132 and #models:GetChildren()==212,"Forest count")
new.Parent=W
local rf=W.RSResourcesP45.Models
for _,r in cfg.resources do
    local old=modelAt("RSResourcesP45",r.id)
    assert(old:GetAttribute("RSModelDigest")==r.sourceDigest and closeCF(old:GetPivot(),CFrame.new(table.unpack(r.sourcePivot))),"Resource source")
    local m=track(old:Clone());m:ScaleTo(r.targetScale);m:PivotTo(CFrame.new(v(r.position))*CFrame.Angles(0,math.rad(r.yaw),0))
    local _,size=m:GetBoundingBox();assert(near(size,v(r.bounds)),"Resource bounds")
    m:SetAttribute("RSExpectedGroundY",r.groundY);m:SetAttribute("RSBuriedDepth",r.burial);m:SetAttribute("RSSupportRadius",math.max(.5,r.radius));m:SetAttribute("RSResourceChunk",r.tile)
    detach(old);m.Parent=rf
end
-- Persist visual collision flags and the exact collision matrix via reviewed server policy.
-- __RS_PHYSICS__
local api=configure(W)
local stones,sticks,rocks=applyResources(W)
assert(stones==108 and sticks==108 and rocks==6,"Physical resource counts")
local paint={}
for _,patch in cfg.patches do for _,cell in patch.cells do
    local region=Region3.new(Vector3.new(cell.x,-32,cell.z),Vector3.new(cell.x+4,112,cell.z+4))
    local d=T:ReadVoxelChannels(region,4,{"SolidMaterial","SolidOccupancy","LiquidOccupancy"})
    local top=0;for y=1,36 do assert(d.LiquidOccupancy[1][y][1]<=.02,"Wet column");if d.SolidOccupancy[1][y][1]>.02 then top=y end end
    assert(top>0 and d.SolidMaterial[1][top][1]==Enum.Material.Grass and math.abs(-32+(top-1+d.SolidOccupancy[1][top][1])*4-cell.height)<.001,"Paint baseline")
    local below=top>1 and d.SolidMaterial[1][top-1][1]==Enum.Material.Grass
    d.SolidMaterial[1][top][1]=Enum.Material.Ground;if below then d.SolidMaterial[1][top-1][1]=Enum.Material.Ground end
    T:WriteVoxelChannels(region,4,{SolidMaterial=d.SolidMaterial,SolidOccupancy=d.SolidOccupancy,LiquidOccupancy=d.LiquidOccupancy})
    table.insert(paint,{region=region,d=d,top=top,below=below})
end end
for _,r in cfg.scripts do
    local parent=game:GetService(r.service);if r.folder then parent=parent:FindFirstChild(r.folder) end
    assert(parent,"Script parent")
    local o=parent:FindFirstChild(r.name)
    if r.beforeHash then
        assert(o and o.ClassName==r.class and hash(o.Source)==r.beforeHash,"Script source "..r.name)
        table.insert(scriptRest,{obj=o,source=o.Source});o.Source=r.source
    else
        assert(not o,"Script already exists");o=track(Instance.new(r.class));o.Name=r.name;o.Source=r.source;o.Parent=parent
    end
end
local after=snapshot();local af=fingerprint(after)
assert(after.total+cfg.cloneReserve+500<=6000,"Dedicated budget")
local oldMap,newMap={},{}
for _,r in before.objects do oldMap[key(r)]=r end
for _,r in after.objects do newMap[key(r)]=r end
local changed,removed={},{}
for k,r in newMap do if not oldMap[k] or canonical(r)~=canonical(oldMap[k]) then table.insert(changed,r) end end
for k,r in oldMap do if not newMap[k] then table.insert(removed,{service=r.service,path=r.path,managedId=r.managedId}) end end
local tiles=0
for i,r in after.terrain do
    assert(r.solidVoxels==before.terrain[i].solidVoxels and r.waterVoxels==before.terrain[i].waterVoxels,"Terrain volume")
    if r.digest~=before.terrain[i].digest then tiles+=1 end
end
assert(tiles==9 and #paint==144,"Paint scope")
if cfg.mode=="preview" then
    -- Restore all physical changes on preserved original objects as well.
    -- __RS_RESTORE_PHYSICS__
    for _,r in paint do
        r.d.SolidMaterial[1][r.top][1]=Enum.Material.Grass;if r.below then r.d.SolidMaterial[1][r.top-1][1]=Enum.Material.Grass end
        T:WriteVoxelChannels(r.region,4,{SolidMaterial=r.d.SolidMaterial,SolidOccupancy=r.d.SolidOccupancy,LiquidOccupancy=r.d.LiquidOccupancy})
    end
    for _,r in scriptRest do r.obj.Source=r.source end
    for _,o in created do o:Destroy() end
    for _,r in detached do r.obj.Parent=r.parent end
    local restored=snapshot()
    assert(fingerprint(restored)==bf,"Exact inverse mismatch")
    return syncResult({preview=true,noPlaceWrites=true,beforeFingerprint=bf,afterFingerprint=af,afterTotal=after.total,changed=changed,removed=removed,terrain=after.terrain,lighting=after.lighting,workspaceSettings=after.workspaceSettings,inverseVerified=true,forest=212,trees=132,resources=216,tiles=tiles,planDigest=cfg.planDigest})
end
assert(cfg.mode=="apply" and cfg.confirmStaging and af==cfg.afterFingerprint,"Reviewed apply")
A:SavePlaceAsync({SaveWithoutPublish=false})
return syncResult({saved=true,planDigest=cfg.planDigest,afterFingerprint=af,afterTotal=after.total})
