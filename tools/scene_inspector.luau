--!strict
-- Roblox-Studios: read-only Place inspection. No SavePlaceAsync, no writes.
-- No Script execution. Physics and client rendering are NOT simulated.
local HttpService = game:GetService("HttpService")
local workspace = game:GetService("Workspace")
local LIMIT = 2500
local SCAN_LIMIT = 30000
local objects = {}
local byClass: {[string]: number} = {}
local maxDepth = 8
local count = 0
local examined = 0
local partsSeen = 0

local function finite(n: number): number
    if n ~= n or math.abs(n) > 1000000 then
        return 0
    end
    return math.floor(n * 100) / 100
end

local function pathFor(instance: Instance): string
    local segments = {}
    local cursor: Instance? = instance
    while cursor ~= nil and cursor ~= workspace and #segments < maxDepth do
        table.insert(segments, 1, cursor.Name:sub(1, 60))
        cursor = cursor.Parent
    end
    return table.concat(segments, "/")
end

for _, instance in workspace:GetDescendants() do
    examined += 1
    if examined > SCAN_LIMIT then
        break
    end
    local className = instance.ClassName
    byClass[className] = (byClass[className] or 0) + 1
    if instance:IsA("BasePart") then
        partsSeen += 1
        if count < LIMIT then
            local pos = instance.Position
            local size = instance.Size
            local rawBiome = instance:GetAttribute("Biome")
            local rawAsset = instance:GetAttribute("AssetId")
            local biome = if typeof(rawBiome) == "string" then (rawBiome :: string):sub(1, 48) else "unclassified"
            local assetId = if typeof(rawAsset) == "string" or typeof(rawAsset) == "number" then tostring(rawAsset) else nil
            table.insert(objects, {
                path = pathFor(instance),
                class = className,
                name = instance.Name:sub(1, 80),
                position = {finite(pos.X), finite(pos.Y), finite(pos.Z)},
                size = {finite(size.X), finite(size.Y), finite(size.Z)},
                color = {
                    math.floor(instance.Color.R * 255),
                    math.floor(instance.Color.G * 255),
                    math.floor(instance.Color.B * 255)
                },
                material = instance.Material.Name,
                anchored = instance.Anchored,
                canCollide = instance.CanCollide,
                biome = biome,
                assetId = assetId
            })
            count += 1
        end
    end
end

local payload = {
    schemaVersion = 1,
    universeId = tostring(game.GameId),
    placeId = tostring(game.PlaceId),
    objects = objects,
    stats = {
        sampledParts = count,
        totalPartsScanned = partsSeen,
        examinedInstances = math.min(examined, SCAN_LIMIT),
        scanTruncated = examined > SCAN_LIMIT,
        objectsTruncated = partsSeen > LIMIT,
        classCounts = byClass,
    },
    coordinateSystem = "X,Z top-down; Y is height; units are studs",
    note = "Read-only structural report, not a screenshot. Unknown biomes are unclassified."
}
return HttpService:JSONEncode(payload)
