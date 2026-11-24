--!strict
-- T1-R1: pure, deterministic, engine-independent world rules.
-- No Instances, Terrain writes or game-specific asset dependencies.
local WorldProfile = {}
WorldProfile.GENERATOR_VERSION = 1
WorldProfile.CELL = 4
WorldProfile.CHUNK_STUDS = 64
WorldProfile.CHUNK_RADIUS = 8
WorldProfile.CHUNK_COUNT = 17
WorldProfile.PLAY_EDGE = 540
WorldProfile.INITIAL_CHUNKS = {0, -1, 1, -2, 2}
WorldProfile.BOUNDS = {
    xMin = -544, xMax = 544,
    yMin = -32, yMax = 64,
    zMin = -48, zMax = 48,
}
WorldProfile.LANE_Z = 0
WorldProfile.WATER_SURFACE = 10
WorldProfile.RIVER_BASE_X = 76
WorldProfile.RIVER_HALF_WIDTH = 12

function WorldProfile.chunkAt(x: number): number
    return math.clamp(math.floor((x+32)/WorldProfile.CHUNK_STUDS),
        -WorldProfile.CHUNK_RADIUS,WorldProfile.CHUNK_RADIUS)
end

function WorldProfile.chunkBounds(index: number): (number,number)
    assert(index%1==0 and math.abs(index)<=WorldProfile.CHUNK_RADIUS,"invalid chunk index")
    local left=index*WorldProfile.CHUNK_STUDS-32
    return left,left+WorldProfile.CHUNK_STUDS
end

function WorldProfile.validSeed(seed: any): boolean
    return type(seed) == "number" and seed == seed and seed % 1 == 0 and seed >= 1 and seed <= 2147483646
end

local function clamp(x: number, lo: number, hi: number): number
    return math.max(lo, math.min(hi, x))
end

function WorldProfile.sample(seed: number, x: number, z: number)
    assert(WorldProfile.validSeed(seed), "invalid world seed")
    assert(x == x and z == z and math.abs(x) < 100000 and math.abs(z) < 100000, "invalid sample")
    local s = (seed % 32749) / 31
    local n1 = math.noise(x * 0.014 + s, z * 0.012, 1.7)
    local n2 = math.noise(x * 0.037, z * 0.043 + s, 2.2)
    local flat = clamp((math.abs(x) - 44) / 28, 0, 1)
    local depth = clamp((-z - 12) / 30, 0, 1)
    local hills = (n1 * 15 + n2 * 5) * flat
    local distantRidge = depth * depth * (13 + 15 * math.abs(n1))
    local rim=math.clamp((math.abs(x)-522)/22,0,1)
    local surface = math.min(62,16+hills+distantRidge+rim*rim*26)
    local riverCenter = WorldProfile.RIVER_BASE_X + 6 * math.noise(z * 0.018, s, 4.1)
    local riverDist = math.abs(x - riverCenter)
    local bankBlend = clamp((riverDist - WorldProfile.RIVER_HALF_WIDTH) / 11, 0, 1)
    -- A connected river bed across all Z, including the playable lane.
    local wet = riverDist <= WorldProfile.RIVER_HALF_WIDTH
    local height = if wet then -6 else -6 + (surface + 6) * (bankBlend * bankBlend * (3 - 2 * bankBlend))
    local shore = riverDist < WorldProfile.RIVER_HALF_WIDTH + 15
    local material = if wet then "Mud" elseif shore then "Sand" elseif height > 32 then "Rock" else "Grass"
    return {height = height, wet = wet, shore = shore, riverDist = riverDist, material = material}
end

function WorldProfile.spawn(seed: number)
    local ground = WorldProfile.sample(seed, 0, WorldProfile.LANE_Z)
    return {x = 0, y = ground.height + 5, z = WorldProfile.LANE_Z}
end

function WorldProfile.signature(seed: number): string
    assert(WorldProfile.validSeed(seed), "invalid world seed")
    return tostring(WorldProfile.GENERATOR_VERSION) .. ":" .. tostring(seed)
end

return WorldProfile
