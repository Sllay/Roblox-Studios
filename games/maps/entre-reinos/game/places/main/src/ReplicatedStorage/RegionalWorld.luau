--!strict
local Profile=require("./RegionalProfile")
local Routes=require("./RegionalCrossings")
local Living=require("./Living/LivingModel")
local Work=require("./Living/WorkEngine")
local Structures=require("./Living/StructureDefs")
local Inventory=require("./Living/Inventory")

local World={}
World.VERSION=1
World.MAX_JSON_BYTES=512*1024
World.FOREIGN=2

local function range(n: any, lo: number, hi: number): boolean
    return type(n)=="number" and n>=lo and n<=hi
end

function World.validPosition(p: any): boolean
    return type(p)=="table" and range(p.x,-Profile.PLAY_EDGE,Profile.PLAY_EDGE)
        and range(p.y,-24,76) and p.z==0
end

function World.valid(record: any, seed: number, home: any): boolean
    if type(record)~="table" or record.version~=World.VERSION or record.generator~=Profile.GENERATOR_VERSION
        or type(record.discovered)~="table" or not World.validPosition(record.position) then return false end
    for index,value in pairs(record.discovered) do
        if (index~="0" and index~="2") or value~=true then return false end
    end
    if record.harvestedChunks~=nil then
        if type(record.harvestedChunks)~="table" then return false end
        for id,value in pairs(record.harvestedChunks) do
            local chunk=if type(id)=="string" then tonumber(id) else nil
            if not chunk or tostring(chunk)~=id or chunk%1~=0 or math.abs(chunk)>Profile.CHUNK_RADIUS
                or math.abs(chunk)<=8 or value~=true then return false end
        end
    end
    local foreign=record.foreign
    if foreign~=nil and (not Living.valid(foreign) or foreign.seed~=seed or foreign.r3~=nil) then return false end
    local graph=Routes.compile(seed)
    local crossings={}
    for _,crossing in ipairs(graph.crossings) do crossings[crossing.id]=crossing end
    local occupied={}
    for _,population in ipairs({home or {buildings={}},foreign or {buildings={}}}) do
        for _,building in ipairs(population.buildings) do
            local def=Structures.get(building.typeId)
            if def.kind=="crossing" then
                local crossing=crossings[building.crossingId]
                if not crossing or not crossing.buildable or occupied[crossing.id]
                    or building.x~=(crossing.west.x+crossing.east.x)/2 then return false end
                occupied[crossing.id]=true
            elseif building.crossingId~=nil then
                return false
            end
        end
    end
    if record.mount~=nil then
        local mount=record.mount
        if type(mount)~="table" or mount.id~="horse:1" or not World.validPosition(mount.position)
            or not range(mount.health,0,100) or not range(mount.energy,0,100)
            or (mount.lastLand~=nil and not World.validPosition(mount.lastLand)) then return false end
    end
    if record.boat~=nil then
        local boat=record.boat
        if type(boat)~="table" or boat.id~="boat:2" or not World.validPosition(boat.position)
            or not range(boat.health,0,100)
            or (boat.cargo~=nil and (not Inventory.valid(boat.cargo) or boat.cargo.maxMass~=36)) then return false end
    end
    if record.rider~=nil and ((record.rider~="mount" and record.rider~="boat")
        or not record[record.rider]) then return false end
    return true
end

