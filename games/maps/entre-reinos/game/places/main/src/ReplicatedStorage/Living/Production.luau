--!strict
-- A production order owns no stock. Ingredients move into the worker's
-- actual bag at pickup and are exchanged only after reaching the station.
local Inventory=require("./Inventory")
local Items=require("./ItemDefs")
local Professions=require("./ProfessionDefs")
local Production={}
Production.VERSION=1
Production.MAX_ORDERS=12
Production.order=table.freeze({"planks","smelt","axe","pick","hammer","hoe","bow","spear","bread","cook"})
Production.recipes=table.freeze({
    planks={station="workshop",input={wood=2},item="plank",quantity=3,time=4,label="Serrar madeira",cost="2 madeira → 3 tábuas"},
    smelt={station="forge",input={iron=2,wood=1},item="metal",quantity=2,time=8,label="Fundir ferro",cost="2 ferro + 1 madeira → 2 metal"},
    axe={station="forge",input={metal=1,wood=1},item="axe",quantity=1,time=5,label="Fazer machado",cost="1 metal + 1 madeira"},
    pick={station="forge",input={metal=1,wood=1},item="pick",quantity=1,time=5,label="Fazer picareta",cost="1 metal + 1 madeira"},
    hammer={station="forge",input={metal=1,wood=1},item="hammer",quantity=1,time=5,label="Fazer martelo",cost="1 metal + 1 madeira"},
    hoe={station="forge",input={metal=1,wood=1},item="hoe",quantity=1,time=5,label="Fazer enxada",cost="1 metal + 1 madeira"},
    bow={station="workshop",input={plank=2,leather=1},item="bow",quantity=1,time=6,label="Fazer arco",cost="2 tábuas + 1 couro"},
    spear={station="forge",input={metal=1,plank=1},item="spear",quantity=1,time=6,label="Fazer lança",cost="1 metal + 1 tábua"},
    bread={station="workshop",input={grain=2,wood=1},item="food",quantity=4,time=5,label="Assar pão",cost="2 grãos + 1 madeira → 4 alimento"},
    cook={station="workshop",input={meat=2,wood=1},item="food",quantity=4,time=5,label="Cozinhar carne",cost="2 carnes + 1 madeira → 4 alimento"},
} :: {[string]: any})

local function integer(value: any,min: number,max: number): boolean
    return type(value)=="number" and value%1==0 and value>=min and value<=max
end

