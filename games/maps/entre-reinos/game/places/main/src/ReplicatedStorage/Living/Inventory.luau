--!strict
-- Pure transactional inventory; all mutations are server-side and mass bounded.
local Items = require("./ItemDefs")
local Inv = {}
local function quantity(q: any): boolean
    return type(q)=="number" and q==q and q%1==0 and q>0 and q<=100000
end
function Inv.new(maxMass: number)
    assert(type(maxMass)=="number" and maxMass>0 and maxMass<=100000,"bad_mass")
    return {maxMass=maxMass, items={}}
end
function Inv.weight(bag: any): number
    local total=0
    for id,amount in pairs(bag.items) do
        local item=Items.get(id)
        if item and type(amount)=="number" then total+=amount*item.mass end
    end
    return total
end
function Inv.count(bag: any, id: string): number
    return if type(bag.items[id])=="number" then bag.items[id] else 0
end
function Inv.canAdd(bag: any, id: string, amount: number): boolean
    local item=Items.get(id)
    return item~=nil and quantity(amount) and Inv.weight(bag)+amount*item.mass<=bag.maxMass+0.000001
end
function Inv.add(bag: any, id: string, amount: number): boolean
    if not Inv.canAdd(bag,id,amount) then return false end
    bag.items[id]=Inv.count(bag,id)+amount
    return true
end
function Inv.take(bag: any, id: string, amount: number): boolean
    if not Items.get(id) or not quantity(amount)
        or Inv.count(bag,id)<amount then return false end
    local left=Inv.count(bag,id)-amount
    if left==0 then bag.items[id]=nil else bag.items[id]=left end
    return true
end
function Inv.transfer(source: any, dest: any, id: string, amount: number): boolean
    if not quantity(amount) or Inv.count(source,id)<amount
        or not Inv.canAdd(dest,id,amount) then return false end
    if not Inv.take(source,id,amount) then return false end
    if not Inv.add(dest,id,amount) then
        assert(Inv.add(source,id,amount),"inventory rollback failed")
        return false
    end
    return true
end
function Inv.valid(bag: any): boolean
    if type(bag)~="table" or type(bag.items)~="table"
        or type(bag.maxMass)~="number" or bag.maxMass<1 then return false end
    local mass=0
    for id,amount in pairs(bag.items) do
        local def=Items.get(id)
        if not def or not quantity(amount) then return false end
        mass+=amount*def.mass
    end
    return mass<=bag.maxMass+0.000001
end
return Inv
