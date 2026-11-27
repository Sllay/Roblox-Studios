--!strict
local Legacy = require("../places/main/src/ReplicatedStorage/WorldProfile")
local Regions = require("../places/main/src/ReplicatedStorage/RegionalProfile")

local function checkRegions()
    local count = 0
    for index = -Regions.REGIONS_PER_SIDE, Regions.REGIONS_PER_SIDE do
        local region = Regions.region(index)
        assert(Regions.regionAt(region.xMin) == index)
        assert(Regions.regionAt(region.xMax - 0.001) == index)
        assert(Regions.regionAt((region.xMin + region.xMax) / 2) == index)
        if region.east then
            local neighbor = Regions.region(region.east)
            assert(neighbor.west == index and neighbor.xMin == region.xMax)
        end
        for chunk = region.firstChunk, region.lastChunk do
            assert(Regions.regionOfChunk(chunk) == index)
            count += 1
        end
    end
    assert(count == Regions.CHUNK_COUNT and count == 49)
    assert(Regions.regionAt(Regions.BOUNDS.xMax) == nil)
    assert(Regions.regionAt(Regions.BOUNDS.xMin - 1) == nil)
end

local function checkWater(seed: number, regionIndex: number, kind: string)
    local region = Regions.region(regionIndex)
    local lastLeft: number? = nil
    local lastRight: number? = nil
    for z = Regions.BOUNDS.zMin + 2, Regions.BOUNDS.zMax - 2, Regions.CELL do
        local first: number? = nil
        local last: number? = nil
        local foundCrossing = false
        for x = region.xMin + 2, region.xMax - 2, Regions.CELL do
            local sample = Regions.sample(seed, x, z)
            if sample.wet then
                assert(sample.waterSurface and sample.waterSurface > sample.height)
                assert(first == nil or (last and x - last == Regions.CELL), "disconnected water row")
                first = first or x
                last = x
                if sample.traversal == kind then foundCrossing = true end
            else
                assert(sample.waterSurface == nil)
            end
        end
        assert(first and last, "channel ended within the terrain")
        if lastLeft and lastRight then
            assert(first <= lastRight and last >= lastLeft, "adjacent water rows disconnected")
        end
        if math.abs(z) <= 4 then assert(foundCrossing, "missing intended path water class") end
        lastLeft, lastRight = first, last
    end
end

