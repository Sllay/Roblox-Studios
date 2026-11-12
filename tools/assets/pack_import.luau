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
-- __RS_PLACEMENT__
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
    local placementEvidence=nil
    if cfg.placementProfile then
        local detached=model:Clone()
        placementEvidence=solvePlacement(detached,cfg.position[1],cfg.position[3],cfg.yaw,cfg.placementProfile)
        detached:Destroy()
        assert(math.abs(placementEvidence.position[2]-cfg.position[2])<0.05,"Ground verification differs")
    end
    local controlReport=nil
    if cfg.verifyLab then
        local control=game:GetService("ReplicatedStorage"):FindFirstChild("RSLightingLabSource")
        local lab=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):FindFirstChild("RSLightingLab")
        assert(control and control:IsA("Model") and control:GetAttribute("RSOwner")=="RSLightingLabV1" and control:GetAttribute("RSModelDigest")==cfg.digest,"Control missing")
        assert(lab and lab:IsA("LocalScript") and lab:GetAttribute("RSOwner")=="RSLightingLabV1" and lab.Source==cfg.clientSource,"Lab script missing or changed")
        assert(model:GetAttribute("RSPlacementProfile")~=nil,"Placement profile missing")
        controlReport=audit(control)
    end
    local report=audit(model)
    local fetched=fetchDependencies(model,report)
    local blob,digest=serialize(model)
    return output({verified=true,audit=report,placement=placementEvidence,controlAudit=controlReport,dependencyFetch=fetched,persistedDigest=digest,serializedBase64=buffer.tostring(Encoding:Base64Encode(blob))})
end
local model=cloneSelected()
local report=audit(model)
local fetched=fetchDependencies(model,report)
local blob,digest=serialize(model)
if cfg.mode=="placement_probe" then
    local placement=solvePlacement(model,cfg.position[1],cfg.position[3],cfg.yaw,cfg.placementProfile)
    model:Destroy()
    return output({placement=placement,digest=digest})
end
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

if cfg.mode=="repair" then
    assert(cfg.environment=="staging" and game.PlaceVersion==cfg.expectedVersion,"Repair target/version mismatch")
    assert(digest==cfg.digest,"Source digest changed")
    local root=managed()
    assert(root,"Managed root missing")
    local existing=root:FindFirstChild(cfg.managedId)
    assert(existing and existing:IsA("Model") and existing:GetAttribute("RSManagedId")==cfg.managedId
        and existing:GetAttribute("RSAssetId")==cfg.assetId and existing:GetAttribute("RSModelDigest")==digest
        and existing:GetAttribute("RSSelector")==cfg.selectorJson,"Existing provenance mismatch")
    local function equivalent(a,b)
        if typeof(a)~=typeof(b) then return false end
        if typeof(a)=="number" then return math.abs(a-b)<0.025 end
        if typeof(a)~="table" then return a==b end
        for k,v in a do if not equivalent(v,b[k]) then return false end end
        for k in b do if a[k]==nil then return false end end
        return true
    end
    local before=audit(existing)
    assert(equivalent(before,report),"Existing model differs from source")
    local old=existing:GetPivot()
    for i,v in {old:GetComponents()} do assert(math.abs(v-cfg.oldPivot[i])<0.02,"Existing pivot changed") end
    local solved=solvePlacement(model,cfg.position[1],cfg.position[3],cfg.yaw,cfg.placementProfile)
    assert(math.abs(solved.position[2]-cfg.position[2])<0.05,"Ground differs from reviewed position")
    local target=CFrame.new(solved.position[1],solved.position[2],solved.position[3])*CFrame.Angles(0,math.rad(cfg.yaw),0)
    local RS=game:GetService("ReplicatedStorage")
    local SPS=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
    assert(not RS:FindFirstChild("RSLightingLabSource") and not SPS:FindFirstChild("RSLightingLab"),"Lab already exists")
    -- Control is freshly loaded source. Only physics and behavior metadata
    -- are sanitized; its original visual properties remain untouched.
    for _,obj in model:GetDescendants() do
        for name in obj:GetAttributes() do obj:SetAttribute(name,nil) end
        for _,tag in Tags:GetTags(obj) do Tags:RemoveTag(obj,tag) end
        if obj:IsA("BasePart") then obj.Anchored=true;obj.CanCollide=false;obj.CanTouch=false;obj.CanQuery=false end
    end
    for name in model:GetAttributes() do model:SetAttribute(name,nil) end
    for _,tag in Tags:GetTags(model) do Tags:RemoveTag(model,tag) end
    model.Name="RSLightingLabSource"
    model:SetAttribute("RSOwner","RSLightingLabV1")
    model:SetAttribute("RSModelDigest",digest)
    model:PivotTo(target)
    existing:PivotTo(target)
    existing:SetAttribute("RSPlacementProfile",Http:JSONEncode(cfg.placementProfile))
    assert(equivalent(audit(existing),before) and equivalent(audit(model),report),"Geometry or appearance changed")
    model.Parent=RS
    local scriptObj=Instance.new("LocalScript")
    scriptObj.Name="RSLightingLab"
    scriptObj:SetAttribute("RSOwner","RSLightingLabV1")
    scriptObj.Source=cfg.clientSource
    scriptObj.Parent=SPS
    local L=game:GetService("Lighting")
    local settings={brightness=L.Brightness,exposure=L.ExposureCompensation,specular=L.EnvironmentSpecularScale,diffuse=L.EnvironmentDiffuseScale,clock=L.ClockTime,style=L.LightingStyle.Name}
    local post={}
    for _,obj in L:GetChildren() do if obj:IsA("PostEffect") then table.insert(post,{name=obj.Name,class=obj.ClassName,enabled=obj.Enabled}) end end
    Assets:SavePlaceAsync({SaveWithoutPublish=false})
    return output({saved=true,placement=solved,lighting=settings,postEffects=post,sourceMatches=true,audit=before})
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
local solved=solvePlacement(model,cfg.position[1],cfg.position[3],cfg.yaw,cfg.placementProfile)
assert(math.abs(solved.position[2]-cfg.position[2])<0.05,"Reviewed ground position changed")
model:PivotTo(CFrame.new(solved.position[1],solved.position[2],solved.position[3])*CFrame.Angles(0,math.rad(cfg.yaw),0))
model:SetAttribute("RSPlacementProfile",Http:JSONEncode(cfg.placementProfile))
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
return output({saved=true,managedId=cfg.managedId,audit=final,dependencyFetch=fetched,placement=solved})