function Production.valid(data: any, state: any): boolean
    if type(data)~="table" or data.version~=Production.VERSION
        or not integer(data.nextOrder,1,1e9) or not integer(data.completed,0,1e9)
        or (data.priorityBuilding~=nil and not integer(data.priorityBuilding,1,state.nextBuildingId-1))
        or (data.focusFood~=nil and type(data.focusFood)~="boolean")
        or (data.stewardPlanned~=nil and type(data.stewardPlanned)~="boolean")
        or type(data.orders)~="table" or #data.orders>Production.MAX_ORDERS then return false end
    local stations={}
    local workers={}
    for _,b in ipairs(state.buildings) do stations[b.id]=b end
    for _,npc in ipairs(state.npcs) do workers[npc.id]=npc end
    local ids={}
    local assigned={}
    for index,order in pairs(data.orders) do
        if not integer(index,1,#data.orders) or type(order)~="table"
            or not integer(order.id,1,data.nextOrder-1) or ids[order.id]
            or type(order.recipe)~="string" or not Production.recipes[order.recipe]
            or not integer(order.station,1,state.nextBuildingId-1)
            or not stations[order.station] or stations[order.station].typeId~=Production.recipes[order.recipe].station
            or type(order.progress)~="number" or not (order.progress>=0 and order.progress<=Production.recipes[order.recipe].time)
            or (order.worker~=nil and (not integer(order.worker,1,1e9)
                or not workers[order.worker] or assigned[order.worker])) then return false end
        ids[order.id]=true
        if order.worker then assigned[order.worker]=true end
    end
    for _,npc in ipairs(state.npcs) do
        if npc.order~=nil and npc.order~="balanced" and npc.order~="food" and
            npc.order~="building" and npc.order~="stock" then return false end
        local function validTool(tool: any): boolean
            if tool==nil then return true end
            local def=type(tool)=="table" and Items.get(tool.item)
            return def~=nil and def.kind=="tool" and integer(tool.remaining,1,def.durability)
        end
        local requested=Items.get(npc.gearOrder)
        if (npc.gearOrder~=nil and (not requested or (requested.kind~="tool" and requested.kind~="weapon")))
            or not validTool(npc.tool) or not validTool(npc.gearSpare)
            or (npc.gearDepot~=nil and not integer(npc.gearDepot,1,state.nextBuildingId-1))
            or (npc.gearUntil~=nil and not (type(npc.gearUntil)=="number" and npc.gearUntil>=0 and npc.gearUntil<1e9))
            or (npc.gearRetry~=nil and not (type(npc.gearRetry)=="number" and npc.gearRetry>=0 and npc.gearRetry<1e9)) then
            return false
        end
    end
    return true
end

function Production.ensure(state: any)
    if state.production==nil then
        state.production={version=Production.VERSION,nextOrder=1,completed=0,orders={}}
    end
end

local function available(station: any): boolean
    return station~=nil and station.state=="complete" and station.health>0 and not station.ruined
end

function Production.enqueue(state: any, recipeId: any, x: number, stationId: number?): (boolean, any)
    local data=state.production
    local recipe=type(recipeId)=="string" and Production.recipes[recipeId]
    if not data or not recipe then return false,"unknown_recipe" end
    if #data.orders>=Production.MAX_ORDERS then return false,"production_queue_full" end
    local closest=nil
    local distance=18
    for _,station in ipairs(state.buildings) do
        local d=math.abs(x-station.x)
        if (stationId==nil or station.id==stationId) and station.typeId==recipe.station and available(station) and d<distance then
            closest,distance=station,d
        end
    end
    if not closest then return false,"production_station_required" end
    local id=data.nextOrder
    data.nextOrder+=1
    table.insert(data.orders,{id=id,recipe=recipeId,station=closest.id,progress=0})
    return true,id
end

function Production.release(state: any,npc: any)
    local data=state.production
    if not data then return end
    for _,order in ipairs(data.orders) do
        if order.worker==npc.id then
            order.worker=nil
        end
    end
end

function Production.removeStation(state: any,id: number)
    local data=state.production
    if not data then return end
    for i=#data.orders,1,-1 do
        if data.orders[i].station==id then table.remove(data.orders,i) end
    end
end

function Production.toolRate(npc: any,item: string): number
    return if npc.tool and npc.tool.item==item then 1.35 else 1
end

function Production.wear(npc: any,item: string)
    if not npc.tool or npc.tool.item~=item then return end
    npc.tool.remaining-=1
    if npc.tool.remaining==0 then npc.tool=nil end
end

local function ingredients(npc: any,recipe: any,storage: any,work: any,state: any): any
    local bag=Inventory.new(npc.inventory.maxMass)
    bag.items=table.clone(npc.inventory.items)
    local missing={}
    for item,amount in pairs(recipe.input) do
        local need=math.max(0,amount-Inventory.count(bag,item))
        if need>0 then
            if not storage or work.stockAvailable(state,storage,item)<need or not Inventory.add(bag,item,need) then
                return nil
            end
            missing[item]=need
        end
    end
    return missing
end

function Production.step(state: any,npc: any,dt: number,work: any): boolean
    local data=state.production
    if not data or (npc.state~="idle" and npc.state~="produce" and npc.state~="tool") then return false end
    local profession=Professions.get(npc.profession)
    local wanted=profession.tool
    if wanted and not npc.tool and npc.state~="produce" then
        for _,storage in ipairs(state.buildings) do
            if work.stockAvailable(state,storage,wanted)>0 and work.canReach(state,npc.x,storage.x,"worker") then
                npc.state="tool"
                if work.walkResident(state,npc,storage.x,dt,-4.4) and Inventory.take(storage.stored,wanted,1) then
                    npc.tool={item=wanted,remaining=Items.get(wanted).durability}
                    npc.state="idle"
                end
                return true
            end
        end
        if npc.state=="tool" then npc.state="idle" end
    end
    for i,order in ipairs(data.orders) do
        if order.worker~=nil and order.worker~=npc.id then continue end
        local station=work.findBuilding(state,order.station)
        local recipe=Production.recipes[order.recipe]
        if not available(station) or not work.canReach(state,npc.x,station.x,"carrier") then
            if order.worker==npc.id then Production.release(state,npc) end
            continue
        end
        local depot=nil
        local direct=ingredients(npc,recipe,nil,work,state)
        if not direct then
            for _,b in ipairs(state.buildings) do
                if work.usableStorage(b) and work.canReach(state,npc.x,b.x,"worker")
                    and work.canReach(state,b.x,station.x,"carrier") and ingredients(npc,recipe,b,work,state) then
                    depot=b
                    break
                end
            end
            if not depot then
                if order.worker==npc.id then Production.release(state,npc) end
                continue
            end
        end
        if not order.worker and profession.craft~=recipe.station then
            local specialist=false
            for _,other in ipairs(state.npcs) do
                if other~=npc and other.health>0 and other.state=="idle" and not other.underAttack
                    and Professions.get(other.profession).craft==recipe.station
                    and work.canReach(state,other.x,station.x,"carrier") then specialist=true;break end
            end
            if specialist then continue end
        end
        order.worker=npc.id
        npc.state="produce"
        if depot then
            if work.walkResident(state,npc,depot.x,dt,-4.4) then
                local missing=ingredients(npc,recipe,depot,work,state)
                if missing then
                    for item,count in pairs(missing) do
                        assert(Inventory.transfer(depot.stored,npc.inventory,item,count),"production pickup")
                    end
                end
            end
            return true
        end
        if not work.walkResident(state,npc,station.x,dt,-4.4) then return true end
        npc.activity="fabricate"
        local rate=(if profession.craft==recipe.station then 1.65 else 1)*Production.toolRate(npc,"hammer")
            *work.activityRate(npc,"craft")
        order.progress=math.min(recipe.time,order.progress+dt*rate)
        if order.progress<recipe.time then return true end
        local after=Inventory.new(npc.inventory.maxMass)
        after.items=table.clone(npc.inventory.items)
        for item,count in pairs(recipe.input) do assert(Inventory.take(after,item,count)) end
        if not Inventory.add(after,recipe.item,recipe.quantity) then
            -- Free space through the ordinary worker delivery path and retry.
            Production.release(state,npc)
            npc.state="idle"
            return false
        end
        npc.inventory.items=after.items
        Production.wear(npc,"hammer")
        work.learn(state,npc,"craft",6)
        data.completed+=1
        table.remove(data.orders,i)
        npc.state="idle"
        return true
    end
    npc.state="idle"
    return false
end

return Production