local function checkSeed(seed: number)
    local biomes: {[string]: boolean} = {}
    for x = Legacy.BOUNDS.xMin + 2, Legacy.BOUNDS.xMax - 2, Regions.CELL do
        for z = Regions.BOUNDS.zMin + 2, Regions.BOUNDS.zMax - 2, Regions.CELL do
            local old, new = Legacy.sample(seed, x, z), Regions.sample(seed, x, z)
            assert(old.height == new.height and old.material == new.material and old.wet == new.wet)
            local originalWater = if old.riverDist < 23 then 10 else nil
            assert(new.waterSurface == originalWater)
        end
    end
    local lastByLayer: {[number]: number} = {}
    for x = Regions.BOUNDS.xMin + 2, Regions.BOUNDS.xMax - 2, Regions.CELL do
        for _, z in ipairs({-46, -26, 2, 22, 46}) do
            local sample = Regions.sample(seed, x, z)
            local same = Regions.sample(seed, x, z)
            assert(sample.height == same.height and sample.material == same.material and sample.biome == same.biome)
            assert(sample.height > Regions.BOUNDS.yMin and sample.height < Regions.BOUNDS.yMax)
            biomes[sample.biome] = true
            local last = lastByLayer[z]
            local midpoint = math.abs(x - 2)
            local limit = if midpoint == Legacy.BOUNDS.xMax then 7 else 4
            if (midpoint == Legacy.BOUNDS.xMax or midpoint == Regions.region(1).xMax) and last then
                assert(math.abs(sample.height - last) < limit,
                    string.format("regional seam seed=%d x=%d z=%d step=%.3f", seed, x, z, sample.height - last))
                local left = Regions.sample(seed, x - 2 - 0.001, z)
                local right = Regions.sample(seed, x - 2 + 0.001, z)
                assert(math.abs(left.height - right.height) < 0.01)
                assert(left.waterSurface == right.waterSurface)
            end
            lastByLayer[z] = sample.height
        end
    end
    for _, id in ipairs({"heartland", "meadow", "forest", "hills", "rockland", "mountains", "stream", "riverbank"}) do
        assert(biomes[id], id)
    end
    for _, index in ipairs({-2, -1, 1, 2}) do
        checkWater(seed, index, if math.abs(index) == 1 then "ford" else "deep_water")
    end
    local sites: {[string]: boolean} = {}
    for chunk = -Regions.CHUNK_RADIUS, Regions.CHUNK_RADIUS do
        local first, second = Regions.naturalSites(seed, chunk), Regions.naturalSites(seed, chunk)
        assert(#first == #second)
        for i, site in ipairs(first) do
            assert(not sites[site.id] and site.initialAmount > 0)
            assert(site.id == second[i].id and site.x == second[i].x and site.y == second[i].y)
            assert(Regions.chunkAt(site.x) == chunk and Regions.sample(seed, site.x, site.z).traversal == "dry")
            sites[site.id] = true
        end
    end
    for _, index in ipairs({-2, 2}) do
        local town = assert(Regions.settlement(seed, index))
        assert(Regions.regionAt(town.x) == index and town.y == Regions.sample(seed, town.x, town.z).height)
        for x = town.x - 20, town.x + 20, 4 do
            local ground = Regions.sample(seed, x, town.z)
            assert(ground.traversal == "dry" and math.abs(ground.height - town.y) < 3)
        end
    end
end

checkRegions()
for _, seed in ipairs({1, 42, 1009, 870001, 123456789, 516639272, 2147483646}) do checkSeed(seed) end
print("ENTRE_REINOS_T2_R1_PROFILE: five regions, 49 chunks and seven seeds passed")

local Scenery=require("../places/main/src/ReplicatedStorage/SceneryProfile")
local scenicSeeds={516639272,17071985,382775}
for _,worldSeed in ipairs(scenicSeeds) do
    local left,right=Scenery.coverage(0,24,0)
    local rearLeft,rearRight=Scenery.coverage(0,24,-3)
    assert(right>=-left and rearLeft<left and rearRight>right)
    for x=-1500,1500,12 do
        for _,z in ipairs({-46,-2,46}) do
            local legacy=Regions.sample(worldSeed,x,z)
            local current=Scenery.sample(worldSeed,x,z)
            assert(current.height==legacy.height and current.material==legacy.material and current.waterSurface==legacy.waterSurface)
        end
        assert(Scenery.sample(worldSeed,x,92).wet)
    end
    for _,side in ipairs({-1,1}) do
        local id=side*(Regions.CHUNK_RADIUS+2)
        assert(Scenery.bounds(id,-3).zMin==-240 and Scenery.bounds(id,1).zMax==112)
        assert(math.abs(Scenery.bounds(id,0).xMin)>Regions.PLAY_EDGE or math.abs(Scenery.bounds(id,0).xMax)>Regions.PLAY_EDGE)
    end
    for row=-3,-1 do
        local a,b=Scenery.vegetation(worldSeed,4,row),Scenery.vegetation(worldSeed,4,row)
        assert(#a==#b and #a<=13)
        for i,tree in ipairs(a) do
            assert(tree.x==b[i].x and tree.y==b[i].y and tree.z==b[i].z)
            assert(not Scenery.sample(worldSeed,tree.x,tree.z).wet)
        end
    end
    local deep=Scenery.sample(worldSeed,0,-232)
    assert(deep.height>Scenery.sample(worldSeed,0,-48).height+20)
end
print("ENTRE_REINOS_V20_SCENERY: unchanged playable samples, exterior terrain and wet frontage in three seeds")

local DRY_LIMIT=Regions.CELL
for _,seed in ipairs({516639272,42,17071985,382775}) do
    -- The earlier wet/dry switch jumped 26–48 studs over one quarter stud.
    for z=-230,-50,4 do
        local previous=Scenery.sample(seed,52,z)
        for x=52.25,104,0.25 do
            local point=Scenery.sample(seed,x,z)
            if previous.wet~=point.wet then
                assert(math.abs(point.height-previous.height)<DRY_LIMIT,"broken riverbank profile")
            end
            if point.wet then assert((point.waterSurface or -math.huge)>point.height) end
            previous=point
        end
    end
    -- The same course feeds through all rear rows into one foreground level.
    local upstream=math.huge
    for z=-236,108,4 do
        local point=Scenery.sample(seed,Legacy.RIVER_BASE_X,z)
        assert(point.waterSurface and point.height<point.waterSurface,"disconnected heartland river")
        assert(point.waterSurface<=upstream,"river climbs downstream")
        upstream=point.waterSurface
    end
    assert(upstream==6)
    -- Inspect both dimensions of the tiled raster at their shared boundaries.
    for _,edge in ipairs({-176,-112,-48,48}) do
        for x=42,108,2 do
            local a=Scenery.sample(seed,x,edge-0.001)
            local b=Scenery.sample(seed,x,edge+0.001)
            assert(math.abs(a.height-b.height)<0.04,"height jumps between Z rows")
            if a.waterSurface and b.waterSurface then
                assert(math.abs(a.waterSurface-b.waterSurface)<0.01)
            end
        end
    end
    for id=-Regions.CHUNK_RADIUS-1,Regions.CHUNK_RADIUS+2 do
        local edge=Scenery.bounds(id,1).xMin
        local a=Scenery.sample(seed,edge-0.001,92)
        local b=Scenery.sample(seed,edge+0.001,92)
        assert(a.waterSurface==6 and b.waterSurface==6 and math.abs(a.height-b.height)<0.01)
    end
end
print("ENTRE_REINOS_WATER_BRIDGE: connected watershed and continuous borders across four seeds")
