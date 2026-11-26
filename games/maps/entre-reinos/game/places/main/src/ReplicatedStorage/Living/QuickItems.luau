--!strict
-- Issued weapons are campaign equipment. Everything else comes from the
-- authoritative personal inventory and is checked again on every use.
local Quick={}
Quick.order=table.freeze({"sword","bow","spear","axe","food"})
Quick.items=table.freeze({
    sword={label="Espada",issued=true,action="attack"},
    bow={label="Arco",issued=true,action="bow",ammo="arrows"},
    spear={label="Lança",issued=false,action="attack"},
    axe={label="Machado",issued=false,action="tool_use"},
    food={label="Alimento",issued=false,action="tool_use"},
} :: {[string]: any})

function Quick.owned(key: any,bag: any): boolean
    if type(key)~="string" then return false end
    local item=Quick.items[key]
    if not item then return false end
    return item.issued or (bag~=nil and (bag.items[key] or 0)>0)
end

return Quick
