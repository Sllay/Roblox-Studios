--!strict
-- T1-F6. The server keeps generated native Terrain intact. Roblox instance
-- streaming owns client replication; it does not change the domain or saves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LegacyProfile = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("WorldProfile"))

type RuntimeProfile = {
    GENERATOR_VERSION: number, CELL: number, CHUNK_STUDS: number, PLAY_EDGE: number,
    CHUNK_RADIUS: number, INITIAL_CHUNKS: {number},
    BOUNDS: {xMin: number, xMax: number, yMin: number, yMax: number, zMin: number, zMax: number},
    validSeed: (any) -> boolean,
    chunkAt: (number) -> number,
    chunkBounds: (number) -> (number, number),
    spawn: (number) -> {x: number, y: number, z: number},
    signature: (number) -> string,
    sample: (number, number, number) -> {
        height: number, wet: boolean, shore: boolean, riverDist: number,
        material: string, waterSurface: number?,
    },
    naturalSites: ((number, number) -> {{id: string, x: number, y: number, z: number,
        item: string, initialAmount: number}})?,
}
local Profile: RuntimeProfile = LegacyProfile
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
local totalChunkMs = 0
local peakChunkMs = 0
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

function World.metrics()
    return {
        chunks = World.getChunkCount(), voxels = voxelCount, waterCells = waterCount,
        totalChunkMs = totalChunkMs, peakChunkMs = peakChunkMs,
        decorations = if scene then #scene:GetDescendants() else 0,
    }
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
            wall.Position = Vector3.new(side * (Profile.PLAY_EDGE + 2), 20, 0)
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
                -- Foreground silhouettes must be the SAME recognizable
                -- stylized-tree vocabulary, not black triangular placeholders.
                local silhouette = Instance.new("Model")
                silhouette.Name = "DarkTreeSilhouette_" .. tostring(i)
                silhouette:SetAttribute("ER_VisualLayer", "foreground")
                local height = 4.5 + (i % 3) * 1.1
                local darkWood = Color3.fromRGB(25, 36, 31)
                local darkLeaf = Color3.fromRGB(25, 46, 39)
                part(silhouette, "Trunk", Vector3.new(0.9, height, 0.9),
                    Vector3.new(x, surface.height + height * 0.5, z),
                    darkWood)
                for k = 1, 3 do
                    local canopyWidth = 4.5 - k * 0.45
                    part(silhouette, "Canopy", Vector3.new(canopyWidth, 2.8, canopyWidth),
                        Vector3.new(x, surface.height + height * 0.75 + k * 1.4, z),
                        darkLeaf, Enum.PartType.Ball)
                end
                silhouette.Parent = chunkFolder
            end
        end
    end
    if math.abs(id) > LegacyProfile.CHUNK_RADIUS and Profile.naturalSites then
        for _, site in ipairs(Profile.naturalSites(seed, id)) do
            local model = Instance.new("Model")
            model.Name = site.id
            model:SetAttribute("ER_VisualLayer", "background")
            if site.item == "wood" then
                part(model, "Trunk", Vector3.new(1.7, 9, 1.7),
                    Vector3.new(site.x, site.y + 4, site.z), Color3.fromRGB(91, 62, 46))
                for layer = 1, 3 do
                    local width = 8.6 - layer * 1.5
                    part(model, "Canopy", Vector3.new(width, 4.1, width),
                        Vector3.new(site.x, site.y + 5 + layer * 2, site.z),
                        Color3.fromRGB(54, 93 + layer * 10, 62), Enum.PartType.Ball)
                end
            else
                local rock = part(model, "Outcrop", Vector3.new(6, 4.5, 4.5),
                    Vector3.new(site.x, site.y + 1.2, site.z),
                    if site.item == "iron" then Color3.fromRGB(124, 103, 90) else Color3.fromRGB(124, 128, 125))
                rock.Material = Enum.Material.Slate
                rock.Orientation = Vector3.new(15, (id * 17) % 60, 10)
            end
            model.Parent = chunkFolder
        end
    elseif math.abs(id)>=3 then
        for i=1,5 do
            local x=xmin+i*11+((seed+i*13+id*47)%5)-2
            local z=-24-(i%3)*7
            local surface=Profile.sample(seed,x,z)
            if not surface.wet then
                local tree=Instance.new("Model")
                tree.Name="Forest_"..tostring(i)
                local y=surface.height
                part(tree,"Trunk",Vector3.new(1.5,9.2,1.5),
                    Vector3.new(x,y+4.6,z),Color3.fromRGB(86,66,49))
                for crown=1,3 do
                    local width=7.5-crown*1.15
                    part(tree,"Canopy",Vector3.new(width,4,width),
                        Vector3.new(x,y+5+crown*2.1,z),Color3.fromRGB(56,102+crown*7,67),Enum.PartType.Ball)
                end
                tree.Parent=chunkFolder
            end
        end
    end
    chunkFolder.Parent = scene
