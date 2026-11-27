--!strict
-- T1-F6. The server keeps generated native Terrain intact. Roblox instance
-- streaming owns client replication; it does not change the domain or saves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LegacyProfile = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("WorldProfile"))

local Vegetation=require(script.Parent:WaitForChild("VegetationScene"))
local Scenery = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("SceneryProfile"))

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
local Profile: RuntimeProfile = LegacyProfile :: any
local terrainMaterials: {[string]: Enum.Material} = {
    Grass=Enum.Material.Grass, Ground=Enum.Material.Ground, Mud=Enum.Material.Mud,
    Sand=Enum.Material.Sand, Rock=Enum.Material.Rock, Slate=Enum.Material.Slate,
}
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
local sceneryReady: {[string]: boolean} = {}
local sceneryCount=0
local sceneryVoxels=0
local sceneryPeakMs=0
local decorativeCount=0
local decorativeMs=0

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
        vegetationModels=decorativeCount,vegetationMs=decorativeMs,
        sceneryVolumes=sceneryCount,sceneryVoxels=sceneryVoxels,sceneryPeakMs=sceneryPeakMs,
    }
end

local function populateVegetation(layer: Folder,seed: number,id: number,row: number)
    local startedAt=os.clock()
    for _,item in ipairs(Scenery.vegetation(seed,id,row)) do
        Vegetation.place(layer,item.kind,Vector3.new(item.x,item.y,item.z),
            item.size,item.angle,item.tint,row<=-2)
        decorativeCount+=1
    end
    decorativeMs+=(os.clock()-startedAt)*1000
end

local function decoratedChunk(seed: number,id: number)
    if not scene then
        local f = Instance.new("Folder")
        f.Name = "ER_World_3D"
        f:SetAttribute("GeneratorVersion", Profile.GENERATOR_VERSION)
        f:SetAttribute("Seed", seed)
        f:SetAttribute("SceneryVersion", Scenery.VERSION)
        f.Parent = workspace
        scene = f
        for _, side in ipairs({-1, 1}) do
            local wall = Instance.new("Part")
            wall.Name = "RegionEdge_" .. tostring(side)
            wall.Anchored = true
            wall.Size = Vector3.new(4, 200, 96)
            wall.Position = Vector3.new(side * (Profile.PLAY_EDGE + 2), 54, 0)
            wall.Transparency = 1
            wall.CanCollide = true
            wall:SetAttribute("ER_PlacementRole", "control")
            wall.CanTouch = false
            wall.CanQuery = false
            wall.Parent = f
        end
    end
    local chunkFolder = Instance.new("Folder")
    chunkFolder.Name = "Chunk_" .. tostring(id)
    populateVegetation(chunkFolder,seed,id,0)
    chunkFolder.Parent = scene
end

local function paintVolume(seed: number, id: number, bounds: any, sampler: any): (boolean, string?, number?, number?)
    local resolution = Profile.CELL
    local region = Region3.new(
        Vector3.new(bounds.xMin, bounds.yMin, bounds.zMin),
        Vector3.new(bounds.xMax, bounds.yMax, bounds.zMax))
    local sx = (bounds.xMax - bounds.xMin) / resolution
    local sy = (bounds.yMax - bounds.yMin) / resolution
    local sz = (bounds.zMax - bounds.zMin) / resolution
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
        local x = bounds.xMin + (ix - 0.5) * resolution
        local columns={}
        local columnMaterials={}
        for iz=1,sz do
            local column=sampler(seed,x,bounds.zMin+(iz-0.5)*resolution)
            local material=terrainMaterials[column.material]
            if not material then return fail("terrain_material_unsupported") end
            columns[iz]=column
            columnMaterials[iz]=material
        end
        for iy = 1, sy do
            solids[ix][iy], liquids[ix][iy], materials[ix][iy] = {}, {}, {}
            local bottom = bounds.yMin + (iy - 1) * resolution
            for iz = 1, sz do
                local sample=columns[iz]
                local solid = math.clamp((sample.height - bottom) / resolution, 0, 1)
                local candidate = if sample.waterSurface then
                    math.clamp((sample.waterSurface - bottom) / resolution, 0, 1) else 0
                local liquid = math.min(1 - solid, candidate)
                solids[ix][iy][iz] = solid
                liquids[ix][iy][iz] = liquid
                materials[ix][iy][iz] = if solid > 0 then columnMaterials[iz] else Enum.Material.Air
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
    return true,nil,sx*sy*sz,liquidCells
end

