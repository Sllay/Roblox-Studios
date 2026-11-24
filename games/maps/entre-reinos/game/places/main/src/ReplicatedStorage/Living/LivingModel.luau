--!strict
-- State-only model, detached from engine. Existing R1 six-slot schema is retained;
-- optional living is versioned independently and migrated on demand.
local Inventory=require("./Inventory")
local Professions=require("./ProfessionDefs")
local Structures=require("./StructureDefs")
local Items=require("./ItemDefs")
local R3=require("./R3Engine")
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
        -- True persisted depth, not a renderer-only corridor index.
        -- Seed/id jitter creates independent three-dimensional positions.
        local z= -6+((seed%97+i*53)%131)/131*12
        npcs[i]={id=i,name=names[i],profession=jobs[i],x=-3+(i-1)*3,z=z,
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
local function units(n: any): boolean
    return finite(n) and n>=0 and n%1==0
end

local function counts(items: any): boolean
    if type(items)~="table" then return false end
    for item,count in pairs(items) do
        if not Items.get(item) or not units(count) then return false end
    end
    return true
end

local function array(value: any, limit: number): boolean
    if type(value)~="table" or #value>limit then return false end
    local n=#value
    local count=0
    for index in pairs(value) do
        if not units(index) or index<1 or index>n then return false end
        count+=1
    end
    return count==n
end

function Living.valid(state: any): boolean
    if type(state)~="table" or state.version~=Living.VERSION
        or not finite(state.seed) or not array(state.npcs,50)
        or not array(state.buildings,120) or not array(state.sites,256)
        or not array(state.events,100) or not finite(state.elapsed)
        or state.elapsed<0 or not units(state.nextBuildingId)
        or state.nextBuildingId<1 or type(state.stats)~="table" then return false end
    for _,field in ipairs({"gathered","delivered","built","repaired"}) do
        if not units(state.stats[field]) then return false end
    end
    if state.stats.stored~=nil and not units(state.stats.stored) then return false end
    if state.r3~=nil and not R3.valid(state.r3) then return false end
    local npcIds={}
    for _,n in ipairs(state.npcs) do
        if type(n)~="table" or not units(n.id) or npcIds[n.id] or not finite(n.x)
            or (n.z~=nil and (not finite(n.z) or math.abs(n.z)>32))
            or (n.wanderX~=nil and not finite(n.wanderX))
            or (n.wanderZ~=nil and not finite(n.wanderZ))
            or (n.wanderUntil~=nil and not finite(n.wanderUntil))
            or type(n.name)~="string" or not Professions.get(n.profession)
            or not Inventory.valid(n.inventory) or not finite(n.health)
            or not finite(n.hunger) or not finite(n.fatigue) or not units(n.reserved)
            or (n.carryItem~=nil and not Items.get(n.carryItem)) then return false end
        npcIds[n.id]=true
    end
    for _,site in ipairs(state.sites) do
        -- Older ruins may contain duplicate salvage IDs. Restore disambiguates them.
        if type(site)~="table" or type(site.id)~="string" or not Items.get(site.item)
            or not units(site.remaining) or not finite(site.x) then return false end
    end
    local buildingIds={}
    for _,b in ipairs(state.buildings) do
        if type(b)~="table" or not units(b.id) or b.id>=state.nextBuildingId
            or buildingIds[b.id] or not finite(b.x) or not finite(b.y)
            or not Structures.get(b.typeId) or not counts(b.delivered) or not counts(b.claimed)
            or not finite(b.progress) or not finite(b.health)
            or (b.ruinedStock~=nil and (b.typeId~="stockpile" or not counts(b.ruinedStock)))
            or (b.ruinCount~=nil and not units(b.ruinCount))
            or (b.stored~=nil and not Inventory.valid(b.stored)) then return false end
        buildingIds[b.id]=true
    end
    return true
end
function Living.restore(data: any, seed: number): any
    if data==nil then return Living.new(seed) end
    if not Living.valid(data) or data.seed~=seed then return nil end
    local restored=Living.clone(data)
    local ids={}
    for _,site in ipairs(restored.sites) do ids[site.id]=true end
    local seen={}
    for index,site in ipairs(restored.sites) do
        if seen[site.id] then
            local id="legacy_salvage_"..tostring(index)
            while ids[id] do id..="_" end
            ids[id]=true
            site.id=id
        end
        seen[site.id]=true
    end
    local buildings={}
    for _,building in ipairs(restored.buildings) do
        buildings[building.id]=building
        building.claimed={}
        if building.ruined or building.state=="ruined" then
            R3.isolateRuinedStock(building)
        end
    end
    for _,npc in ipairs(restored.npcs) do
        if npc.z==nil then
            npc.z= -6+((seed%97+npc.id*53)%131)/131*12
        end
        local b=if npc.jobId~=nil then buildings[npc.jobId] else nil
        if b and npc.carryItem and (npc.state=="gather" or npc.state=="deliver") then
            b.claimed[npc.carryItem]=(b.claimed[npc.carryItem] or 0)+npc.reserved
        end
    end
    return restored
end
return Living