end

local function createChunk(seed: number, id: number): (boolean, string?)
    if generated[id] then return true, nil end
    if math.abs(id)>Profile.CHUNK_RADIUS or id%1~=0 then return fail("invalid_chunk") end
    if failure then return false, failure end
    local startedAt = os.clock()
    local b = Profile.BOUNDS
    local resolution = Profile.CELL
    local xmin,xmax = Profile.chunkBounds(id)
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
        local columns={}
        for iz=1,sz do
            columns[iz]=Profile.sample(seed,x,b.zMin+(iz-0.5)*resolution)
        end
        for iy = 1, sy do
            solids[ix][iy], liquids[ix][iy], materials[ix][iy] = {}, {}, {}
            local bottom = b.yMin + (iy - 1) * resolution
            for iz = 1, sz do
                local sample=columns[iz]
                local solid = math.clamp((sample.height - bottom) / resolution, 0, 1)
                local candidate = if sample.waterSurface then
                    math.clamp((sample.waterSurface - bottom) / resolution, 0, 1) else 0
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
    local chunkMs = (os.clock() - startedAt) * 1000
    totalChunkMs += chunkMs
    peakChunkMs = math.max(peakChunkMs, chunkMs)
    workspace:SetAttribute("ER_WorldVoxelCount", voxelCount)
    workspace:SetAttribute("ER_WorldWaterCells", waterCount)
    workspace:SetAttribute("ER_WorldChunkCount", World.getChunkCount())
    return true, nil
end

function World.activate(seed: number, progress: ((number, string) -> ())?,
        developmentProfile: RuntimeProfile?): (boolean, string?)
    if active then return false, "world_already_active" end
    if generating then return false, "world_generation_in_progress" end
    if failure then return false, failure end
    if not Profile.validSeed(seed) then return fail("invalid_world_seed") end
    if developmentProfile then Profile = developmentProfile end
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

local function withinBounds(x: number): boolean
    return x >= Profile.BOUNDS.xMin and x < Profile.BOUNDS.xMax
end

function World.isLoadedAt(x: number): boolean
    return withinBounds(x) and generated[Profile.chunkAt(x)]==true
end

function World.ensureNear(seed: number, x: number): (boolean, string?)
    if not active or currentSeed~=seed then return false,"world_not_ready" end
    if failure then return false,failure end
    if generating then return false,"world_generation_in_progress" end
    if not withinBounds(x) then return false,"outside_region" end
    local current=Profile.chunkAt(x)
    local west,east=Profile.chunkAt(x-38),Profile.chunkAt(x+38)
    local wanted={current}
    for index=west,east do if index~=current then table.insert(wanted,index) end end
    for _,index in ipairs(wanted) do
        if not generated[index] then
            generating=true
            local invoked,ok,reason=pcall(createChunk,seed,index)
            generating=false
            if not invoked then return fail("terrain_stream_exception") end
            if not ok then return false,reason end
            phase="ready"
        end
    end
    return true,nil
end

return World
