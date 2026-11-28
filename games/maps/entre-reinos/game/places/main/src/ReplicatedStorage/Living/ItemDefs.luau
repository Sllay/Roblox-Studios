--!strict
-- T1-R2. Mass units and stack sizes are authoritative, extensible item data.
local Items = {}
Items.VERSION = 1
Items.all = {
    plank = {mass = 1, stack = 24, kind = "resource", label = "Tábua"},
    metal = {mass = 3, stack = 12, kind = "resource", label = "Metal"},
    grain = {mass = 1, stack = 24, kind = "resource", label = "Grão"},
    meat = {mass = 2, stack = 16, kind = "resource", label = "Carne"},
    leather = {mass = 1, stack = 12, kind = "resource", label = "Couro"},
    axe = {mass = 3, stack = 4, kind = "tool", label = "Machado", durability = 18},
    pick = {mass = 4, stack = 4, kind = "tool", label = "Picareta", durability = 18},
    hammer = {mass = 2, stack = 4, kind = "tool", label = "Martelo", durability = 16},
    hoe = {mass = 2, stack = 4, kind = "tool", label = "Enxada", durability = 16},
    bow = {mass = 2, stack = 4, kind = "weapon", label = "Arco"},
    spear = {mass = 3, stack = 4, kind = "weapon", label = "Lança"},
    wood = {mass = 2, stack = 20, kind = "resource", label = "Madeira"},
    stone = {mass = 3, stack = 15, kind = "resource", label = "Pedra"},
    food = {mass = 1, stack = 24, kind = "resource", label = "Alimento"},
    iron = {mass = 4, stack = 12, kind = "resource", label = "Ferro"},
}
function Items.get(id: any): any
    if type(id) ~= "string" then return nil end
    return Items.all[id]
end
function Items.register(id: string, item: any): boolean
    if Items.get(id) or not string.match(id,"^[a-z][a-z0-9_]+$")
        or type(item) ~= "table" then return false end
    if type(item.mass) ~= "number" or item.mass <= 0
        or type(item.stack) ~= "number" or item.stack < 1
        or item.stack % 1 ~= 0 or type(item.label) ~= "string" then return false end
    Items.all[id] = table.clone(item)
    return true
end
return Items
