--!strict
-- Restricted decorative asset policy. All inspection occurs before parenting.
local Http = game:GetService("HttpService")
local Assets = game:GetService("AssetService")
local Workspace = game:GetService("Workspace")
local cfg = Http:JSONDecode(__RS_CONFIG__)
assert(tostring(game.GameId) == cfg.universeId and tostring(game.PlaceId) == cfg.placeId, "Target identity mismatch")
local allowed = {
    Model=true, Folder=true, Part=true, MeshPart=true, SpecialMesh=true,
    Decal=true, Texture=true, SurfaceAppearance=true,
}
local MAX_DESCENDANTS = 350
local MAX_PARTS = 100
local MAX_DEPENDENCIES = 100
local function contentId(value: string): boolean
    return value == "" or string.match(value, "^rbxassetid://%d+$") ~= nil
end
local function audit(model: Instance)
    assert(model:IsA("Model") and model.Parent == nil, "Expected detached model")
    local descendants = model:GetDescendants()
    local problems, records, dependencies = {}, {}, {}
    local unreadableProperties = {}
    local counts = {}
    local partCount, collisions = 0, 0
    local function issue(message: string)
        if #problems < 80 then table.insert(problems, message) end
    end
    local function dep(value: string)
        if not contentId(value) then
            issue("Unsupported content URI")
        elseif value ~= "" then
            dependencies[value] = true
        end
        return value
    end
    if #descendants > MAX_DESCENDANTS then issue("Instance budget exceeded") end
    for index, obj in descendants do
        if index > MAX_DESCENDANTS then break end
        local class = obj.ClassName
        counts[class] = (counts[class] or 0) + 1
        if not allowed[class] then
            issue("Disallowed class: " .. class)
        end
        if obj:IsA("LuaSourceContainer") then issue("Embedded code: " .. class) end
        -- Relative hierarchy with unambiguous child indices. Includes duplicate names.
        local path = {}
        local cursor = obj
        while cursor ~= model do
            local parent = cursor.Parent
            assert(parent, "Detached descendant")
            local idx = table.find(parent:GetChildren(), cursor)
            table.insert(path, 1, {cursor.Name, idx})
            cursor = parent
        end
        local record: {any} = {path, class}
        if obj:IsA("BasePart") then
            partCount += 1
            if obj.CanCollide then collisions += 1 end
            local cf = model:GetPivot():ToObjectSpace(obj.CFrame)
            local function nums(v: Vector3) return {v.X,v.Y,v.Z} end
            table.insert(record, {cf:GetComponents()})
            table.insert(record, nums(obj.Size))
            table.insert(record, {obj.Color.R,obj.Color.G,obj.Color.B})
            table.insert(record, {obj.Material.Name,obj.Transparency,obj.Reflectance,obj.Anchored,obj.CanCollide})
            if obj:IsA("MeshPart") then
                table.insert(record, {dep(obj.MeshId),dep(obj.TextureID),obj.CollisionFidelity.Name,obj.RenderFidelity.Name})
            elseif obj:IsA("Part") then
                table.insert(record, obj.Shape.Name)
            end
        elseif obj:IsA("SpecialMesh") then
            table.insert(record,{obj.MeshType.Name,dep(obj.MeshId),dep(obj.TextureId),
                {obj.Scale.X,obj.Scale.Y,obj.Scale.Z},{obj.Offset.X,obj.Offset.Y,obj.Offset.Z},
                {obj.VertexColor.X,obj.VertexColor.Y,obj.VertexColor.Z}})
        elseif obj:IsA("Decal") then
            table.insert(record,{dep(obj.Texture),obj.Face.Name,obj.Transparency,obj.Color3.R,obj.Color3.G,obj.Color3.B})
            if obj:IsA("Texture") then
                table.insert(record,{obj.StudsPerTileU,obj.StudsPerTileV,obj.OffsetStudsU,obj.OffsetStudsV})
            end
        elseif obj:IsA("SurfaceAppearance") then
            -- These map properties require Plugin capability. Open Cloud may
            -- load the model but cannot read them. Never interpret denial as empty.
            local maps = {}
            for _, property in {"ColorMap","NormalMap","MetalnessMap","RoughnessMap","EmissiveMaskContent","TexturePackContent"} do
                local ok, value = pcall(function() return (obj :: any)[property] end)
                if ok and typeof(value) == "string" then
                    table.insert(maps, {property, dep(value)})
                else
                    unreadableProperties[property] = (unreadableProperties[property] or 0) + 1
                    table.insert(maps, {property, "UNINSPECTED"})
                end
            end
            table.insert(record,{maps,obj.AlphaMode.Name,obj.Color.R,obj.Color.G,obj.Color.B})
        end
        table.insert(records,Http:JSONEncode(record))
    end
    if next(unreadableProperties) ~= nil then issue("SurfaceAppearance texture dependencies not fully inspectable in Open Cloud") end
    if partCount < 1 then issue("No visual parts") end
    if partCount > MAX_PARTS then issue("Part budget exceeded") end
    local deps = {}
    for value in dependencies do table.insert(deps,value) end
    table.sort(deps)
    if #deps > MAX_DEPENDENCIES then issue("Dependency budget exceeded") end
    local _, bounds = model:GetBoundingBox()
    if math.max(bounds.X,bounds.Y,bounds.Z) > 512 then issue("Model dimensions exceed 512 studs") end
    table.sort(records)
    return {
        policyVersion=1, allowed=#problems==0, issues=problems,
        counts=counts, parts=partCount, collisionParts=collisions,
        unreadableProperties=unreadableProperties, inspectionComplete=next(unreadableProperties)==nil,
        instances=#descendants, dependencies=deps, signature=records,
        bounds={bounds.X,bounds.Y,bounds.Z},
    }
