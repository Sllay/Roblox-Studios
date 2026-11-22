--!strict
local Professions = {}
Professions.all = {
    common = {gather = {}, build = 1, carryCapacity = 22, moveSpeed = 6, label = "Habitante"},
    carpenter = {gather = {wood = 3}, build = 1, carryCapacity = 30, moveSpeed = 6, label = "Carpinteiro"},
    miner = {gather = {stone = 3, iron = 3}, build = 1, carryCapacity = 36, moveSpeed = 5.5, label = "Minerador"},
    builder = {gather = {}, build = 2, carryCapacity = 30, moveSpeed = 6, label = "Construtor"},
}
function Professions.get(id: any): any
    if type(id) ~= "string" then return nil end
    return Professions.all[id]
end
function Professions.gatherYield(id: string, item: string): number
    local p = Professions.get(id)
    return if p then (p.gather[item] or 1) else 1
end
function Professions.buildRate(id: string): number
    local p = Professions.get(id)
    return if p then p.build else 1
end
function Professions.register(id: string, def: any): boolean
    if Professions.get(id) or type(def) ~= "table" or type(def.gather) ~= "table"
        or type(def.build) ~= "number" or def.build <= 0
        or type(def.carryCapacity) ~= "number" or def.carryCapacity < 1
        or type(def.moveSpeed) ~= "number" or def.moveSpeed <= 0 then return false end
    Professions.all[id] = table.clone(def)
    return true
end
return Professions
