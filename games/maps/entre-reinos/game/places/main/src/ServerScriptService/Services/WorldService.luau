--!strict
-- T1-R1. Deterministic 3D Terrain in four isolated X-chunks.
-- The private world server generates the central/eastern 3 chunks before spawning;
-- the western chunk streams when the player approaches. Lobby NEVER calls this service.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profile = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("WorldProfile"))
local Terrain = workspace.Terrain
local World = {}
local active = false
local generating = false
local failure: string? = nil
local phase = "idle"
local currentSeed: number? = nil
local generated: {[number]: boolean} = {}
local voxelCount = 0
local waterCount = 0
local scene: Folder? = nil

local function fail(reason: string): (boolean, string?)
    failure = reason
    phase = "failed"
    warn("[EntreReinos][Terrain] " .. reason)
    return false, reason
end
function World.getFailure(): string? return failure end
function World.getPhase(): string return phase end
function World.isActive(): boolean return active end
function World.getChunkCount(): number
    local n = 0
    for _, present in pairs(generated) do if present then n += 1 end end
    return n
end
function World.reportException()
    failure = "terrain_activation_exception"
    phase = "failed"
end

local function part(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, shape: Enum.PartType?)
    local obj = Instance.new("Part")
    obj.Name = name
    obj.Anchored = true
    obj.Size = size
    obj.Position = pos
    obj.Color = color
    obj.Material = Enum.Material.SmoothPlastic
    obj.CastShadow = false
    obj.CanCollide = false
    obj.CanQuery = false
    obj.CanTouch = false
    if shape then obj.Shape = shape end
    obj.Parent = parent
    return obj
end

local function decoratedChunk(seed: number, id: number, xmin: number, xmax: number)
    if not scene then
        local f = Instance.new("Folder")
        f.Name = "ER_World_3D"
        f:SetAttribute("GeneratorVersion", Profile.GENERATOR_VERSION)
        f:SetAttribute("Seed", seed)
        f.Parent = workspace
        scene = f
        for _, side in ipairs({-1, 1}) do
            local wall = Instance.new("Part")
            wall.Name = "RegionEdge_" .. tostring(side)
            wall.Anchored = true
            wall.Size = Vector3.new(3, 120, 96)
            wall.Position = Vector3.new(side * 126, 20, 0)
            wall.Transparency = 1
            wall.CanCollide = true
            wall.CanTouch = false
            wall.CanQuery = false
            wall.Parent = f
        end
    end
    local chunkFolder = Instance.new("Folder")
    chunkFolder.Name = "Chunk_" .. tostring(id)
    for i = 1, 18 do
        local x = -119 + i * 12
        if x >= xmin and x < xmax then
            local z = -22 - (i % 3) * 7
            local surface = Profile.sample(seed, x, z)
            if not surface.wet and surface.riverDist > 20 then
                local model = Instance.new("Model")
                model.Name = "TreeSite_" .. tostring(i)
                model:SetAttribute("Seed", seed)
                local y = surface.height
                part(model, "Trunk", Vector3.new(1.7, 8.8, 1.7),
                    Vector3.new(x, y + 4.4, z), Color3.fromRGB(89, 61, 51))
                for k = 1, 3 do
                    part(model, "Canopy", Vector3.new(7 - k, 4.2, 7 - k),
                        Vector3.new(x, y + 5 + k * 2.2, z),
                        Color3.fromRGB(62, 118, 80), Enum.PartType.Ball)
                end
                local anchor = part(model, "WorkAnchor", Vector3.new(2, 3, 2),
                    Vector3.new(x, Profile.sample(seed, x, 0).height + 2, 0), Color3.new(0, 0, 0))
                anchor.Transparency = 1
                anchor:SetAttribute("InteractionKind", "Tree")
                model.Parent = chunkFolder
            end
        end
    end
    for i = 1, 10 do
        local x = -120 + i * 23
        if x >= xmin and x < xmax then
            local z = 40
            local surface = Profile.sample(seed, x, z)
            if not surface.wet and math.abs(x) > 35 then
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
                grass.Parent = chunkFolder
            end
        end
    end
    chunkFolder.Parent = scene
end

