--!strict
local Professions = {}
Professions.order=table.freeze({"lumberjack","carpenter","miner","smith","artisan","farmer","hunter",
    "builder","carrier","merchant","guard","archer","spearman","common"})
Professions.all = {
    lumberjack = {gather = {wood = 3}, build = 1, carryCapacity = 30, moveSpeed = 6, label = "Lenhador", tool = "axe"},
    smith = {gather = {}, build = 1, carryCapacity = 28, moveSpeed = 6, label = "Ferreiro", craft = "forge", tool = "hammer"},
    artisan = {gather = {}, build = 1, carryCapacity = 26, moveSpeed = 6, label = "Artesão", craft = "workshop", tool = "hammer"},
    farmer = {gather = {food = 2}, build = 1, carryCapacity = 28, moveSpeed = 6, label = "Fazendeiro", tool = "hoe"},
    hunter = {gather = {}, build = 1, carryCapacity = 28, moveSpeed = 6.3, label = "Caçador"},
    carrier = {gather = {}, build = 1, carryCapacity = 44, moveSpeed = 6.4, label = "Transportador"},
    merchant = {gather = {}, build = 1, carryCapacity = 30, moveSpeed = 6, label = "Comerciante"},
    guard = {gather = {}, build = 1, carryCapacity = 28, moveSpeed = 6, label = "Guarda"},
    archer = {gather = {}, build = 1, carryCapacity = 28, moveSpeed = 6, label = "Arqueiro"},
    spearman = {gather = {}, build = 1, carryCapacity = 28, moveSpeed = 6, label = "Lanceiro"},
    common = {gather = {}, build = 1, carryCapacity = 22, moveSpeed = 6, label = "Habitante"},
    carpenter = {gather = {wood = 3}, build = 1, carryCapacity = 30, moveSpeed = 6, label = "Carpinteiro", craft = "workshop", tool = "axe"},
    miner = {gather = {stone = 3, iron = 3}, build = 1, carryCapacity = 36, moveSpeed = 5.5, label = "Minerador", tool = "pick"},
    builder = {gather = {}, build = 2, carryCapacity = 30, moveSpeed = 6, label = "Construtor", tool = "hammer"},
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
