--!strict
-- Spatial rules for the T2-R1 development branch. The v18 field owns its
-- original half-open interval and is sampled unchanged on every old voxel.
local Legacy = require("./WorldProfile")

local Profile = {}
Profile.GENERATOR_VERSION = 2
Profile.CELL = Legacy.CELL
Profile.CHUNK_STUDS = Legacy.CHUNK_STUDS
Profile.INITIAL_CHUNKS = Legacy.INITIAL_CHUNKS
Profile.LANE_Z = Legacy.LANE_Z
Profile.REGION_CHUNKS = 8
Profile.REGIONS_PER_SIDE = 2
Profile.CHUNK_RADIUS = Legacy.CHUNK_RADIUS + Profile.REGION_CHUNKS * Profile.REGIONS_PER_SIDE
Profile.CHUNK_COUNT = Profile.CHUNK_RADIUS * 2 + 1
local edge = (Profile.CHUNK_RADIUS + 0.5) * Profile.CHUNK_STUDS
local regionWidth = Profile.REGION_CHUNKS * Profile.CHUNK_STUDS
Profile.PLAY_EDGE = edge - 4
Profile.BOUNDS = {
    xMin = -edge, xMax = edge,
    yMin = Legacy.BOUNDS.yMin, yMax = Legacy.BOUNDS.yMax,
    zMin = Legacy.BOUNDS.zMin, zMax = Legacy.BOUNDS.zMax,
}
Profile.validSeed = Legacy.validSeed
Profile.spawn = Legacy.spawn

type Biome = {
    id: string, ground: number, height: number, detail: number, ridge: number,
    material: string, cover: number, resource: string, stock: number, settlement: boolean,
}

local function biome(
    id: string, ground: number, height: number, detail: number, ridge: number,
    material: string, cover: number, resource: string, stock: number, settlement: boolean
): Biome
    return table.freeze({
        id = id, ground = ground, height = height, detail = detail, ridge = ridge,
        material = material, cover = cover, resource = resource, stock = stock,
        settlement = settlement,
    })
end

local meadow = biome("meadow", 16, 4, 2, 9, "Grass", 3, "wood", 8, true)
local forest = biome("forest", 19, 8, 4, 20, "Grass", 8, "wood", 16, false)
local hills = biome("hills", 22, 15, 4, 20, "Ground", 4, "stone", 10, false)
local rockland = biome("rockland", 19, 10, 5, 23, "Rock", 1, "stone", 18, false)
local mountains = biome("mountains", 24, 16, 5, 41, "Slate", 2, "iron", 13, false)

-- A region's point on the route can have flanking biomes. Neighboring
-- regions use the same absolute-space controls, including across their seam.
local biomeSize = 128
local sequence = {meadow, forest, hills, rockland, mountains}

local function smooth(t: number): number
    local u = math.clamp(t, 0, 1)
    return u * u * (3 - 2 * u)
end

local function mix(from: number, to: number, weight: number): number
    return from + (to - from) * weight
end

