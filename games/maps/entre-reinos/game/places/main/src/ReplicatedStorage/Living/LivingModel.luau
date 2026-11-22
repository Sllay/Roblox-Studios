--!strict
-- State-only model, detached from engine. Existing R1 six-slot schema is retained;
-- optional living is versioned independently and migrated on demand.
local Inventory=require("./Inventory")
local Professions=require("./ProfessionDefs")
local Items=require("./ItemDefs")
local Living={}
Living.VERSION=1

local function finite(n: any): boolean
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end

function Living.clone(value: any): any
    if type(value)~="table" then return value end
    local out={}
    for key,v in pairs(value) do out[Living.clone(key)]=Living.clone(v) end
    return out
end
function Living.new(seed: number): any
    local names={"Ari","Nilo","Cora","Lia"}
    local jobs={"carpenter","miner","builder","common"}
    local npcs={}
    for i=1,#names do
        local p=Professions.get(jobs[i])
        npcs[i]={id=i,name=names[i],profession=jobs[i],x=-3+(i-1)*3,
            inventory=Inventory.new(p.carryCapacity), health=100,
            hunger=0, fatigue=0, skill=1, state="idle", target=nil,
            carryItem=nil, reserved=0}
    end
    return {
        version=Living.VERSION,seed=seed,elapsed=0,nextBuildingId=1,
        npcs=npcs,buildings={},events={},
        sites={
            {id="wood_a",item="wood",x=-42,remaining=72},
            {id="wood_b",item="wood",x=-78,remaining=72},
            {id="stone_a",item="stone",x=-60,remaining=72},
            {id="stone_b",item="stone",x=41,remaining=60},
            {id="food_a",item="food",x=-24,remaining=70},
            {id="iron_a",item="iron",x=-98,remaining=40},
        },
        stats={gathered=0,delivered=0,built=0,repaired=0},
    }
end
function Living.valid(state: any): boolean
    if type(state)~="table" or state.version~=Living.VERSION
        or not finite(state.seed) or type(state.npcs)~="table"
        or type(state.buildings)~="table" or type(state.sites)~="table"
        or type(state.stats)~="table" or not finite(state.elapsed)
        or not finite(state.nextBuildingId) then return false end
    if #state.npcs>50 or #state.buildings>120 or #state.sites>256 then return false end
    for _,n in ipairs(state.npcs) do
        if type(n)~="table" or not finite(n.id) or not finite(n.x)
            or type(n.name)~="string" or not Professions.get(n.profession)
            or not Inventory.valid(n.inventory) or not finite(n.health)
            or not finite(n.hunger) or not finite(n.fatigue) then return false end
    end
    for _,site in ipairs(state.sites) do
        if not Items.get(site.item) or not finite(site.remaining)
            or site.remaining<0 or not finite(site.x) then return false end
    end
    for _,b in ipairs(state.buildings) do
        if type(b)~="table" or not finite(b.id) or not finite(b.x)
            or type(b.typeId)~="string" or type(b.delivered)~="table"
            or not finite(b.progress) or not finite(b.health) then return false end
    end
    return true
end
function Living.restore(data: any, seed: number): any
    if data==nil then return Living.new(seed) end
    if Living.valid(data) and data.seed==seed then return Living.clone(data) end
    return nil
end
return Living
