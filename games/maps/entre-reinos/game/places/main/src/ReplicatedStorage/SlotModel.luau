--!strict
-- T1-R1: pure persisted record contract. Every world is a separate DataStore key.
local Slots = {}
Slots.COUNT = 6
Slots.SCHEMA_VERSION = 1

local function finite(value: any): boolean
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Slots.validIndex(index: any): boolean
    return type(index) == "number" and finite(index) and index % 1 == 0 and index >= 1 and index <= Slots.COUNT
end

function Slots.key(userId: number, index: number): string
    assert(userId > 0 and userId % 1 == 0 and Slots.validIndex(index), "invalid world key")
    return "u:" .. tostring(userId) .. ":s:" .. tostring(index)
end

function Slots.newWorld(seed: number, now: number, spawn: {x: number, y: number, z: number})
    assert(type(seed) == "number" and seed % 1 == 0 and seed >= 1 and seed <= 2147483646, "invalid seed")
    assert(finite(now) and now >= 0, "invalid timestamp")
    assert(finite(spawn.x) and finite(spawn.y) and finite(spawn.z), "invalid spawn")
    return {
        schemaVersion = Slots.SCHEMA_VERSION,
        generatorVersion = 1,
        seed = seed,
        createdAt = now,
        updatedAt = now,
        revision = 0,
        clockSeconds = 0,
        position = {x = spawn.x, y = spawn.y, z = 0},
        regions = {},
        storyFlags = {},
    }
end

function Slots.validWorld(data: any): boolean
    if type(data) ~= "table" then
        return false
    end
    if data.schemaVersion ~= Slots.SCHEMA_VERSION or data.generatorVersion ~= 1 then
        return false
    end
    if not finite(data.seed) or data.seed % 1 ~= 0 or data.seed < 1 or data.seed > 2147483646 then
        return false
    end
    if not finite(data.revision) or data.revision % 1 ~= 0 or data.revision < 0 then
        return false
    end
    if not finite(data.createdAt) or not finite(data.updatedAt) or not finite(data.clockSeconds) then
        return false
    end
    if data.clockSeconds < 0 or data.createdAt < 0 or data.updatedAt < data.createdAt then
        return false
    end
    local p = data.position
    if type(p) ~= "table" or not finite(p.x) or not finite(p.y) or p.z ~= 0 then
        return false
    end
    if math.abs(p.x) > 120 or p.y < -24 or p.y > 76 then
        return false
    end
    if type(data.regions) ~= "table" or type(data.storyFlags) ~= "table" then
        return false
    end
    return true
end

function Slots.summary(data: any, index: number)
    if type(data) ~= "table" or data.deleted == true then
        return {index = index, exists = false}
    end
    if not Slots.validWorld(data) then
        return {index = index, exists = false, corrupt = true}
    end
    return {
        index = index, exists = true,
        seed = data.seed, updatedAt = data.updatedAt,
        revision = data.revision, worldDay = math.floor(data.clockSeconds / 240) + 1,
    }
end

return Slots
