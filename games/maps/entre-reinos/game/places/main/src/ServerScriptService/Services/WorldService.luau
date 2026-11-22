--!strict
-- T1-R1: bounded runtime Terrain for a NEW, empty Entre Reinos Place.
-- Uses native solid/material/liquid voxel channels; refuses to overwrite existing Terrain.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldProfile = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("WorldProfile"))
local Terrain = workspace.Terrain

local WorldService = {}
local activated = false

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, shape: Enum.PartType?)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.Position = position
    p.Material = Enum.Material.SmoothPlastic
    p.Color = color
    p.CastShadow = false
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    if shape then p.Shape = shape end
    p.Parent = parent
    return p
end

local function tree(parent: Instance, x: number, z: number, y: number, scale: number, silhouette: boolean)
    local model = Instance.new("Model")
    model.Name = if silhouette then "ForegroundSilhouette" else "BackgroundTree"
    local black = Color3.new(0, 0, 0)
    local bark = if silhouette then black else Color3.fromRGB(81, 55, 47)
    local leaves = if silhouette then black else Color3.fromRGB(65, 112, 73)
    part(model, "Trunk", Vector3.new(1.7, 8, 1.7) * scale, Vector3.new(x, y + 4 * scale, z), bark)
    for tier = 1, 3 do
        local crown = part(model, "NeedleCrown", Vector3.new(6.6 - tier, 4.3, 6.6 - tier) * scale,
            Vector3.new(x, y + (5.5 + tier * 2.2) * scale, z), leaves, Enum.PartType.Ball)
        crown.Transparency = 0
    end
    if not silhouette then
        -- An interactable tree can later expose T1-R2 jobs through a lane-side anchor.
        local anchor = part(model, "WorkAnchor", Vector3.new(2, 3, 2),
            Vector3.new(x, WorldProfile.sample(model:GetAttribute("Seed") or 1, x, 0).height + 2, 0),
            Color3.new(0, 0, 0))
        anchor.Transparency = 1
        anchor:SetAttribute("InteractionKind", "Tree")
    end
    model.Parent = parent
end

local function buildDecorations(seed: number)
    local folder = Instance.new("Folder")
    folder.Name = "ER_World_3D"
    folder:SetAttribute("GeneratorVersion", WorldProfile.GENERATOR_VERSION)
    folder:SetAttribute("Seed", seed)
    for i = 1, 18 do
        local x = -119 + i * 12
        local z = -22 - (i % 3) * 7
        local surface = WorldProfile.sample(seed, x, z)
        if not surface.wet and surface.riverDist > 20 then
            local model = Instance.new("Model")
            model.Name = "TreeSite_" .. tostring(i)
            model:SetAttribute("Seed", seed)
            local y = surface.height
            part(model, "Trunk", Vector3.new(1.7, 8.8, 1.7), Vector3.new(x, y + 4.4, z), Color3.fromRGB(89, 61, 51))
            for k = 1, 3 do
                part(model, "Canopy", Vector3.new(7 - k, 4.2, 7 - k),
                    Vector3.new(x, y + 5 + k * 2.2, z), Color3.fromRGB(62, 118, 80), Enum.PartType.Ball)
            end
            local anchor = part(model, "WorkAnchor", Vector3.new(2, 3, 2),
                Vector3.new(x, WorldProfile.sample(seed, x, 0).height + 2, 0), Color3.new(0,0,0))
            anchor.Transparency = 1
            anchor:SetAttribute("InteractionKind", "Tree")
            model.Parent = folder
        end
    end
    -- Strict black 3D models, kept away from the important playable center.
    for i = 1, 10 do
        local x = -120 + i * 23
        local z = 40
        local surface = WorldProfile.sample(seed, x, z)
        if not surface.wet then
            local grass = Instance.new("WedgePart")
            grass.Name = "BlackForegroundGrass"
            grass.Size = Vector3.new(2.7, 5 + (i % 3) * 2, 3.5)
            grass.CFrame = CFrame.new(x, surface.height + grass.Size.Y / 2, z)
            grass.Anchored = true
            grass.Material = Enum.Material.SmoothPlastic
            grass.Color = Color3.new(0, 0, 0)
            grass.CastShadow = false
            grass.CanCollide = false
            grass.CanQuery = false
            grass.CanTouch = false
            grass.Parent = folder
        end
    end
    folder.Parent = workspace
end

