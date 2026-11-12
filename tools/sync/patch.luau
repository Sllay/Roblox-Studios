-- Exact inventory preconditions, scoped edits; no arbitrary Luau from plans.
local W=workspace
local SS=game:GetService("ServerStorage")
local function same(a,b)
    if typeof(a)~=typeof(b) then return false end
    if typeof(a)=="number" then return math.abs(a-b)<0.0001 end
    if typeof(a)~="table" then return a==b end
    for k,v in a do if not same(v,b[k]) then return false end end
    for k in b do if a[k]==nil then return false end end
    return true
end
local function getTarget(r)
    local root=game:GetService(r.service)
    local obj=locate(r.service,r.path)
    assert(not r.ambiguous and same(record(root,obj),r),"Object changed since sync")
    return obj
end
local function getParent(r)
    if #r.path==0 then return game:GetService(r.service) end
    return getTarget(r)
end
local function noCritical(obj)
    assert(obj~=W.Terrain and not obj:IsA("SpawnLocation") and obj.Name~="Baseplate","Use dedicated terrain/spawn migration")
    for _,name in {"RSSceneBuilder","RSWorldVegetation","RSEnvironmentP4","RSEnvironmentP4Detail","RSManagedAssets"} do
        local scene=W:FindFirstChild(name)
        assert(not scene or (obj~=scene and not obj:IsDescendantOf(scene)),"Use dedicated coupled environment migration")
    end
end
local inert={Model=true,Folder=true,Part=true,MeshPart=true,SurfaceAppearance=true,Texture=true,Decal=true,SpecialMesh=true,WedgePart=true,CornerWedgePart=true}
local function inertTree(obj)
    assert(inert[obj.ClassName],"Unsupported archive/edit class")
    if obj:IsA("BasePart") then assert(obj.Anchored,"Unanchored root") end
    for _,c in obj:GetDescendants() do
        assert(inert[c.ClassName],"Unsupported descendant; cannot archive safely")
        if c:IsA("BasePart") then assert(c.Anchored,"Unanchored subtree") end
    end
end
local function archiveRoot(create)
    local a=SS:FindFirstChild("RSScenePatchArchive")
    if a then assert(a:IsA("Folder") and a:GetAttribute("RSOwner")=="RSScenePatchV1","Archive collision")
    elseif create then
        a=Instance.new("Folder");a.Name="RSScenePatchArchive";a:SetAttribute("RSOwner","RSScenePatchV1");a.Parent=SS
    end
    return a
end
local function setPart(obj,changes)
    if changes.cframe then obj.CFrame=CFrame.new(table.unpack(changes.cframe)) end
    if changes.size then obj.Size=Vector3.new(table.unpack(changes.size)) end
    if changes.color then obj.Color=Color3.new(table.unpack(changes.color)) end
    if changes.material then obj.Material=Enum.Material[changes.material] end
    if changes.transparency~=nil then obj.Transparency=changes.transparency end
    if changes.canCollide~=nil then obj.CanCollide=changes.canCollide end