local function createChunk(seed: number, id: number): (boolean, string?)
    if generated[id] then return true, nil end
    if id < 1 or id > Profile.CHUNK_COUNT then return fail("invalid_chunk") end
    if failure then return false, failure end
    local b = Profile.BOUNDS
    local resolution = Profile.CELL
    local xmin = b.xMin + (id - 1) * Profile.CHUNK_STUDS
    local xmax = xmin + Profile.CHUNK_STUDS
    local region = Region3.new(
        Vector3.new(xmin, b.yMin, b.zMin),
        Vector3.new(xmax, b.yMax, b.zMax))
    local sx = Profile.CHUNK_STUDS / resolution
    local sy = (b.yMax - b.yMin) / resolution
    local sz = (b.zMax - b.zMin) / resolution
    phase = "read_chunk_" .. tostring(id)
    local readOk, existing = pcall(function()
        return Terrain:ReadVoxelChannels(region, resolution, {"SolidOccupancy", "LiquidOccupancy"})
    end)
    if not readOk or type(existing) ~= "table" then return fail("terrain_read_failed") end
    for ix = 1, sx do
        for iy = 1, sy do
            for iz = 1, sz do
                if existing.SolidOccupancy[ix][iy][iz] > 0.001
                    or existing.LiquidOccupancy[ix][iy][iz] > 0.001 then
                    return fail("nonempty_terrain_refuses_overwrite")
                end
            end
        end
    end
    phase = "prepare_chunk_" .. tostring(id)
    local solids, liquids, materials = {}, {}, {}
    local solidCells = 0
    local liquidCells = 0
    for ix = 1, sx do
        solids[ix], liquids[ix], materials[ix] = {}, {}, {}
        local x = xmin + (ix - 0.5) * resolution
        for iy = 1, sy do
            solids[ix][iy], liquids[ix][iy], materials[ix][iy] = {}, {}, {}
            local bottom = b.yMin + (iy - 1) * resolution
            for iz = 1, sz do
                local z = b.zMin + (iz - 0.5) * resolution
                local sample = Profile.sample(seed, x, z)
                local solid = math.clamp((sample.height - bottom) / resolution, 0, 1)
                local candidate = if sample.riverDist < 23 then
                    math.clamp((Profile.WATER_SURFACE - bottom) / resolution, 0, 1) else 0
                local liquid = math.min(1 - solid, candidate)
                solids[ix][iy][iz] = solid
                liquids[ix][iy][iz] = liquid
                materials[ix][iy][iz] = if solid > 0 then Enum.Material[sample.material] else Enum.Material.Air
                if solid > 0.5 then solidCells += 1 end
                if liquid > 0.5 then liquidCells += 1 end
            end
        end
    end
    if solidCells == 0 then return fail("invalid_world_geometry") end
    phase = "write_chunk_" .. tostring(id)
    local writeOk, writeError = pcall(function()
        Terrain:WriteVoxelChannels(region, resolution, {
            SolidMaterial = materials,
            SolidOccupancy = solids,
            LiquidOccupancy = liquids,
        })
    end)
    if not writeOk then
        warn("[EntreReinos][Terrain] WriteVoxelChannels failed: ", writeError)
        return fail("terrain_write_uncertain")
    end
    phase = "verify_chunk_" .. tostring(id)
    local verifyOk, verified = pcall(function()
        return Terrain:ReadVoxelChannels(region, resolution,
            {"SolidOccupancy", "LiquidOccupancy", "SolidMaterial"})
    end)
    if not verifyOk or type(verified) ~= "table" then return fail("terrain_readback_failed") end
    for ix = 1, sx do
        for iy = 1, sy do
            for iz = 1, sz do
                if math.abs(verified.SolidOccupancy[ix][iy][iz] - solids[ix][iy][iz]) > 0.02
                    or math.abs(verified.LiquidOccupancy[ix][iy][iz] - liquids[ix][iy][iz]) > 0.02 then
                    return fail("terrain_readback_diff")
                end
                if solids[ix][iy][iz] > 0.01
                    and verified.SolidMaterial[ix][iy][iz] ~= materials[ix][iy][iz] then
                    return fail("terrain_material_readback_diff")
                end
            end
        end
    end
    phase = "decorate_chunk_" .. tostring(id)
    local decorated, reason = pcall(decoratedChunk, seed, id, xmin, xmax)
    if not decorated then
        warn("[EntreReinos][Terrain] Decoration error: ", reason)
        return fail("world_decoration_requires_new_server")
    end
    generated[id] = true
    voxelCount += sx * sy * sz
    waterCount += liquidCells
    workspace:SetAttribute("ER_WorldVoxelCount", voxelCount)
    workspace:SetAttribute("ER_WorldWaterCells", waterCount)
    workspace:SetAttribute("ER_WorldChunkCount", World.getChunkCount())
    return true, nil
end

function World.activate(seed: number, progress: ((number, string) -> ())?): (boolean, string?)
    if active then return false, "world_already_active" end
    if generating then return false, "world_generation_in_progress" end
    if failure then return false, failure end
    if not Profile.validSeed(seed) then return fail("invalid_world_seed") end
    generating = true
    currentSeed = seed
    for order, id in ipairs(Profile.INITIAL_CHUNKS) do
        if progress then progress((order - 1) / #Profile.INITIAL_CHUNKS,
            "Gerando região " .. tostring(order) .. "/" .. tostring(#Profile.INITIAL_CHUNKS)) end
        local ok, reason = createChunk(seed, id)
        if not ok then
            generating = false
            return false, reason
        end
        -- Yield to the network and render pipeline between independent regions.
        task.wait()
    end
    phase = "spawn"
    local start = workspace:FindFirstChild("StartArea")
    if start then
        local floor = start:FindFirstChild("Floor")
        if floor and floor:IsA("BasePart") then
            floor.CanCollide = false
            floor.Transparency = 1
        end
        local spawn = start:FindFirstChild("Spawn")
        if spawn and spawn:IsA("SpawnLocation") then
            local pos = Profile.spawn(seed)
            spawn.Position = Vector3.new(pos.x, pos.y - 2, pos.z)
            spawn.Transparency = 1
            spawn.CanCollide = false
        end
    end
    workspace:SetAttribute("ER_WorldSignature", Profile.signature(seed))
    phase = "ready"
    active = true
    generating = false
    if progress then progress(1, "Terreno inicial pronto") end
    return true, nil
end

function World.ensureNear(seed: number, x: number): (boolean, string?)
    if not active or currentSeed ~= seed then return false, "world_not_ready" end
    if failure then return false, failure end
    if generating then return false, "world_generation_in_progress" end
    -- Only the far-west chunk is deferred in T1-R1. The river (east) is ready
    -- before spawn, so swimming can be tested immediately.
    if x < -24 and not generated[1] then
        generating = true
        local ok, reason = createChunk(seed, 1)
        generating = false
        if ok then phase = "ready" end
        return ok, reason
    end
    return true, nil
end

return World