end
local function loadAsset(): Model
    local ok, result = pcall(Assets.LoadAssetAsync, Assets, tonumber(cfg.assetId))
    assert(ok, "Asset load denied or unavailable: " .. tostring(result))
    assert(typeof(result) == "Instance" and result:IsA("Model"), "Asset is not a Model")
    assert(result.Parent == nil, "Loaded asset was not detached")
    return result
end
local function managedRoot()
    local root = Workspace:FindFirstChild("RSManagedAssets")
    if root then
        assert(root:IsA("Folder") and root:GetAttribute("RSOwner") == "RobloxStudiosStaticV1",
            "Managed folder name collision")
    end
    return root
end
local function findManaged(root: Instance?, id: string)
    if not root then return nil end
    local found = root:FindFirstChild(id)
    if found then
        assert(found:IsA("Model") and found:GetAttribute("RSManagedId") == id
            and found:GetAttribute("RSAssetId") == cfg.assetId, "Managed identity collision")
    end
    return found
end
local function output(extra)
    extra.universeId = tostring(game.GameId)
    extra.placeId = tostring(game.PlaceId)
    extra.assetId = cfg.assetId
    return Http:JSONEncode(extra)
end
if cfg.mode == "verify" then
    local found = findManaged(managedRoot(),cfg.managedId)
    assert(found, "Imported model not found")
    local parts = 0
    for _, obj in found:GetDescendants() do
        assert(allowed[obj.ClassName] and not obj:IsA("LuaSourceContainer"), "Unexpected imported class")
        if obj:IsA("BasePart") then
            assert(obj.Anchored and not obj.CanCollide and not obj.CanTouch and not obj.CanQuery,"Unexpected physics settings")
            parts += 1
        end
    end
    assert(parts == cfg.parts, "Part count mismatch")
    assert(found:GetAttribute("Biome") == cfg.biome, "Biome mismatch")
    local expected = CFrame.new(cfg.position[1],cfg.position[2],cfg.position[3]) * CFrame.Angles(0,math.rad(cfg.yaw),0)
    local actual = {found:GetPivot():GetComponents()}
    local desired = {expected:GetComponents()}
    for i, value in actual do assert(math.abs(value - desired[i]) < 0.02, "Model pivot mismatch") end
    return output({verified=true,managedId=cfg.managedId,parts=parts})