end
local function output(r) r.universeId=tostring(game.GameId);r.placeId=tostring(game.PlaceId);return Http:JSONEncode(r) end
assert(cfg.environment=="staging" and game.PlaceVersion==cfg.expectedVersion,"Target/version changed")
local prepared={}
-- All preconditions checked before mutation. Operations target distinct objects.
for _,op in cfg.operations do
    local obj,parent
    if op.target then obj=getTarget(op.target);noCritical(obj) end
    if op.parent then parent=getParent(op.parent) end
    if op.kind=="add_part" then
        assert(parent and (parent==W or parent:IsA("Folder")) and (parent==W or parent:IsDescendantOf(W)),"Unsupported parent")
        if parent~=W then noCritical(parent) end
        assert(not parent:FindFirstChild(op.name),"Name collision")
    elseif op.kind=="set_part" then
        assert(obj:IsA("Part") and obj.Anchored,"Only anchored Part edits")
        inertTree(obj)
    elseif op.kind=="move_model" then
        assert(obj:IsA("Model") and obj:IsDescendantOf(W),"Only Workspace model")
        inertTree(obj)
    elseif op.kind=="adopt" then
        assert(obj and obj:GetAttribute("RSSceneSyncId")==nil and obj:GetAttribute("RSManagedId")==nil,"Already managed")
        inertTree(obj)
    elseif op.kind=="archive" then
        assert(obj:IsDescendantOf(W),"Only Workspace object archive")
        inertTree(obj)
        local a=archiveRoot(false);assert(not a or not a:FindFirstChild(op.archiveId),"Archive ID collision")
    elseif op.kind=="restore" then
        local a=archiveRoot(false);assert(a,"Archive missing")
        assert(obj:IsA("Folder") and obj.Parent==a and #obj:GetChildren()==1,"Archive entry mismatch")
        local original=obj:GetChildren()[1]
        assert(parent and (parent==W or parent:IsDescendantOf(W)) and not parent:FindFirstChild(original.Name),"Restore parent/name conflict")
        if parent~=W then noCritical(parent) end
        local expectedParent=obj:GetAttribute("RSOriginalParent")
        assert(expectedParent==op.parentToken,"Restore parent differs from archive")
        inertTree(original)
    elseif op.kind=="update_script" then
        assert(obj:IsA("LuaSourceContainer") and #obj:GetChildren()==0 and obj.Archivable,"Unsupported script edit")
        assert(hash(obj.Source)==op.target.properties.sourceHash and hash(op.source)==op.sourceHash,"Script source mismatch")
        local a=archiveRoot(false);assert(not a or not a:FindFirstChild(op.archiveId),"Script backup ID collision")
    elseif op.kind=="create_script" then
        assert(parent and not parent:FindFirstChild(op.name),"Script parent/name collision")
        assert((op.class=="Script" and parent==game:GetService("ServerScriptService")) or
            (op.class=="ModuleScript" and parent==game:GetService("ReplicatedStorage")) or
            (op.class=="LocalScript" and parent==game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")),"Unsupported script destination")
        assert(hash(op.source)==op.sourceHash,"Source hash mismatch")
    else error("Unsupported operation") end
    table.insert(prepared,{op=op,obj=obj,parent=parent})
end
if cfg.mode=="preview" then return output({preview=true,operations=#prepared}) end
assert(cfg.mode=="apply","Unknown mode")
local results={}
for _,item in prepared do
    local op,obj,parent=item.op,item.obj,item.parent
    if op.kind=="add_part" then
        assert(not parent:FindFirstChild(op.name),"Destination changed")
        obj=Instance.new("Part");obj.Name=op.name;obj.Anchored=true;obj.CanTouch=false
        setPart(obj,op.changes);obj:SetAttribute("RSSceneSyncId",op.id);obj.Parent=parent
    elseif op.kind=="set_part" then setPart(obj,op.changes)
    elseif op.kind=="move_model" then obj:PivotTo(CFrame.new(table.unpack(op.cframe)))
    elseif op.kind=="adopt" then obj:SetAttribute("RSSceneSyncId",op.id)
    elseif op.kind=="archive" then
        local a=archiveRoot(true)
        assert(not a:FindFirstChild(op.archiveId),"Archive destination changed")
        local entry=Instance.new("Folder");entry.Name=op.archiveId;entry:SetAttribute("RSOwner","RSScenePatchV1")
        entry:SetAttribute("RSOriginalParent",op.parentToken);entry.Parent=a;obj.Parent=entry
    elseif op.kind=="restore" then
        local original=obj:GetChildren()[1];assert(not parent:FindFirstChild(original.Name),"Restore destination changed");original.Parent=parent;obj:Destroy();obj=original
    elseif op.kind=="update_script" then
        local a=archiveRoot(true)
        local entry=Instance.new("Folder");entry.Name=op.archiveId;entry:SetAttribute("RSOwner","RSScenePatchV1");entry:SetAttribute("RSOriginalTarget",op.targetToken);entry.Parent=a
        local backup=obj:Clone();assert(backup and hash(backup.Source)==op.target.properties.sourceHash,"Script backup failed")
        if backup:IsA("BaseScript") then entry:SetAttribute("RSOriginalEnabled",backup.Enabled);backup.Enabled=false end
        -- backup must not duplicate the managed identity in the observed inventory
        backup:SetAttribute("RSSceneSyncId",nil);backup:SetAttribute("RSManagedId",nil);backup.Parent=entry
        obj.Source=op.source
    elseif op.kind=="create_script" then
        obj=Instance.new(op.class);obj.Name=op.name;obj.Source=op.source;obj:SetAttribute("RSSceneSyncId",op.id);obj.Parent=parent
    end
    table.insert(results,{kind=op.kind,name=obj.Name,path=obj:GetFullName()})
end
game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false})
return output({saved=true,results=results})
