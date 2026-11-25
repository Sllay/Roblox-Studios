--!strict
-- Costs are donated from the NPC backpack only; never mint resources on placement.
local Structures = {}
Structures.DEPTH_Z = -10
Structures.PLACEMENT_RANGE = 36
Structures.all = {
    bridge_light = {label="Ponte provisória", footprint=8, maxSlope=4, cost={wood=12},
        buildSeconds=26, health=95, storageMass=0, kind="crossing", tier="light", height=4},
    bridge_reinforced = {label="Ponte reforçada", footprint=8, maxSlope=4, cost={wood=20,stone=12},
        buildSeconds=48, health=260, storageMass=0, kind="crossing", tier="reinforced", height=5},
    castle = {label="Castelo", footprint=17, maxSlope=4, cost={wood=20,stone=36},
        buildSeconds=80, health=840, storageMass=0, kind="treasury", height=22, buildable=false},
    shelter = {label="Abrigo", footprint=10, maxSlope=5, cost={wood=8,stone=3},
        buildSeconds=20, health=120, storageMass=0, kind="habitation", height=11},
    house = {label="Casa", footprint=14, maxSlope=5, cost={wood=16,stone=8},
        buildSeconds=36, health=200, storageMass=0, kind="habitation", height=14},
    stockpile = {label="Galpão", footprint=12, maxSlope=5, cost={wood=10,stone=6},
        buildSeconds=30, health=150, storageMass=250, kind="storage", height=10},
    fence = {label="Cerca", footprint=7, maxSlope=6, cost={wood=5},
        buildSeconds=12, health=60, storageMass=0, kind="defense", height=6},
    wall = {label="Muralha", footprint=9, maxSlope=4, cost={wood=10,stone=12},
        buildSeconds=50, health=360, storageMass=0, kind="defense", height=12},
}
function Structures.get(id: any): any
    if type(id) ~= "string" then return nil end
    return Structures.all[id]
end
function Structures.register(id: string, def: any): boolean
    if Structures.get(id) or type(def) ~= "table"
        or type(def.cost) ~= "table" or type(def.footprint) ~= "number"
        or def.footprint <= 0 or type(def.maxSlope) ~= "number"
        or type(def.buildSeconds) ~= "number" or def.buildSeconds <= 0
        or type(def.health) ~= "number" or def.health <= 0 then return false end
    Structures.all[id] = table.clone(def)
    return true
end
return Structures
