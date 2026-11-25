--!strict
-- T1-R1: pure persisted record contract. Every world is a separate DataStore key.
local Living = require("./Living/LivingModel")
local World=require("./WorldProfile")
local Regions=require("./RegionalWorld")
local Slots = {}
Slots.COUNT = 6
Slots.SCHEMA_VERSION = 1
-- These are data contracts, not Roblox Place revisions.
-- Cosmetic/gameplay changes keep these versions untouched.
Slots.SAVE_FORMAT_VERSION = 1
Slots.RULESET_VERSION = 4
Slots.LEGACY_RULESET_VERSION = 3
Slots.MIN_RULESET_VERSION = 1

function Slots.compatibility(data: any): (boolean, string)
    if type(data)~="table" or data.deleted==true then
        return false,"missing_save"
    end
    local format=if data.saveFormatVersion==nil then 1 else data.saveFormatVersion
    local rules=if data.rulesetVersion==nil then 1 else data.rulesetVersion
    if type(format)~="number" or format%1~=0 or
        type(rules)~="number" or rules%1~=0 then
        return false,"invalid_save_version"
    end
    if format>Slots.SAVE_FORMAT_VERSION or rules>Slots.RULESET_VERSION then
        return false,"newer_save_protected"
    end
    if format<1 or rules<Slots.MIN_RULESET_VERSION then
        return false,"migration_required"
    end
    if format<Slots.SAVE_FORMAT_VERSION then return false,"migration_required" end
    if rules<Slots.RULESET_VERSION then return true,"legacy_compatible" end
    if rules~=Slots.RULESET_VERSION then return false,"migration_required" end
    return true,if data.saveFormatVersion==nil then "legacy_compatible" else "compatible"
end

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

function Slots.legacyBackupKey(data: any): string
    return tostring(data.createdAt)..":"..tostring(data.seed)..":"..tostring(data.revision)
end

function Slots.newWorld(seed: number, now: number, spawn: {x: number, y: number, z: number})
    assert(type(seed) == "number" and seed % 1 == 0 and seed >= 1 and seed <= 2147483646, "invalid seed")
    assert(finite(now) and now >= 0, "invalid timestamp")
    assert(finite(spawn.x) and finite(spawn.y) and finite(spawn.z), "invalid spawn")
    return {
        schemaVersion = Slots.SCHEMA_VERSION,
        generatorVersion = 1,
        saveFormatVersion = Slots.SAVE_FORMAT_VERSION,
        rulesetVersion = Slots.LEGACY_RULESET_VERSION,
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

function Slots.validPosition(x: any, y: any, z: any): boolean
    -- v15 could write positions up to ±121 at the world boundary.
    return finite(x) and finite(y) and z == 0
        and math.abs(x) <= 121 and y >= -24 and y <= 76
end

function Slots.validTravel(x: any,y: any,z: any): boolean
    return finite(x) and finite(y) and z==0
        and math.abs(x)<=World.PLAY_EDGE and y>=-24 and y<=76
end

function Slots.spawnPosition(data: any): any
    if data.living and data.living.r3 and data.living.r3.awaitingRecovery then
        return World.spawn(data.seed)
    end
    if data.regionWorld and Regions.validPosition(data.regionWorld.position) then return data.regionWorld.position end
    local p=data.frontierPosition
    if type(p)=="table" and p.revision==data.revision and Slots.validTravel(p.x,p.y,p.z) then
        return p
    end
    return data.position
end

function Slots.validWorld(data: any): boolean
    if type(data) ~= "table" then
        return false
    end
    if data.schemaVersion ~= Slots.SCHEMA_VERSION or data.generatorVersion ~= 1 then
        return false
    end
    local compatible=Slots.compatibility(data)
    if not compatible then return false end
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
    if type(p) ~= "table" or not Slots.validPosition(p.x, p.y, p.z) then
        return false
    end
    local extended=data.frontierPosition
    if extended~=nil and (type(extended)~="table" or not finite(extended.revision)
        or extended.revision<0 or extended.revision%1~=0
        or not Slots.validTravel(extended.x,extended.y,extended.z)) then return false end
    if type(data.regions) ~= "table" or type(data.storyFlags) ~= "table" then
        return false
    end
    -- Schema 1 worlds from T1-R1 do not have living; they remain readable.
    -- Population itself has its own migratable schema and must never silently
    -- be discarded when a newer/unknown population record is encountered.
    if data.living ~= nil and (not Living.valid(data.living) or data.living.seed ~= data.seed) then
        return false
    end
    if data.rulesetVersion==Slots.RULESET_VERSION then
        if not Regions.valid(data.regionWorld,data.seed,data.living) then return false end
    elseif data.regionWorld~=nil then
        return false
    end
    return true
end

function Slots.summary(data: any, index: number)
    if data == nil or (type(data) == "table" and data.deleted == true) then
        return {index = index, exists = false}
    end
    if type(data) ~= "table" then
        return {index = index, exists = true, corrupt = true}
    end
    local compatible,reason=Slots.compatibility(data)
    if not compatible then
        return {index=index,exists=true,incompatible=true,compatibility=reason,
            saveFormatVersion=data.saveFormatVersion or 1,
            rulesetVersion=data.rulesetVersion or 1}
    end
    if not Slots.validWorld(data) then
        return {index = index, exists = true, corrupt = true}
    end
    return {
        index = index, exists = true,
        seed = data.seed, updatedAt = data.updatedAt,
        revision = data.revision, worldDay = math.floor(data.clockSeconds / 240) + 1,
        saveFormatVersion=data.saveFormatVersion or 1,
        rulesetVersion=data.rulesetVersion or 1,
        compatibility=reason,
    }
end

return Slots
