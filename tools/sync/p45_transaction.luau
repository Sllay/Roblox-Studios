-- Dedicated coupled P4.5 transaction. Preview mutates only disposable edit session.
local scenePathFor=pathFor
-- __RS_ROCK_HELPERS__
-- __RS_STICK_HELPER__
local W=workspace
local function v(a)return Vector3.new(table.unpack(a)) end
local function near(a,b,t)return (a-b).Magnitude<(t or 0.005) end
local function digestBuffer(b)return buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(b,Enum.HashAlgorithm.Sha256))) end
local function cfAt(row)return CFrame.new(v(row.position))*CFrame.Angles(0,math.rad(row.yaw),0)*(if row.orientation=="Z90" then CFrame.Angles(0,0,math.pi/2) else CFrame.identity) end
local function getModel(rootName,id)
    local root=W:FindFirstChild(rootName);assert(root,"Root missing")
    local models=if rootName=="RSManagedAssets" then root else root:FindFirstChild("Models")
    local m=models and models:FindFirstChild(id)
    assert(m and m:IsA("Model") and m:GetAttribute("RSManagedId")==id,"Model identity "..id)
    return m,root
end
assert(cfg.mode=="preview" or cfg.mode=="apply","Operation mode")
assert(cfg.environment=="staging" and cfg.placeId=="93428341652658" and cfg.universeId=="10769712441","Staging scope")
assert(not W:FindFirstChild("RSResourcesP45"),"Resource root exists")
-- The independent caller compares the entire observed baseline before dispatch.
-- Exact targeted preconditions and terrain hashes also run inside the task.
local terrain=terrainState()
for _,r in terrain do assert(cfg.terrainExpected[r.id]==r.digest,"Terrain changed "..r.id) end
assert(#terrain==49,"Terrain scope")
local function canonicalValue(v)
    if typeof(v)~="table" then return Http:JSONEncode(v) end
    local keys={}
    for k in v do table.insert(keys,k) end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
    local out={}
    for _,k in keys do table.insert(out,Http:JSONEncode(tostring(k))..":"..canonicalValue(v[k])) end
    return "{"..table.concat(out,",").."}"
end
local function fingerprint(state)
    local hashes={}
    for _,r in state.objects do table.insert(hashes,hash(canonicalValue(r))) end
    table.sort(hashes)
    return hash(table.concat(hashes,";")..canonicalValue(state.terrain)..canonicalValue(state.lighting)..canonicalValue(state.workspaceSettings))
end
local before=inventory()
local beforeFingerprint=fingerprint(before)
if cfg.mode=="apply" then assert(beforeFingerprint==cfg.beforeFingerprint,"Native baseline changed") end
local backups={}
local function backup(obj,svc)
    local path=scenePathFor(game:GetService(svc),obj)
    local blob=Serial:SerializeInstancesAsync({obj})
    local copies=Serial:DeserializeInstancesAsync(blob)
    assert(#copies==1 and copies[1].ClassName==obj.ClassName and copies[1].Name==obj.Name,"Backup roundtrip")
    local c=copies[1]
    assert(#c:GetDescendants()==#obj:GetDescendants(),"Backup hierarchy")
    if obj:IsA("BasePart") then assert(c.Size==obj.Size and near(c.Position,obj.Position) and c.CollisionGroup==obj.CollisionGroup,"Backup collider") end
    if obj:IsA("Model") then assert(near(c:GetPivot().Position,obj:GetPivot().Position) and math.abs(c:GetScale()-obj:GetScale())<.001,"Backup model") end
    if obj:IsA("LuaSourceContainer") then assert(c.Source==obj.Source,"Backup script") end
    c:Destroy()
    table.insert(backups,{service=svc,path=path,digest=digestBuffer(blob),serializedBase64=buffer.tostring(Encoding:Base64Encode(blob))})
end
local pack=Assets:LoadAssetAsync(tonumber(cfg.rock.assetId))
assert(pack:IsA("Model") and pack.Parent==nil,"Detached rock pack")
local src=pack
for _,seg in cfg.rock.selector do
    local child=src:GetChildren()[seg.index]
    assert(child and child.Name==seg.name and child.ClassName==seg.class,"Rock selector");src=child
end
assert(src:IsA("Model"),"Rock source")
local rock=src:Clone();assert(rock and rock.Parent==nil,"Rock clone")
local ra=audit(rock)
local _,rd=serialize(rock);assert(rd==cfg.rock.sourceDigest,"Rock source digest")
fetchDependencies(rock,ra)
local rockScale=rock:GetScale()
local bb=rock:GetBoundingBox();rock.PrimaryPart=nil;rock.WorldPivot=CFrame.new(bb.Position);rock:PivotTo(CFrame.identity)
pack:Destroy()
local stick=extractStick()
local newRoot=Instance.new("Folder");newRoot.Name="RSResourcesP45";newRoot:SetAttribute("RSOwner","RSResourcesP45V1");newRoot:SetAttribute("RSPlanDigest",cfg.planDigest)
local models=Instance.new("Folder");models.Name="Models";models.Parent=newRoot
local tags=game:GetService("CollectionService")
local function clean(m)
    for _,o in {m,table.unpack(m:GetDescendants())} do
        assert(o:IsA("Model") or o:IsA("MeshPart") or o:IsA("SurfaceAppearance"),"Unsafe resource class")
        for k in o:GetAttributes() do o:SetAttribute(k,nil) end
        for _,tag in tags:GetTags(o) do tags:RemoveTag(o,tag) end
        if o:IsA("BasePart") then o.Anchored=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false;o.CastShadow=false end
    end
end
local function resourceMeta(m,row)
    m.Name=row.id;m:SetAttribute("RSManagedId",row.id);m:SetAttribute("RSAssetId",row.assetId);m:SetAttribute("RSModelDigest",row.sourceDigest)
    m:SetAttribute("RSSpecies",if row.category=="stone" then "Rock" else "Stick")
    m:SetAttribute("RSResourceType",if row.category=="stone" then "Stone" else "Stick")
    m:SetAttribute("RSResourceState","decorative");m:SetAttribute("RSFutureCollectible",true);m:SetAttribute("RSResourceChunk",row.tile)
    m:SetAttribute("RSExpectedGroundY",row.groundY);m:SetAttribute("RSBuriedDepth",row.burial);m:SetAttribute("RSSupportRadius",math.max(.5,row.radius))
end
local count=0
for _,row in cfg.resources do
    local template=if row.category=="stone" then rock else stick
    local m=template:Clone();assert(m,"Resource clone")
    clean(m)
    m:ScaleTo(template:GetScale()*row.scaleFactorFromSource)
    -- Keep model pivot horizontal; lay the actual mesh down inside the model.
    if row.orientation=="Z90" then
        local part=m:FindFirstChild("Visual");assert(part and part:IsA("MeshPart"),"Stick visual")
        part.CFrame=CFrame.Angles(0,0,math.pi/2)*part.CFrame
        m.PrimaryPart=nil;m.WorldPivot=CFrame.identity
    end
    local _,size=m:GetBoundingBox();assert(near(size,v(row.bounds),.012),"Resource bounds "..row.id)
    m:PivotTo(CFrame.new(v(row.position))*CFrame.Angles(0,math.rad(row.yaw),0))
    resourceMeta(m,row)
    if row.action=="resize_relocate" then
        local old=getModel("RSEnvironmentP4",row.id)
        assert(old:GetAttribute("RSSpecies")=="Rock" and old:GetAttribute("RSModelDigest")==row.sourceDigest and near(old:GetPivot().Position,Vector3.new(row.before.x,row.before.y,row.before.z),.01) and math.abs(old:GetScale()-row.before.scale)<.001,"Old stone changed")
        backup(old,"Workspace")
        old:Destroy()
    else assert(row.action=="new","Resource action") end
    m.Parent=models;count+=1
end
rock:Destroy();stick:Destroy()
newRoot.Parent=W
for _,row in cfg.bushMoves do
    local m=getModel("RSEnvironmentP4",row.id)
    assert(m:GetAttribute("RSSpecies")=="Bush_03" and m:GetAttribute("RSModelDigest")==row.sourceDigest and near(m:GetPivot().Position,v(row.from),.01) and math.abs(m:GetScale()-row.scale)<.001,"Bush changed")
    backup(m,"Workspace")
    m:PivotTo(CFrame.new(v(row.to))*CFrame.Angles(0,math.rad(row.yaw),0));m:SetAttribute("RSExpectedGroundY",row.groundY)
end
local function setCollider(p,s,row)
    p.Shape=Enum.PartType[s.shape];p.Size=v(s.size);p.CFrame=CFrame.new(v(s.position))*(if s.rotation=="Z90" then CFrame.Angles(0,0,math.pi/2) else CFrame.identity)
    p.Anchored=true;p.CanCollide=true;p.CanTouch=false;p.CanQuery=true;p.Transparency=1;p.CastShadow=false;p.CollisionGroup=row.collisionGroup
    p.CustomPhysicalProperties=PhysicalProperties.new(1,.05,0,100,1)
    p:SetAttribute("RSOwner",row.owner);p:SetAttribute("RSTreeId",row.id)
    assert(near(p.Size,v(s.size)) and near(p.Position,v(s.position)),"Collider clamp")
end
for _,row in cfg.colliders do
    local m,root=getModel(row.root,row.id)
    assert(near(m:GetPivot().Position,v(row.modelPosition),.01) and math.abs(m:GetScale()-row.modelScale)<.001,"Tree changed")
    local folder=root:FindFirstChild("Collisions")
    if not folder then assert(row.action=="add" and row.root=="RSManagedAssets","Missing collision folder");folder=Instance.new("Folder");folder.Name="Collisions";folder.Parent=root end
    local shaft=folder:FindFirstChild(row.id)
    if row.oldCollider then
        assert(shaft and shaft:IsA("Part") and near(shaft.Size,v(row.oldCollider.size)) and near(shaft.Position,v(row.oldCollider.position)) and shaft.CollisionGroup==row.collisionGroup,"Old collider changed")
        backup(shaft,"Workspace")
    else assert(not shaft,"Unexpected collider");shaft=Instance.new("Part");shaft.Name=row.id end
    setCollider(shaft,row.shaft,row);shaft.Parent=folder
    assert(not folder:FindFirstChild(row.id.."-cap"),"Duplicate cap")
    local cap=Instance.new("Part");cap.Name=row.id.."-cap";setCollider(cap,row.cap,row);cap.Parent=folder
end
local wind=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):FindFirstChild("RSWind")
assert(wind and wind:IsA("LocalScript") and hash(wind.Source)==cfg.windBeforeHash,"Wind source changed")
backup(wind,"StarterPlayer");wind.Source=cfg.windSource
local after=inventory()
assert(after.total+cfg.cloneReserve<=4500,"Inventory budget")
local afterFingerprint=fingerprint(after)
if cfg.mode=="preview" then
    -- Exercise the inverse in this disposable session, not in the live place.
    newRoot:Destroy()
    for _,row in cfg.colliders do
        local _,root=getModel(row.root,row.id)
        local folder=root:FindFirstChild("Collisions")
        folder:FindFirstChild(row.id.."-cap"):Destroy()
        if row.action=="add" then
            folder:FindFirstChild(row.id):Destroy()
            if row.root=="RSManagedAssets" and #folder:GetChildren()==0 then folder:Destroy() end
        end
    end
    for _,r in backups do
        local parentPath=table.clone(r.path);local last=table.remove(parentPath)
        local parent=locate(r.service,parentPath)
        local blob=Encoding:Base64Decode(buffer.fromstring(r.serializedBase64))
        assert(digestBuffer(blob)==r.digest,"Recovery blob")
        local copies=Serial:DeserializeInstancesAsync(blob)
        assert(#copies==1 and copies[1].Name==last.name and copies[1].ClassName==last.class,"Recovery selector")
        local old=parent:FindFirstChild(last.name)
        if copies[1]:IsA("LocalScript") then assert(old and old:IsA("LocalScript"),"Recovery script");old.Source=copies[1].Source;copies[1]:Destroy()
        else if old then assert(old.ClassName==last.class,"Recovery class");old:Destroy() end;copies[1].Parent=parent end
    end
    local restored=inventory()
    return syncResult({schemaVersion=1,preview=true,noPlaceWrites=true,planDigest=cfg.planDigest,after=after,backups=backups,resources=count,colliders=#cfg.colliders,beforeFingerprint=beforeFingerprint,afterFingerprint=afterFingerprint,restored=restored})
end
assert(cfg.confirmStaging==true and #backups==cfg.backupCount and afterFingerprint==cfg.afterFingerprint,"Reviewed apply fingerprint mismatch")
Assets:SavePlaceAsync({SaveWithoutPublish=false})
return syncResult({schemaVersion=1,saved=true,planDigest=cfg.planDigest,resources=count,colliders=#cfg.colliders})