function WorldService.activate(seed: number): (boolean, string?)
    if activated then
        return false, "world_already_active"
    end
    if not WorldProfile.validSeed(seed) then
        return false, "invalid_world_seed"
    end
    local b = WorldProfile.BOUNDS
    local region = Region3.new(Vector3.new(b.xMin, b.yMin, b.zMin), Vector3.new(b.xMax, b.yMax, b.zMax))
    local resolution = WorldProfile.CELL
    -- Fail closed. Never Terrain:Clear() or overwrite someone else's map.
    local successRead, existing = pcall(function()
        return Terrain:ReadVoxelChannels(region, resolution, {"SolidOccupancy", "LiquidOccupancy"})
    end)
    if not successRead or type(existing) ~= "table" then
        return false, "terrain_read_failed"
    end
    local sx = (b.xMax - b.xMin) / resolution
    local sy = (b.yMax - b.yMin) / resolution
    local sz = (b.zMax - b.zMin) / resolution
    for ix = 1, sx do
        for iy = 1, sy do
            for iz = 1, sz do
                if existing.SolidOccupancy[ix][iy][iz] > 0.001
                    or existing.LiquidOccupancy[ix][iy][iz] > 0.001 then
                    return false, "nonempty_terrain_refuses_overwrite"
                end
            end
        end
    end

    local solids, liquids, materials = {}, {}, {}
    local liquidCells = 0
    local solidCells = 0
    for ix = 1, sx do
        solids[ix], liquids[ix], materials[ix] = {}, {}, {}
        local x = b.xMin + (ix - 0.5) * resolution
        for iy = 1, sy do
            solids[ix][iy], liquids[ix][iy], materials[ix][iy] = {}, {}, {}
            local bottom = b.yMin + (iy - 1) * resolution
            for iz = 1, sz do
                local z = b.zMin + (iz - 0.5) * resolution
                local sample = WorldProfile.sample(seed, x, z)
                local solid = math.clamp((sample.height - bottom) / resolution, 0, 1)
                local waterCandidate = if sample.riverDist < 23 then
                    math.clamp((WorldProfile.WATER_SURFACE - bottom) / resolution, 0, 1)
                    else 0
                local liquid = math.min(1 - solid, waterCandidate)
                local material = if solid > 0 then Enum.Material[sample.material] else Enum.Material.Air
                solids[ix][iy][iz] = solid
                liquids[ix][iy][iz] = liquid
                materials[ix][iy][iz] = material
                if solid > 0.5 then solidCells += 1 end
                if liquid > 0.5 then liquidCells += 1 end
            end
        end
    end
    if liquidCells == 0 or solidCells == 0 then
        return false, "invalid_world_geometry"
    end
    local okWrite, writeError = pcall(function()
        Terrain:WriteVoxelChannels(region, resolution, {
            SolidMaterial = materials,
            SolidOccupancy = solids,
            LiquidOccupancy = liquids,
        })
    end)
    if not okWrite then
        -- Result is potentially partially written. Never blind-retry without inspection.
        warn("[EntreReinos] Terrain write failed (review required): ", writeError)
        return false, "terrain_write_uncertain"
    end
    local okVerify, readback = pcall(function()
        return Terrain:ReadVoxelChannels(region, resolution, {"SolidOccupancy", "LiquidOccupancy"})
    end)
    if not okVerify or type(readback) ~= "table" then
        return false, "terrain_readback_failed"
    end
    local seenWater = false
    local seenSolid = false
    for ix = 1, sx do
        for iy = 1, sy do
            for iz = 1, sz do
                if math.abs(readback.SolidOccupancy[ix][iy][iz] - solids[ix][iy][iz]) > 0.02
                    or math.abs(readback.LiquidOccupancy[ix][iy][iz] - liquids[ix][iy][iz]) > 0.02 then
                    return false, "terrain_readback_diff"
                end
                if readback.SolidOccupancy[ix][iy][iz] > 0.5 then seenSolid = true end
                if readback.LiquidOccupancy[ix][iy][iz] > 0.5 then seenWater = true end
            end
        end
    end
    if not seenSolid or not seenWater then
        return false, "terrain_verify_missing_channels"
    end
    buildDecorations(seed)
    local startArea = workspace:FindFirstChild("StartArea")
    if startArea then
        local floor = startArea:FindFirstChild("Floor")
        if floor and floor:IsA("BasePart") then
            floor.CanCollide = false
            floor.Transparency = 1
        end
        local spawn = startArea:FindFirstChild("Spawn")
        if spawn and spawn:IsA("SpawnLocation") then
            local pos = WorldProfile.spawn(seed)
            spawn.Position = Vector3.new(pos.x, pos.y - 2, pos.z)
            spawn.Transparency = 1
            spawn.CanCollide = false
        end
    end
    workspace:SetAttribute("ER_WorldSignature", WorldProfile.signature(seed))
    workspace:SetAttribute("ER_WorldVoxelCount", sx * sy * sz)
    workspace:SetAttribute("ER_WorldWaterCells", liquidCells)
    activated = true
    return true, nil
end

function WorldService.isActive(): boolean
    return activated
end

return WorldService