local function outsideBiome(seed: number, node: number, side: number): Biome
    -- One buildable clearing on each far flank. It belongs to a field
    -- spanning the nearby region; no later flattening around buildings.
    if node == 6 then return meadow end
    return sequence[(node + seed % #sequence + (if side < 0 then 2 else 0)) % #sequence + 1]
end

function Profile.chunkAt(x: number): number
    return math.clamp(math.floor((x + 32) / Profile.CHUNK_STUDS), -Profile.CHUNK_RADIUS, Profile.CHUNK_RADIUS)
end

function Profile.chunkBounds(index: number): (number, number)
    assert(index % 1 == 0 and math.abs(index) <= Profile.CHUNK_RADIUS, "invalid chunk index")
    local left = index * Profile.CHUNK_STUDS - 32
    return left, left + Profile.CHUNK_STUDS
end

function Profile.regionOfChunk(chunk: number): number
    assert(chunk % 1 == 0 and math.abs(chunk) <= Profile.CHUNK_RADIUS, "invalid chunk index")
    if math.abs(chunk) <= Legacy.CHUNK_RADIUS then return 0 end
    return math.sign(chunk) * math.ceil((math.abs(chunk) - Legacy.CHUNK_RADIUS) / Profile.REGION_CHUNKS)
end

function Profile.region(index: number)
    assert(index % 1 == 0 and math.abs(index) <= Profile.REGIONS_PER_SIDE, "invalid region index")
    local first, last = -Legacy.CHUNK_RADIUS, Legacy.CHUNK_RADIUS
    if index ~= 0 then
        local start = Legacy.CHUNK_RADIUS + (math.abs(index) - 1) * Profile.REGION_CHUNKS + 1
        local finish = start + Profile.REGION_CHUNKS - 1
        first, last = if index > 0 then start else -finish, if index > 0 then finish else -start
    end
    local xMin = Profile.chunkBounds(first)
    local _, xMax = Profile.chunkBounds(last)
    return {
        id = "region:" .. tostring(index), index = index, firstChunk = first, lastChunk = last,
        xMin = xMin, xMax = xMax,
        west = if index > -Profile.REGIONS_PER_SIDE then index - 1 else nil,
        east = if index < Profile.REGIONS_PER_SIDE then index + 1 else nil,
    }
end

function Profile.regionAt(x: number): number?
    if not (x >= Profile.BOUNDS.xMin and x < Profile.BOUNDS.xMax) then return nil end
    return Profile.regionOfChunk(Profile.chunkAt(x))
end

function Profile.signature(seed: number): string
    assert(Profile.validSeed(seed), "invalid world seed")
    return tostring(Profile.GENERATOR_VERSION) .. ":" .. tostring(seed)
end

local function channelAt(seed: number, side: number, outward: number, z: number): (number, number, boolean)
    -- Each region gets a connected course from the background to the
    -- foreground. The first is a ford, the second a navigable deep river.
    local band = math.clamp(math.floor(outward / regionWidth), 0, Profile.REGIONS_PER_SIDE - 1)
    local phase = (seed % 8191) / 113 + side * 7 + band * 11
    local center = band * regionWidth + (if band == 0 then 228 else 320) + phase % 64
        + math.noise(z / 47, phase, 8.4) * 13
    local bedDistance = math.abs(outward - center)
    local water = 12 + 9 * smooth((-z - 21) / 16)
    return bedDistance, water, band == 0
end

function Profile.sample(seed: number, x: number, z: number)
    if x >= Legacy.BOUNDS.xMin and x < Legacy.BOUNDS.xMax then
        local legacy = Legacy.sample(seed, x, z)
        return {
            height = legacy.height, wet = legacy.wet, shore = legacy.shore, riverDist = legacy.riverDist,
            material = legacy.material, waterSurface = legacy.waterSurface, biome = "heartland",
            landHeight = legacy.landHeight, channelBed = legacy.channelBed, channelSurface = legacy.channelSurface,
            channelWidth = legacy.channelWidth, channelBankWidth = legacy.channelBankWidth,
            traversal = if legacy.wet then "deep_water" else "dry",
        }
    end
    local side = math.sign(x)
    local outward = math.abs(x) - Legacy.BOUNDS.xMax
    local node = math.floor(outward / biomeSize)
    local weight = smooth(outward / biomeSize - node)
    local here = outsideBiome(seed, node, side)
    local nextBiome = outsideBiome(seed, node + 1, side)
    local dominant = if weight < 0.5 then here else nextBiome

    local phase = (seed % 32749) / 31
    local coarse = math.noise(x / 105, z / 80, phase)
    local fine = math.noise(x / 33, z / 39 + phase, 3.7)
    local background = smooth((-z - 11) / 35)
    local surface = mix(here.ground, nextBiome.ground, weight)
        + coarse * mix(here.height, nextBiome.height, weight)
        + fine * mix(here.detail, nextBiome.detail, weight)
        + background * mix(here.ridge, nextBiome.ridge, weight)

    local clearing = 1 - smooth(math.abs(outward - 6 * biomeSize) / 55)
    surface = mix(surface, 18 + fine, clearing * (1 - background))
    local border = Legacy.sample(seed, side * Legacy.BOUNDS.xMax, z)
    surface = mix(border.height, math.min(surface, 60), smooth(outward / 146))

    local distance, water, ford = channelAt(seed, side, outward, z)
    local halfBed = if ford then 10 else 15
    local bank = if ford then 12 else 25
    -- Keep opposing bridge approaches viable despite different biomes.
    -- The low shoulder tapers out toward the hills and along Z so the
    -- background channel still follows the rising surrounding terrain.
    local shoulder = (1 - smooth((distance - halfBed - bank) / 24))
        * (1 - smooth((math.abs(z) - 6) / 20))
    surface = mix(surface, water + 6, shoulder)
    local bankBlend = smooth((distance - halfBed) / bank)
    local crossing = if ford then 1 - smooth((math.abs(z) - 4) / 15) else 0
    local depth = mix(if ford then 6 else 13, 1.4, crossing)
    local height = mix(water - depth, surface, bankBlend)
    local wet = bankBlend < 1 and height < water
    local shore = distance < halfBed + bank
    local material = if wet then "Mud" elseif shore then "Sand" else dominant.material
    if outward < 16 then material = border.material end
    return {
        height = height, wet = wet, shore = shore, riverDist = distance,
        landHeight = surface, channelBed = water - depth, channelSurface = water,
        channelWidth = halfBed, channelBankWidth = bank,
        material = material, waterSurface = if wet then water else nil,
        biome = if shore then (if ford then "stream" else "riverbank") else dominant.id,
        traversal = if wet then (if water - height <= 2 then "ford" else "deep_water") else "dry",
    }
end

function Profile.settlement(seed: number, regionIndex: number): {id: string, x: number, y: number, z: number}?
    assert(Profile.validSeed(seed), "invalid world seed")
    local region = Profile.region(regionIndex)
    if math.abs(regionIndex) ~= Profile.REGIONS_PER_SIDE then return nil end
    local x = math.sign(regionIndex) * (Legacy.BOUNDS.xMax + 6 * biomeSize)
    local anchor = Profile.sample(seed, x, -10)
    if not meadow.settlement or anchor.wet then return nil end
    return {id = region.id .. ":town", x = x, y = anchor.height, z = -10}
end

export type NaturalSite = {id: string, x: number, y: number, z: number, item: string, initialAmount: number}
function Profile.naturalSites(seed: number, chunk: number): {NaturalSite}
    local regionIndex = Profile.regionOfChunk(chunk)
    if regionIndex == 0 then return {} end -- v18 stock remains in LivingModel
    local left = Profile.chunkBounds(chunk)
    local xMid = left + 32
    local node = (math.abs(xMid) - Legacy.BOUNDS.xMax) / biomeSize
    local def = outsideBiome(seed, math.floor(node + 0.5), math.sign(chunk))
    local town = Profile.settlement(seed, regionIndex)
    local regionId = Profile.region(regionIndex).id
    local sites: {NaturalSite} = {}
    for i = 1, def.cover do
        local jitter = (seed % 241 + i * 59 + chunk * 131) % 5 - 2
        local x = left + i * 7 + jitter
        local z = -19 - i % 4 * 5
        local sample = Profile.sample(seed, x, z)
        local walk = Profile.sample(seed, x, 0)
        if not sample.shore and walk.traversal == "dry"
            and (not town or math.abs(x - town.x) > 47) then
            table.insert(sites, {
                id = regionId .. ":site:" .. tostring(chunk) .. ":" .. tostring(i),
                x = x, y = sample.height, z = z, item = def.resource, initialAmount = def.stock,
            })
        end
    end
    return sites
end

return Profile
