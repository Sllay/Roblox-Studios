--!strict
-- Safe Import v2: exact detached submodel; never write outside staging mapping.
local Http=game:GetService("HttpService")
local Assets=game:GetService("AssetService")
local Serial=game:GetService("SerializationService")
local Encoding=game:GetService("EncodingService")
local Workspace=game:GetService("Workspace")
local Tags=game:GetService("CollectionService")
local cfg=Http:JSONDecode(__RS_CONFIG__)
assert(tostring(game.GameId)==cfg.universeId and tostring(game.PlaceId)==cfg.placeId,"Target mismatch")
local allowed={Model=true,Folder=true,MeshPart=true,SurfaceAppearance=true}
local mapNames={"ColorMapContent","NormalMapContent","MetalnessMapContent","RoughnessMapContent","EmissiveMaskContent"}
local function content(value: Content): string
    assert(typeof(value)=="Content","Expected Content")
    if value.SourceType==Enum.ContentSourceType.None then return "" end
    assert(value.SourceType==Enum.ContentSourceType.Uri,"Object or opaque content is not allowed")
    local uri=value.Uri
    assert(uri and string.match(uri,"^rbxassetid://[1-9]%d*$"),"Unsupported asset URI")
    return uri
end
local function vector(v: Vector3) return {v.X,v.Y,v.Z} end
local function color(v: Color3) return {v.R,v.G,v.B} end
local function pathFor(root: Instance,obj: Instance)
    local path={}
    local cursor=obj
    while cursor~=root do
        local parent=cursor.Parent
        assert(parent,"Invalid path")
        table.insert(path,1,{index=table.find(parent:GetChildren(),cursor),name=cursor.Name,class=cursor.ClassName})
        cursor=parent
    end
    return path