local function createChunk(seed: number,id: number): (boolean,string?)
    if generated[id] then return true,nil end
    if math.abs(id)>Profile.CHUNK_RADIUS or id%1~=0 then return fail("invalid_chunk") end
    if failure then return false,failure end
    local startedAt=os.clock()
    local xmin,xmax=Profile.chunkBounds(id)
    local bounds=table.clone(Profile.BOUNDS)
    bounds.xMin,bounds.xMax=xmin,xmax
    local ok,reason,volume,water=paintVolume(seed,id,bounds,Profile.sample)
    if not ok then return false,reason end
    phase = "decorate_chunk_" .. tostring(id)
    local decorated, reason = pcall(function()
        decoratedChunk(seed,id)
        return true
    end)
    if not decorated then
        warn("[EntreReinos][Terrain] Decoration error: ", reason)
        return fail("world_decoration_requires_new_server")
    end
    generated[id] = true
    voxelCount += volume or 0
    waterCount += water or 0
    local chunkMs = (os.clock() - startedAt) * 1000
    totalChunkMs += chunkMs
    peakChunkMs = math.max(peakChunkMs, chunkMs)
    workspace:SetAttribute("ER_WorldVoxelCount", voxelCount)
    workspace:SetAttribute("ER_WorldWaterCells", waterCount)
    workspace:SetAttribute("ER_WorldChunkCount", World.getChunkCount())
    return true, nil
end

local function createScenery(seed: number,id: number,row: number): (boolean,string?)
    local key=tostring(id).."_"..tostring(row)
    if sceneryReady[key] then return true,nil end
    local startedAt=os.clock()
    local ok,reason,volume=paintVolume(seed,id,Scenery.bounds(id,row),Scenery.sample)
    if not ok then return false,reason end
    local layer=Instance.new("Folder")
    layer.Name="Scenery_"..key
    layer:SetAttribute("ER_VisualLayer",if row==1 then "foreground" else "background")
    populateVegetation(layer,seed,id,row)
    layer.Parent=scene
    sceneryReady[key]=true
    sceneryCount+=1
    sceneryVoxels+=volume or 0
    sceneryPeakMs=math.max(sceneryPeakMs,(os.clock()-startedAt)*1000)
    workspace:SetAttribute("ER_SceneryVolumeCount",sceneryCount)
    return true,nil
end

-- One work list per camera envelope. Streaming clients still control their
-- replication; these flags report that the server wrote and read the region.
function World.prefetch(seed: number,x: number,velocity: number,initial: boolean?): (boolean,string?)
    if not active or seed~=currentSeed then return false,"world_not_ready" end
    if failure then return false,failure end
    if Profile.GENERATOR_VERSION~=2 then return true,nil end
    if generating then return false,"world_generation_in_progress" end
    local wanted={}
    local current=Profile.chunkAt(x)
    local direction=math.sign(velocity)
    for _,row in ipairs({0,1,-1,-2,-3}) do
        local west,east=Scenery.coverage(x,velocity,row)
        for id=west,east do
            local base=row==0 and math.abs(id)<=Profile.CHUNK_RADIUS
            local key=tostring(id).."_"..tostring(row)
            if (base and generated[id]) or (not base and sceneryReady[key]) then continue end
            local delta=id-current
            local priority=math.abs(delta)-(if delta*direction>0 then 0.6 else 0)
                +(if base then -7 elseif row==-3 then 1.8 elseif row==-2 then 0.8 else 0.3)
            table.insert(wanted,{row=row,id=id,base=base,priority=priority})
        end
    end
    table.sort(wanted,function(a,b) return a.priority<b.priority end)
    local limit=if initial then #wanted else math.min(3,#wanted)
    if limit==0 then return true,nil end
    generating=true
    for i=1,limit do
        local chunk=wanted[i]
        local invoked,ok,reason=pcall(if chunk.base then createChunk else createScenery,
            seed,chunk.id,chunk.row)
        if not invoked or not ok then
            generating=false
            if not invoked then return fail("terrain_prefetch_exception") end
            return false,reason
        end
        task.wait()
    end
    generating=false
    phase="ready"
    return true,nil
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
    if not withinBounds(x) then return false,"outside_region" end
    local current=Profile.chunkAt(x)
    local west,east=Profile.chunkAt(x-38),Profile.chunkAt(x+38)
    local wanted={current}
    for index=west,east do if index~=current then table.insert(wanted,index) end end
    for _,index in ipairs(wanted) do
        if not generated[index] then
            if generating then return false,"world_generation_in_progress" end
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
