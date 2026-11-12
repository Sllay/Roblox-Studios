--!strict
-- Read-only structural snapshot. No changes to the DataModel.
local HttpService = game:GetService("HttpService")
local root = game:GetService("Workspace")
local objects = {}
local MAX = 5000
local all = root:GetDescendants()
local function vec(v: Vector3)
    return {v.X, v.Y, v.Z}
end
for i, obj in all do
    if i > MAX then break end
    local managed = obj:GetAttribute("RSManagedId")
    local record: {[string]: any} = {
        path = obj:GetFullName(), class = obj.ClassName,
        managedId = if typeof(managed) == "string" then managed else "",
    }
    if obj:IsA("BasePart") then
        record.cframe = {obj.CFrame:GetComponents()}
        record.size = vec(obj.Size)
        record.color = {obj.Color.R, obj.Color.G, obj.Color.B}
        record.material = obj.Material.Name
        record.anchored = obj.Anchored
        record.canCollide = obj.CanCollide
        record.transparency = obj.Transparency
        if obj:IsA("MeshPart") then
            record.meshId = obj.MeshId
            record.textureId = obj.TextureID
        end
    elseif obj:IsA("Model") then
        record.pivot = {obj:GetPivot():GetComponents()}
    end
    table.insert(objects, record)
end
return HttpService:JSONEncode({
    schemaVersion = 1, universeId = tostring(game.GameId),
    placeId = tostring(game.PlaceId), objects = objects,
    truncated = #all > MAX, total = #all,
})