end
local function audit(model: Model)
    local descendants=model:GetDescendants()
    assert(#descendants>0 and #descendants<=350,"Instance budget")
    local rows={}
    local ids={}
    local parts,surfaces=0,0
    local function dep(value: string)
        if value~="" then ids[value]=true end
        return value
    end
    local pivot=model:GetPivot()
    for _,obj in descendants do
        assert(allowed[obj.ClassName] and not obj:IsA("LuaSourceContainer"),"Rejected class: "..obj.ClassName)
        local row: {[string]: any}={path=pathFor(model,obj),class=obj.ClassName}
        if obj:IsA("MeshPart") then
            parts+=1
            assert(obj.MaterialVariant=="","Custom MaterialVariant requires separate audit")
            row.mesh=dep(content(obj.MeshContent))
            row.texture=dep(content(obj.TextureContent))
            assert(row.mesh~="","Missing mesh")
            row.relative={pivot:ToObjectSpace(obj.CFrame):GetComponents()}
            row.size=vector(obj.Size)
            row.color=color(obj.Color)
            row.material=obj.Material.Name
            row.transparency=obj.Transparency
            row.reflectance=obj.Reflectance
            row.renderFidelity=obj.RenderFidelity.Name
            row.collisionFidelity=obj.CollisionFidelity.Name
        elseif obj:IsA("SurfaceAppearance") then
            surfaces+=1
            assert(obj.Parent and obj.Parent:IsA("MeshPart"),"Unexpected surface parent")
            local maps={}
            for _,property in mapNames do
                maps[property]=dep(content((obj::any)[property]))
            end
            row.maps=maps
            row.color=color(obj.Color)
            row.alphaMode=obj.AlphaMode.Name
            row.emissiveStrength=obj.EmissiveStrength
            row.emissiveTint=color(obj.EmissiveTint)
            row.resampleMode=obj.ResampleMode.Name
        end
        table.insert(rows,row)
    end
    assert(parts>0 and parts<=100,"Part budget")
    local _,size=model:GetBoundingBox()
    assert(math.max(size.X,size.Y,size.Z)<=512,"Dimensions budget")
    local deps={}
    for id in ids do table.insert(deps,id) end
    table.sort(deps)
    assert(#deps<=100,"Dependency budget")
    table.sort(rows,function(a,b) return Http:JSONEncode(a.path)<Http:JSONEncode(b.path) end)
    return {policyVersion=2,parts=parts,surfaces=surfaces,instances=#descendants,bounds=vector(size),dependencies=deps,rows=rows}
end
local function fetchDependencies(model: Model, report)
    local cp=game:GetService("ContentProvider")
    local meshes,meshIds,textures={},{},{}
    local meshStatus,textureStatus={},{}
    for _,obj in model:GetDescendants() do
        if obj:IsA("MeshPart") then
            table.insert(meshes,obj)
            meshIds[content(obj.MeshContent)]=true
        end
    end
    for _,row in report.rows do
        if row.class=="SurfaceAppearance" then
            for _,uri in row.maps do if uri~="" then textures[uri]=true end end
        elseif row.class=="MeshPart" and row.texture~="" then textures[row.texture]=true end
    end
    local textureList={}
    for uri in textures do table.insert(textureList,uri) end
    if #textureList>0 then
        cp:PreloadAsync(textureList,function(uri,status) textureStatus[uri]=status.Name end)
    end
    cp:PreloadAsync(meshes,function(uri,status) meshStatus[uri]=status.Name end)
    for uri in meshIds do assert(meshStatus[uri]=="Success","Mesh fetch not confirmed: "..uri) end
    for uri in textures do assert(textureStatus[uri]=="Success","Texture fetch not confirmed: "..uri) end
    return {meshes=meshStatus,textures=textureStatus,verified=true}
end
local function serialize(model: Model)
    local blob=Serial:SerializeInstancesAsync({model})
    assert(buffer.len(blob)<=512000,"Serialized model exceeds policy")
    local digest=buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(blob,Enum.HashAlgorithm.Sha256)))
    return blob,digest
end
local function cloneSelected()
    local root=Assets:LoadAssetAsync(tonumber(cfg.assetId))
    assert(root:IsA("Model") and root.Parent==nil,"Expected detached pack")
    local cursor: Instance=root
    assert(#cfg.selector>0 and #cfg.selector<=32,"Invalid selector")
    for _,s in cfg.selector do
        local child=cursor:GetChildren()[s.index]
        assert(child and child.Name==s.name and child.ClassName==s.class,"Pack selector changed")
        cursor=child
    end
    assert(cursor:IsA("Model"),"Expected model")
    local model=cursor:Clone()
    assert(model and model.Parent==nil and model:IsA("Model") and #model:GetDescendants()==#cursor:GetDescendants(),"Clone incomplete")
    root:Destroy()
    return model
end
local function output(value)
    value.universeId=tostring(game.GameId)
    value.placeId=tostring(game.PlaceId)
    value.assetId=cfg.assetId
    return Http:JSONEncode(value)
end
local function managed()
    local root=Workspace:FindFirstChild("RSManagedAssets")
    if root then assert(root:IsA("Folder") and root:GetAttribute("RSOwner")=="RobloxStudiosStaticV1","Managed root collision") end
    return root
end
if cfg.mode=="verify" then
    local root=managed()
    assert(root,"Managed root missing")
    local model=root:FindFirstChild(cfg.managedId)
    assert(model and model:IsA("Model") and model:GetAttribute("RSManagedId")==cfg.managedId and model:GetAttribute("RSAssetId")==cfg.assetId,"Managed identity mismatch")
    assert(model:GetAttribute("RSModelDigest")==cfg.digest and model:GetAttribute("RSSelector")==cfg.selectorJson and model:GetAttribute("Biome")==cfg.biome,"Provenance mismatch")
    for _,obj in model:GetDescendants() do
        if obj:IsA("BasePart") then assert(obj.Anchored and not obj.CanCollide and not obj.CanTouch and not obj.CanQuery,"Physics mismatch") end
    end
    local expected=CFrame.new(cfg.position[1],cfg.position[2],cfg.position[3])*CFrame.Angles(0,math.rad(cfg.yaw),0)
    local actual={model:GetPivot():GetComponents()}
    for i,v in {expected:GetComponents()} do assert(math.abs(v-actual[i])<0.02,"Pivot mismatch") end
    local report=audit(model)
    local fetched=fetchDependencies(model,report)
    local blob,digest=serialize(model)
    return output({verified=true,audit=report,dependencyFetch=fetched,persistedDigest=digest,serializedBase64=buffer.tostring(Encoding:Base64Encode(blob))})
end
local model=cloneSelected()
local report=audit(model)
local fetched=fetchDependencies(model,report)
local blob,digest=serialize(model)
if cfg.mode=="audit" then
    local encoded=buffer.tostring(Encoding:Base64Encode(blob))
    local pivot=model:GetPivot()
    local bb,size=model:GetBoundingBox()
    local bottom=bb.Position.Y-size.Y/2
    local bottomOffset=bottom-pivot.Position.Y
    local ground={}
    local base=Workspace:FindFirstChild("Baseplate")
    if base and base:IsA("Part") and base.Anchored and base.CanCollide then
        ground={position=vector(base.Position),size=vector(base.Size),top=base.Position.Y+base.Size.Y/2}
    end
    local spawn=Workspace:FindFirstChildWhichIsA("SpawnLocation",true)
    local spawnPosition=if spawn then vector(spawn.Position) else nil
    model:Destroy()
    return output({audit=report,dependencyFetch=fetched,digest=digest,serializedBase64=encoded,bottomOffset=bottomOffset,ground=ground,spawn=spawnPosition})
end
assert(cfg.mode=="apply","Unknown mode")
assert(game.PlaceVersion==cfg.expectedVersion,"Place changed")
assert(digest==cfg.digest,"Serialized model changed since offline audit")
assert(cfg.environment=="staging","Only staging import")
local root=managed()
assert(not root or not root:FindFirstChild(cfg.managedId),"Managed ID already exists")
for _,obj in model:GetDescendants() do
    for name in obj:GetAttributes() do obj:SetAttribute(name,nil) end
    for _,tag in Tags:GetTags(obj) do Tags:RemoveTag(obj,tag) end
    if obj:IsA("BasePart") then
        obj.Anchored=true
        obj.CanCollide=false
        obj.CanTouch=false
        obj.CanQuery=false
    end
end
for name in model:GetAttributes() do model:SetAttribute(name,nil) end
for _,tag in Tags:GetTags(model) do Tags:RemoveTag(model,tag) end
model.Name=cfg.managedId
model:SetAttribute("RSManagedId",cfg.managedId)
model:SetAttribute("RSAssetId",cfg.assetId)
model:SetAttribute("RSModelDigest",cfg.digest)
model:SetAttribute("RSSelector",cfg.selectorJson)
model:SetAttribute("Biome",cfg.biome)
model:PivotTo(CFrame.new(cfg.position[1],cfg.position[2],cfg.position[3])*CFrame.Angles(0,math.rad(cfg.yaw),0))
-- verify geometry and PBR again after transformation, before save
local final=audit(model)
assert(final.parts==report.parts and final.surfaces==report.surfaces,"Sanitize changed appearance")
if not root then
    root=Instance.new("Folder")
    root.Name="RSManagedAssets"
    root:SetAttribute("RSOwner","RobloxStudiosStaticV1")
    root.Parent=Workspace
end
model.Parent=root
Assets:SavePlaceAsync({SaveWithoutPublish=false})
return output({saved=true,managedId=cfg.managedId,audit=final,dependencyFetch=fetched})
