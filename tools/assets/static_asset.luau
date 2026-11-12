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
            table.insert(record,{dep(obj.ColorMap),dep(obj.NormalMap),dep(obj.MetalnessMap),dep(obj.RoughnessMap),obj.AlphaMode.Name})
        end
        table.insert(records,Http:JSONEncode(record))
    end
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
local model = loadAsset()
local report = audit(model)
if cfg.mode == "audit" then
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