function World.new(seed: number,home: any,persisted: any,position: any,readyAt: ((number)->boolean)?): any
    local record=persisted and Living.clone(persisted) or {
        version=World.VERSION,generator=Profile.GENERATOR_VERSION,
        position={x=position.x,y=position.y,z=0},discovered={["0"]=true},
    }
    if not World.valid(record,seed,home) then return nil end
    if home.r3 and home.r3.awaitingRecovery then
        -- A saved death takes precedence over the saved seat and location.
        record.rider=nil
        record.position={x=position.x,y=position.y,z=0}
    end
    local graph=Routes.compile(seed)
    record.harvestedChunks=record.harvestedChunks or {}
    local session={seed=seed,home=home,record=record,graph=graph,active=nil,phases={},
        center=assert(Profile.settlement(seed,World.FOREIGN)),activeRegion=nil}
    local function allBridges()
        local bridges={}
        for _,population in ipairs({home,record.foreign or {buildings={}}}) do
            for _,b in ipairs(population.buildings) do
                if b.crossingId then table.insert(bridges,b) end
            end
        end
        return bridges
    end
    session.bridges=allBridges
    session.readyAt=readyAt
    Work.bindRegion(home,graph,0,allBridges,readyAt)
    if record.foreign then
        record.foreign=Living.restore(record.foreign,seed)
        local center=assert(Profile.settlement(seed,World.FOREIGN))
        Work.bindRegion(record.foreign,graph,center.x,allBridges,readyAt)
    end
    return session
end

-- One authoritative population per kingdom. When nobody observes it,
-- leave the clock, jobs, inventory, health and reservations untouched.
function World.activate(session: any,x: number): (any, boolean)
    local index=Profile.regionAt(x) or 0
    local key=if index==World.FOREIGN then World.FOREIGN else 0
    local chunk=Profile.chunkAt(x)
    local keyChunk=tostring(chunk)
    if index~=0 and index~=World.FOREIGN and not session.record.harvestedChunks[keyChunk] then
        session.record.harvestedChunks[keyChunk]=true
        local added=0
        for _,site in ipairs(Profile.naturalSites(session.seed,chunk)) do
            local z=if site.item=="wood" then -6 else -4
            if Profile.sample(session.seed,site.x,z).wet then continue end
            if #session.home.sites>=256 or added>=4 then break end
            table.insert(session.home.sites,{id=site.id,item=site.item,x=site.x,z=z,remaining=site.initialAmount})
            added+=1
        end
    end
    if session.activeRegion==index then
        if key==World.FOREIGN and math.abs(x-session.center.x)<=14 then session.record.discovered["2"]=true end
        return session.active,false
    end
    if session.activeRegion~=nil then
        session.phases[session.activeRegion]="aggregated"
    end
    session.phases[index]=if session.phases[index]=="aggregated" then "reactivating" else "preparing"
    local state=session.home
    if key==World.FOREIGN then
        local center=session.center
        if not session.record.foreign then
            local population=Living.new(session.seed)
            local names={"Beatriz","Martim","Inês","Duarte"}
            for i,npc in ipairs(population.npcs) do
                npc.id+=1000
                npc.name=names[i]
                npc.x+=center.x
            end
            population.sites={}
            local middle=Profile.chunkAt(center.x)
            for townChunk=middle-2,middle+2 do
                if Profile.regionOfChunk(townChunk)~=key then continue end
                for _,site in ipairs(Profile.naturalSites(session.seed,townChunk)) do
                    if math.abs(site.x-center.x)>110 or Profile.sample(session.seed,site.x,-6).wet then continue end
                    table.insert(population.sites,{
                        id=site.id,item=site.item,x=site.x,z=if site.item=="wood" then -6 else -4,
                        remaining=site.initialAmount,
                    })
                end
            end
            -- The kingdom's commissioning stock is represented by actual
            -- completed settlement structures. Stockpiles start empty.
            Work.bindRegion(population,session.graph,center.x,session.bridges,session.readyAt)
            Work.initializeVillage(population,center.x)
            session.record.foreign=population
        end
        state=session.record.foreign
        if math.abs(x-center.x)<=14 then session.record.discovered["2"]=true end
    end
    local changed=session.active~=state
    session.active=state
    session.activeRegion=index
    session.phases[index]="active"
    return state,changed
end

function World.snapshot(session: any): any
    local record=Living.clone(session.record)
    if record.foreign then record.foreign.r3=nil end
    return record
end

return World