end

-- Pack selectors are path segments with a child index, name and class.
-- They are locators in a particular loaded hierarchy, not independent Asset IDs.
local function packPath(root: Instance, obj: Instance)
    local segments = {}
    local cursor = obj
    while cursor ~= root do
        local parent = cursor.Parent
        assert(parent, "Object outside pack")
        table.insert(segments, 1, {
            index=table.find(parent:GetChildren(),cursor),
            name=cursor.Name, class=cursor.ClassName,
        })
        cursor=parent
    end
    return segments
end
local function selectPackModel(root: Model, path)
    assert(typeof(path)=="table" and #path>0 and #path<=32,"Invalid pack selector")
    local cursor: Instance = root
    for _, segment in path do
        local child=cursor:GetChildren()[segment.index]
        assert(child and child.Name==segment.name and child.ClassName==segment.class,"Pack selector changed; inventory again")
        cursor=child
    end
    assert(cursor:IsA("Model"),"Selector must identify an individual Model")
    return cursor
end
local function describeModel(root: Model, obj: Model)
    local counts={}
    local visualComponents={}
    local parts, scripts, pbr, nested, unsupported=0,0,0,0,0
    local descendants=obj:GetDescendants()
    for _, child in descendants do
        counts[child.ClassName]=(counts[child.ClassName] or 0)+1
        if child:IsA("BasePart") then parts+=1 end
        if child:IsA("MeshPart") and #visualComponents<100 then
            local appearance=child:FindFirstChildWhichIsA("SurfaceAppearance")
            local tint=if appearance then appearance.Color else child.Color
            table.insert(visualComponents,{name=child.Name,meshId=child.MeshId,textureId=child.TextureID,
                tint={tint.R,tint.G,tint.B},tintSource=if appearance then "SurfaceAppearance.Color" else "BasePart.Color",
                material=child.Material.Name,pbr=appearance~=nil})
        end
        if child:IsA("LuaSourceContainer") then scripts+=1 end
        if child:IsA("SurfaceAppearance") then pbr+=1 end
        if child:IsA("Model") then nested+=1 end
        if not allowed[child.ClassName] then unsupported+=1 end
    end
    local _, size=obj:GetBoundingBox()
    return {name=obj.Name, selector=packPath(root,obj), instances=#descendants,
        parts=parts, meshes=counts.MeshPart or 0, scripts=scripts, pbr=pbr,
        nestedModels=nested, unsupported=unsupported, counts=counts,visualComponents=visualComponents,
        bounds={size.X,size.Y,size.Z},
        technicalCandidate=parts>0 and parts<=MAX_PARTS and #descendants<=MAX_DESCENDANTS
            and scripts==0 and unsupported==0 and math.max(size.X,size.Y,size.Z)<=512}
end
local function inspectPack(root: Model)
    local all=root:GetDescendants()
    assert(#all<=10000,"Pack exceeds 10,000-instance inspection limit")
    local candidates={}
    local totalModels=0
    local scripts=0
    for _, obj in all do
        if obj:IsA("LuaSourceContainer") then scripts+=1 end
        if obj:IsA("Model") then
            totalModels+=1
            if #candidates<256 then table.insert(candidates,describeModel(root,obj)) end
        end
    end
    table.sort(candidates,function(a,b)
        if a.technicalCandidate~=b.technicalCandidate then return a.technicalCandidate end
        if a.nestedModels~=b.nestedModels then return a.nestedModels<b.nestedModels end
        if a.instances~=b.instances then return a.instances<b.instances end
        return Http:JSONEncode(a.selector)<Http:JSONEncode(b.selector)
    end)
    local result={schemaVersion=1, totalInstances=#all,totalModels=totalModels,
        scriptsInPack=scripts, inventoryTruncated=totalModels>#candidates,candidates=candidates}
    if cfg.components == true then
        -- Detached mixed-content inventory. Never read Source, execute, parent or
        -- require third-party code. Only bounded class counts and visual properties.
        local counts, components, codeRows = {}, {}, {}
        local totalComponents = 0
        for _, obj in all do
            counts[obj.ClassName]=(counts[obj.ClassName] or 0)+1
            local kind = nil
            if obj:IsA("LuaSourceContainer") then
                kind="code"
                if #codeRows<128 then
                    local ok, source=pcall(function() return obj.Source end)
                    local row={name=obj.Name:sub(1,120),class=obj.ClassName,sourceReadable=ok,signals={},importAuthorized=false}
                    if ok and type(source)=="string" then
                        local encoding=game:GetService("EncodingService")
                        row.sourceBytes=#source
                        row.sha256=buffer.tostring(encoding:Base64Encode(encoding:ComputeBufferHash(buffer.fromstring(source),Enum.HashAlgorithm.Sha256)))
                        local lower=string.lower(source)
                        for _,entry in {{"require","require%s*%("},{"numericRequire","require%s*%(%s*%d"},{"loadstring","loadstring"},{"http","httpservice"},{"getfenv","getfenv"},{"setfenv","setfenv"},{"remote","remoteevent"},{"assetLoad","loadasset"},{"teleport","teleportservice"},{"datastore","datastoreservice"}} do
                            if string.find(lower,entry[2]) then table.insert(row.signals,entry[1]) end
                        end
                    end
                    table.insert(codeRows,row)
                end
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then kind="vfx"
            elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then kind="ui"
            elseif obj:IsA("Decal") then kind="texture"
            elseif obj:IsA("Tool") then kind="tool"
            end
            if kind then
                totalComponents+=1
                if #components<256 then
                    local path=packPath(root,obj)
                    local row={class=obj.ClassName,name=obj.Name:sub(1,120),kind=kind,
                        selector=if #path<=32 then path else nil, importAuthorized=false}
                    if obj:IsA("ParticleEmitter") then
                        row.texture=obj.Texture
                        row.rate=obj.Rate
                        row.lifetime={obj.Lifetime.Min,obj.Lifetime.Max}
                        row.speed={obj.Speed.Min,obj.Speed.Max}
                        row.enabled=obj.Enabled
                    elseif obj:IsA("Beam") or obj:IsA("Trail") then
                        row.texture=obj.Texture
                        row.enabled=obj.Enabled
                    elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                        row.image=obj.Image
                    elseif obj:IsA("Decal") then
                        row.texture=obj.Texture
                    end
                    table.insert(components,row)
                end
            end
        end
        result.componentInventory={classes=counts,total=totalComponents,codeReview=codeRows,codeReviewTruncated=scripts>#codeRows,
            truncated=totalComponents>#components,rows=components,codeExecuted=false}
    end
    if cfg.components == true then
        local a=audit(root)
        result.staticAudit={allowed=a.allowed,issues=a.issues,inspectionComplete=a.inspectionComplete,parts=a.parts}
        for _,candidate in candidates do
            if candidate.technicalCandidate then
                local selectedModel=selectPackModel(root,candidate.selector)
                local clone=selectedModel:Clone()
                if clone and clone.Parent==nil and #clone:GetDescendants()==#selectedModel:GetDescendants() then
                    local sub=audit(clone)
                    result.sampleAudit={name=candidate.name,selector=candidate.selector,allowed=sub.allowed,issues=sub.issues,inspectionComplete=sub.inspectionComplete,parts=sub.parts}
                end
                if clone then clone:Destroy() end
                break
            end
        end
    end
    -- Automatic sample is a technical extraction proof, NOT visual selection or approval.
    local selected=nil
    if cfg.selector then
        selected=selectPackModel(root,cfg.selector)
    elseif cfg.sample==true then
        for _, item in candidates do
            if item.technicalCandidate then selected=selectPackModel(root,item.selector);break end
        end
    end
    if selected then
        local info=describeModel(root,selected)
        assert(info.technicalCandidate,"Selected model exceeds basic extraction policy")
        local clone=selected:Clone()
        assert(clone and clone.Parent==nil and clone:IsA("Model"),"Detached clone failed")
        assert(#clone:GetDescendants()==#selected:GetDescendants(),"Clone omitted descendants (Archivable)")
        local report=audit(clone)
        local ok,evidence=pcall(function()
            local data=game:GetService("SerializationService"):SerializeInstancesAsync({clone})
            local encoding=game:GetService("EncodingService")
            return {bytes=buffer.len(data),sha256Base64=buffer.tostring(encoding:Base64Encode(encoding:ComputeBufferHash(data,Enum.HashAlgorithm.Sha256)))}
        end)
        clone:Destroy()
        result.extraction={name=info.name,selector=info.selector,instances=info.instances,
            detached=true,audit=report,serialization=if ok then evidence else {unavailable=true,reason=tostring(evidence)},
            visualApproved=false,importAuthorized=false}
    end
    root:Destroy()
    return output({pack=result})
end

local model = loadAsset()
if cfg.mode == "pack_inventory" then return inspectPack(model) end
local report = audit(model)
if cfg.mode == "audit" then
    -- Official serialization probe: only fingerprint and byte count, never
    -- publish or export a third-party binary to this public repository.
    local ok, evidence = pcall(function()
        local serialized = game:GetService("SerializationService"):SerializeInstancesAsync({model})
        local encoding = game:GetService("EncodingService")
        local digest = encoding:ComputeBufferHash(serialized, Enum.HashAlgorithm.Sha256)
        return {bytes=buffer.len(serialized), sha256Base64=buffer.tostring(encoding:Base64Encode(digest))}
    end)
    if ok then
        report.serialization = evidence
    else
        report.serialization = {unavailable=true, reason=tostring(evidence)}
    end
    model:Destroy()
    return output({audit=report})
end
assert(cfg.mode == "apply", "Unknown operation")
assert(game.PlaceVersion == cfg.expectedVersion, "Place version changed; create a new plan")
assert(report.allowed, "Asset failed static policy: " .. table.concat(report.issues,", "))
assert(#report.signature == #cfg.signature, "Asset changed since review")
for i, value in report.signature do
    assert(value == cfg.signature[i], "Asset changed since review")
end
local root = managedRoot()
assert(not findManaged(root,cfg.managedId), "Managed asset already exists; refusing duplicate")
-- Sanitize only the detached approved decoration. No existing scene objects changed.
for _, obj in model:GetDescendants() do
    for name in obj:GetAttributes() do obj:SetAttribute(name,nil) end
    for _, tag in game:GetService("CollectionService"):GetTags(obj) do
        game:GetService("CollectionService"):RemoveTag(obj,tag)
    end
    if obj:IsA("BasePart") then
        obj.Anchored = true
        obj.CanCollide = false
        obj.CanTouch = false
        obj.CanQuery = false
    end
end
for name in model:GetAttributes() do model:SetAttribute(name,nil) end
for _, tag in game:GetService("CollectionService"):GetTags(model) do game:GetService("CollectionService"):RemoveTag(model,tag) end
model.Name = cfg.managedId
model:SetAttribute("RSManagedId",cfg.managedId)
model:SetAttribute("RSAssetId",cfg.assetId)
model:SetAttribute("Biome",cfg.biome)
model:PivotTo(CFrame.new(cfg.position[1],cfg.position[2],cfg.position[3]) * CFrame.Angles(0,math.rad(cfg.yaw),0))
if not root then
    root=Instance.new("Folder")
    root.Name="RSManagedAssets"
    root:SetAttribute("RSOwner","RobloxStudiosStaticV1")
    root.Parent=Workspace
end
model.Parent=root
Assets:SavePlaceAsync({SaveWithoutPublish=false})
return output({saved=true,managedId=cfg.managedId,parts=report.parts})
