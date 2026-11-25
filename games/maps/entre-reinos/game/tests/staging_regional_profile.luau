-- Runs in the disposable Open Cloud engine session, never saving its Terrain.
local function probeRegions(world, profile, publishedLegacy, seed)
    local ok, reason = world.activate(seed, nil, profile)
    assert(ok, reason)
    local start = world.metrics()
    assert(start.chunks == 5 and start.waterCells > 0)
    assert(not world.isLoadedAt(profile.PLAY_EDGE))

    for _, side in ipairs({-1, 1}) do
        for x = 136, profile.PLAY_EDGE, 64 do
            local old = world.getChunkCount()
            local loaded, errorCode = world.ensureNear(seed, side * x)
            assert(loaded, errorCode)
            assert(world.isLoadedAt(side * x))
            assert(world.getChunkCount() - old <= 2, "generated past neighboring window")
        end
        assert(world.ensureNear(seed, side * profile.PLAY_EDGE))
    end
    local complete = world.metrics()
    assert(complete.chunks == profile.CHUNK_COUNT and complete.chunks == 49)
    assert(complete.waterCells > start.waterCells and complete.decorations > start.decorations)
    assert(not world.isLoadedAt(profile.BOUNDS.xMax))

    local terrain = workspace.Terrain
    local b = publishedLegacy.BOUNDS
    local compared = 0
    for chunk = -8, 8 do
        local xmin, xmax = publishedLegacy.chunkBounds(chunk)
        local box = Region3.new(Vector3.new(xmin, b.yMin, b.zMin), Vector3.new(xmax, b.yMax, b.zMax))
        local native = terrain:ReadVoxelChannels(box, 4, {"SolidOccupancy", "LiquidOccupancy", "SolidMaterial"})
        for ix = 1, 16 do
            local x = xmin + (ix - 0.5) * 4
            for iz = 1, 24 do
                local z = b.zMin + (iz - 0.5) * 4
                local old = publishedLegacy.sample(seed, x, z)
                for iy = 1, 24 do
                    local bottom = b.yMin + (iy - 1) * 4
                    local solid = math.clamp((old.height - bottom) / 4, 0, 1)
                    local water = if old.riverDist < 23 then
                        math.min(1 - solid, math.clamp((publishedLegacy.WATER_SURFACE - bottom) / 4, 0, 1))
                        else 0
                    assert(math.abs(native.SolidOccupancy[ix][iy][iz] - solid) <= 0.02)
                    assert(math.abs(native.LiquidOccupancy[ix][iy][iz] - water) <= 0.02)
                    if solid > 0.01 then
                        assert(native.SolidMaterial[ix][iy][iz] == Enum.Material[old.material])
                    end
                    compared += 1
                end
            end
        end
    end

    local supported = 0
    local waterColumns = 0
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Include
    rayParams.FilterDescendantsInstances = {terrain}
    rayParams.IgnoreWater = true
    for _, index in ipairs({-2, -1, 1, 2}) do
        local region = profile.region(index)
        for x = region.xMin + 2, region.xMax - 2, 8 do
            if profile.sample(seed, x, 0).waterSurface then waterColumns += 1 end
            local hit = workspace:Raycast(Vector3.new(x, 70, 0), Vector3.new(0, -100, 0), rayParams)
            assert(hit, "missing native terrain column")
            supported += 1
        end
        local settlement = profile.settlement(seed, index)
        if settlement then
            local hit = workspace:Raycast(Vector3.new(settlement.x, 70, settlement.z),
                Vector3.new(0, -100, 0), rayParams)
            assert(hit and math.abs(hit.Position.Y - settlement.y) < 3, "town candidate lacks native support")
        end
    end
    assert(waterColumns >= 12)
    return {
        start = start, complete = complete, legacyVoxels = compared, nativeSupports = supported,
        waterColumns = waterColumns, streaming = workspace.StreamingEnabled, seed = seed,
    }
end
