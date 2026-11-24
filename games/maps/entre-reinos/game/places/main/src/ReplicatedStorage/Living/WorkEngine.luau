--!strict
-- T1-R2 pure, deterministic NPC work FSM. No NPC gains materials from a job:
-- sources are depleted, bags have real mass, delivery takes from those bags.
local Items=require("./ItemDefs")
local Structures=require("./StructureDefs")
local Professions=require("./ProfessionDefs")
local Inventory=require("./Inventory")
local World=require("../WorldProfile")
local Engine={}
local NEAR=1.6

local function findBuilding(state: any, id: any): any
    for _,b in ipairs(state.buildings) do
        if b.id==id then return b end
    end
    return nil
end
local function findSite(state: any, id: any): any
    for _,s in ipairs(state.sites) do
        if s.id==id then return s end
    end
    return nil
end
local function needed(b: any, item: string): number
    local def=Structures.get(b.typeId)
    if not def then return 0 end
    return math.max(0,(def.cost[item] or 0)-(b.delivered[item] or 0))
        - (b.claimed[item] or 0)
end
local function ready(b: any): boolean
    local def=Structures.get(b.typeId)
    if not def then return false end
    for item,n in pairs(def.cost) do
        if (b.delivered[item] or 0)<n then return false end
    end
    return true
end
local function clearJob(npc: any, state: any)
    local b=findBuilding(state,npc.jobId)
    if b and npc.reserved and npc.reserved>0 and npc.carryItem then
        b.claimed[npc.carryItem]=math.max(0,(b.claimed[npc.carryItem] or 0)-npc.reserved)
    end
    npc.jobId=nil
    npc.siteId=nil
    npc.storageId=nil
    npc.carryItem=nil
    npc.reserved=0
    npc.actionProgress=nil
    npc.state="idle"
end
function Engine.releaseWorker(state: any,npc: any)
    clearJob(npc,state)
end

function Engine.releaseBuildingJobs(state: any, buildingId: number)
    for _,npc in ipairs(state.npcs) do
        if npc.jobId==buildingId or npc.storageId==buildingId then clearJob(npc,state) end
    end
end

function Engine.sourceAvailable(state: any, site: any, except: any?): number
    local remaining=site.remaining
    for _,npc in ipairs(state.npcs) do
        if npc~=except and npc.siteId==site.id and npc.carryItem==site.item
            and (npc.state=="gather" or npc.state=="store_gather") then
            remaining-=npc.reserved
        end
    end
    return math.max(0,remaining)
end

local function availableSource(state: any, item: string, x: number): any
    local best=nil
    local bestDist=math.huge
    for _,site in ipairs(state.sites) do
        if site.item==item and Engine.sourceAvailable(state,site)>0 then
            local distance=math.abs(x-site.x)
                -(if item=="wood" and site.marked==true then 80 else 0)
            if distance<bestDist then
                best=site
                bestDist=distance
            end
        end
    end
    return best
end

local STOCK_TARGET={wood=24,stone=15,iron=10,food=20}
function Engine.usableStorage(b: any): boolean
    return b~=nil and b.typeId=="stockpile" and b.state=="complete"
        and b.health>0 and b.ruined~=true and b.stored~=nil
end

local function storeBuilding(state: any, id: any): any
    local b=findBuilding(state,id)
    return if Engine.usableStorage(b) then b else nil
end

function Engine.stockAvailable(state: any, b: any, item: string, except: any?): number
    if not Engine.usableStorage(b) then return 0 end
    local count=Inventory.count(b.stored,item)
    for _,npc in ipairs(state.npcs) do
        if npc~=except and npc.storageId==b.id and npc.carryItem==item
            and npc.state=="gather" then
            count-=npc.reserved
        end
    end
    return math.max(0,count)
end

local function freeUnits(bag: any, item: string): number
    return math.floor((bag.maxMass-Inventory.weight(bag))/Items.get(item).mass)
end

local function storageSpace(state: any, depot: any, item: string, except: any?): number
    local space=depot.stored.maxMass-Inventory.weight(depot.stored)
    for _,npc in ipairs(state.npcs) do
        if npc~=except and npc.storageId==depot.id and npc.carryItem
            and (npc.state=="store_gather" or npc.state=="store_deliver") then
            space-=npc.reserved*Items.get(npc.carryItem).mass
        end
    end
    return math.max(0,math.floor(space/Items.get(item).mass))
end

local function assignStorage(npc: any,state: any): boolean
    -- Low priority after construction. Stocking is not a free resource mint:
    -- resources first enter a real worker bag, then a finite galpão inventory.
    local best=nil
    local item=nil
    local source=nil
    local distance=math.huge
    for _,b in ipairs(state.buildings) do
        if Engine.usableStorage(b) then
            for _,id in ipairs({"wood","stone","iron","food"}) do
                if storageSpace(state,b,id)<=0 then continue end
                local carried=Inventory.count(npc.inventory,id)
                local s=if carried==0 and freeUnits(npc.inventory,id)>0
                    then availableSource(state,id,npc.x) else nil
                local ordered=s and s.marked==true and id=="wood"
                if carried>0 or (s and (ordered or Inventory.count(b.stored,id)<STOCK_TARGET[id])) then
                    local score=math.abs(npc.x-b.x)
                        +(if s then math.abs(s.x-b.x) else 0)
                        -(if carried>0 then 500 else 0)
                        -(if ordered then 250 else 0)
                    if score<distance then
                        distance=score
                        best=b
                        item=id
                        source=s
                    end
                end
            end
        end
    end
    if best and item then
        local available=if source then Engine.sourceAvailable(state,source)
            else Inventory.count(npc.inventory,item)
        local free=freeUnits(npc.inventory,item)
        local maxCount=storageSpace(state,best,item)
        local target=if source and source.marked==true and item=="wood" then maxCount
            else STOCK_TARGET[item]-Inventory.count(best.stored,item)
        local amount=if source then math.min(available,free,maxCount,target,
            Professions.gatherYield(npc.profession,item))
            else math.min(available,maxCount)
        if amount>0 then
            npc.storageId=best.id
            npc.carryItem=item
            npc.reserved=amount
            if source then
                npc.siteId=source.id
                npc.state="store_gather"
            else
                npc.siteId=nil
                npc.state="store_deliver"
            end
            return true
        end
    end
    return false
end

local function assign(npc: any, state: any): boolean
    local profession=Professions.get(npc.profession)
    if not profession then return false end
    -- Prefer an already-funded building. Profession multiplier applies to build
    -- seconds, never to actual delivered resource units.
    local funded=nil
    local nearest=math.huge
    for _,b in ipairs(state.buildings) do
        if b.state~="complete" and ready(b) then
            local distance=math.abs(npc.x-b.x)
            if distance<nearest then
                nearest=distance
                funded=b
            end
        end
    end
    if funded then
        npc.jobId=funded.id
        npc.state="build"
        return true
    end
    local winner=nil
    local chosenItem=nil
    local source=nil
    local storage=nil
    local amount=0
    local bestUtility=-math.huge
    local function consider(b: any,item: string,count: number,score: number,site: any,depot: any)
        if count>0 and score>bestUtility then
            winner=b
            chosenItem=item
            source=site
            storage=depot
            amount=count
            bestUtility=score
        end
    end
    for _,b in ipairs(state.buildings) do
        if b.state=="blueprint" or b.state=="ruined" then
            local def=Structures.get(b.typeId)
            local district=Engine.districtAt(state,b.x)
            for _,item in ipairs({"wood","stone","iron","food"}) do
                local missing=needed(b,item)
                if missing<=0 or not def.cost[item] then continue end
                consider(b,item,math.min(missing,Inventory.count(npc.inventory,item)),
                    500-math.abs(npc.x-b.x),nil,nil)
                local limit=math.min(missing,freeUnits(npc.inventory,item),
                    Professions.gatherYield(npc.profession,item))
                if limit<=0 then continue end
                for _,depot in ipairs(state.buildings) do
                    local free=Engine.stockAvailable(state,depot,item)
                    if free>0 then
                        local localDepot=district~=nil and Engine.districtAt(state,depot.x)==district
                        consider(b,item,math.min(limit,free),
                            325-(math.abs(npc.x-depot.x)+math.abs(depot.x-b.x))*0.35
                                +(if localDepot then 8 else 0),nil,depot)
                    end
                end
                local site=availableSource(state,item,npc.x)
                if site then
                    local score=200-(math.abs(npc.x-site.x)+math.abs(site.x-b.x))*0.35
                        -npc.fatigue*0.15+math.min(25,missing*2)
                        +(Professions.gatherYield(npc.profession,item)-1)*12
                    consider(b,item,math.min(limit,Engine.sourceAvailable(state,site)),score,site,nil)
                end
            end
        end
    end
    if winner and chosenItem then
        winner.claimed[chosenItem]=(winner.claimed[chosenItem] or 0)+amount
        npc.jobId=winner.id
        npc.siteId=if source then source.id else nil
        npc.storageId=if storage then storage.id else nil
        npc.carryItem=chosenItem
        npc.reserved=amount
        npc.state=if source or storage then "gather" else "deliver"
        return true
    end
    return assignStorage(npc,state)
end

local function walk(npc: any, destX: number, dt: number): boolean
    npc.targetX=destX
    local diff=destX-npc.x
    if math.abs(diff)<=NEAR then return true end
    local speed=Professions.get(npc.profession).moveSpeed
    local travel=math.min(math.abs(diff),speed*dt)
    npc.x+=if diff>0 then travel else -travel
    -- Stable per-tick walking intent for client presentation: unlike
    -- snapshot-distance / irregular network-interval estimates, this does
    -- not alternate fast and slow merely because 1 or 2 ticks elapsed.
    npc.motionX=(if diff>0 then 1 else -1)*travel/dt
    npc.fatigue=math.min(100,npc.fatigue+dt*0.03)
    return math.abs(destX-npc.x)<=NEAR
end

local function working(npc: any,dt: number,activity: string): boolean
    npc.activity=activity
    npc.actionProgress=(npc.actionProgress or 0)+dt
    if npc.actionProgress<0.6 then return false end
    npc.actionProgress=nil
    return true
end

-- Pure footprint and route checks shared by preview and confirmation.
function Engine.canPlace(state: any, typeId: string, x: number): (boolean, string?)
    local def=Structures.get(typeId)
    if not def then return false,"invalid_structure" end
    if type(x)~="number" or x~=x or math.abs(x)+def.footprint/2>120 then
        return false,"outside_region"
    end
    if #state.buildings>=120 then return false,"building_limit" end
    local low=math.huge
    local high=-math.huge
    for _,z in ipairs({World.LANE_Z,Structures.DEPTH_Z-3.5,Structures.DEPTH_Z+3.5}) do
        for step=-2,2 do
            local sample=World.sample(state.seed,x+step*def.footprint/4,z)
            if sample.wet or sample.shore then return false,"invalid_footprint_or_slope" end
            low=math.min(low,sample.height)
            high=math.max(high,sample.height)
        end
    end
    if high-low>def.maxSlope then return false,"invalid_footprint_or_slope" end
    local direction=if x<0 then -1 else 1
    for distance=4,math.abs(x),4 do
        if World.sample(state.seed,distance*direction,World.LANE_Z).wet then
            return false,"no_worker_route"
        end
    end
    for _,site in ipairs(state.sites) do
        if site.item=="wood" and site.remaining>0 and not site.salvage
            and not string.match(site.id,"salvage_")
            and math.abs(x-site.x)<def.footprint/2+2 then
            return false,"occupied_by_tree"
        end
    end
    for _,b in ipairs(state.buildings) do
        local other=Structures.get(b.typeId)
        if other and math.abs(x-b.x)<(def.footprint+other.footprint)*0.5+2 then
            return false,"overlapping_footprint"
        end
    end
    return true,nil
end

function Engine.place(state: any, typeId: string, x: number, groundY: number?): (boolean, any)
    local valid,reason=Engine.canPlace(state,typeId,x)
    if not valid then return false,reason end
    local def=Structures.get(typeId)
    local center=World.sample(state.seed,x,Structures.DEPTH_Z)
    local b={id=state.nextBuildingId,typeId=typeId,x=x,y=groundY or center.height,
        state="blueprint",progress=0,health=def.health,
        delivered={},claimed={},stored=Inventory.new(if def.storageMass>0 then def.storageMass else 1)}
    state.nextBuildingId+=1
    table.insert(state.buildings,b)
    table.insert(state.events,{kind="placed",buildingId=b.id,time=state.elapsed})
    return true,b
end

function Engine.canCancel(b: any): boolean
    return b~=nil and (b.state=="blueprint" or b.state=="building") and b.ruined~=true
end

function Engine.cancel(state: any, id: number): (boolean, string?)
    for i,b in ipairs(state.buildings) do
        if b.id==id then
            if not Engine.canCancel(b) then return false,"building_cannot_cancel" end
            -- Staging policy: delivered material remains in a physical
            -- recovery pile at the site. No credit to a second inventory.
            local returns={}
            for item,amount in pairs(b.delivered) do
                if amount>0 then
                    table.insert(returns,{id="cancelled_"..tostring(id).."_"..item,
                        item=item,x=b.x,remaining=amount,salvage=true})
                end
            end
            if #state.sites+#returns>256 then return false,"no_recovery_space" end
            Engine.releaseBuildingJobs(state,id)
            table.remove(state.buildings,i)
            for _,site in ipairs(returns) do table.insert(state.sites,site) end
            return true,nil
        end
    end
    return false,"building_not_found"
end

function Engine.districtAt(state: any,x: number): string?
    local left,right=nil,nil
    for _,b in ipairs(state.buildings) do
        if b.districtBoundary=="west" then left=b.x end
        if b.districtBoundary=="east" then right=b.x end
    end
    if not left or not right then return nil end
    if x<left then return "Oeste" end
    if x>right then return "Leste" end
    return "Centro"
end

function Engine.initializeVillage(state: any): boolean
    if #state.buildings>0 or state.nextBuildingId~=1 then return false end
    local plan={
        {typeId="castle",x=0},
        {typeId="stockpile",x=-17}, {typeId="stockpile",x=17},
        {typeId="wall",x=-33}, {typeId="wall",x=33},
        {typeId="shelter",x=-55},
    }
    for _,entry in ipairs(plan) do
        local id=entry.typeId
        local placed,b=Engine.place(state,id,entry.x)
        if not placed then
            -- The shelter is optional on a steep seed. All core buildings
            -- fit on the deterministic central plateau.
            assert(id=="shelter","invalid starter village layout")
            continue
        end
        local def=Structures.get(id)
        b.state="complete"
        b.progress=def.buildSeconds
        b.delivered=table.clone(def.cost)
        if id=="wall" then
            b.districtBoundary=if entry.x<0 then "west" else "east"
        end
    end
    table.clear(state.events)
    return true
end

function Engine.damage(state: any, buildingId: number, amount: number): boolean
    local b=findBuilding(state,buildingId)
    if not b or b.state~="complete" or type(amount)~="number" or amount<=0 then return false end
    b.health=math.max(0,b.health-amount)
    if b.health<Structures.get(b.typeId).health then b.state="damaged" end
    return true
end

function Engine.step(state: any, dt: number)
    if type(dt)~="number" or dt~=dt or dt<=0 then return end
    -- Fixed step by the host; cap to avoid huge catch-up after a sleeping phone.
    dt=math.min(dt,0.25)
    state.elapsed+=dt
    for _,npc in ipairs(state.npcs) do
        npc.motionX=0
        npc.activity=nil
        if npc.health<=0 then continue end
        npc.hunger=math.min(100,npc.hunger+dt*0.045)
        -- During a real nearby raid, civilians pause their tasks without
        -- canceling reserved materials or losing work progress. R3Engine
        -- determines danger and defensive/escape movement after this tick.
        if npc.underAttack then continue end
        if npc.hunger>70 and Inventory.count(npc.inventory,"food")>0 then
            if Inventory.take(npc.inventory,"food",1) then npc.hunger-=45 end
        end
        if npc.fatigue>85 then
            clearJob(npc,state)
            npc.state="rest"
        end
        if npc.state=="rest" then
            npc.fatigue=math.max(0,npc.fatigue-dt*4)
            if npc.fatigue<20 then npc.state="idle" end
        else
            if npc.state=="idle" then assign(npc,state) end
            local b=findBuilding(state,npc.jobId)
            if npc.state=="store_gather" then
                local storage=storeBuilding(state,npc.storageId)
                local source=findSite(state,npc.siteId)
                local item=npc.carryItem
                if not storage or not source or not item
                    or source.item~=item then
                    clearJob(npc,state)
                elseif walk(npc,source.x,dt) and working(npc,dt,"collect") then
                    local n=math.min(npc.reserved,Engine.sourceAvailable(state,source,npc),
                        storageSpace(state,storage,item,npc))
                    if n>0 and Inventory.add(npc.inventory,item,n) then
                        source.remaining-=n
                        state.stats.gathered+=n
                        npc.reserved=n
                        npc.siteId=nil
                        npc.state="store_deliver"
                    else
                        clearJob(npc,state)
                    end
                end
            elseif npc.state=="store_deliver" then
                local storage=storeBuilding(state,npc.storageId)
                local item=npc.carryItem
                if not storage or not item then
                    clearJob(npc,state)
                elseif walk(npc,storage.x,dt) then
                    local carried=Inventory.count(npc.inventory,item)
                    local amount=math.min(carried,npc.reserved,storageSpace(state,storage,item,npc))
                    if amount>0 and Inventory.transfer(npc.inventory,
                        storage.stored,item,amount) then
                        state.stats.stored=(state.stats.stored or 0)+amount
                    end
                    clearJob(npc,state)
                end
            elseif npc.state~="idle" and (not b or b.state=="complete") then
                clearJob(npc,state)
            elseif b then
                local item=npc.carryItem
                if npc.state=="gather" and item then
                    local site=findSite(state,npc.siteId)
                    local storage=storeBuilding(state,npc.storageId)
                    if not storage and (not site or site.item~=item) then
                        clearJob(npc,state)
                    elseif walk(npc,if storage then storage.x else site.x,dt)
                        and working(npc,dt,if storage then "load" else "collect") then
                        local available=if storage then Engine.stockAvailable(state,storage,item,npc)
                            else Engine.sourceAvailable(state,site,npc)
                        local n=math.min(npc.reserved,available)
                        local pickedUp=n>0 and (if storage then
                            Inventory.transfer(storage.stored,npc.inventory,item,n)
                            else Inventory.add(npc.inventory,item,n))
                        if pickedUp then
                            if not storage then
                                site.remaining-=n
                                state.stats.gathered+=n
                            end
                            b.claimed[item]-=npc.reserved-n
                            npc.reserved=n
                            npc.siteId=nil
                            npc.storageId=nil
                            npc.state="deliver"
                        else
                            clearJob(npc,state)
                        end
                    end
                elseif npc.state=="deliver" and item then
                    if walk(npc,b.x,dt) then
                        local n=math.min(npc.reserved,Inventory.count(npc.inventory,item),
                            math.max(0,(Structures.get(b.typeId).cost[item] or 0)
                                -(b.delivered[item] or 0)))
                        if n>0 and Inventory.take(npc.inventory,item,n) then
                            b.delivered[item]=(b.delivered[item] or 0)+n
                            state.stats.delivered+=n
                        end
                        clearJob(npc,state)
                    end
                elseif npc.state=="build" then
                    if not ready(b) then
                        clearJob(npc,state)
                    elseif walk(npc,b.x,dt) then
                        npc.activity="build"
                        local def=Structures.get(b.typeId)
                        local rate=Professions.buildRate(npc.profession)
                        local step=dt*rate
                        if b.state=="damaged" then
                            b.health=math.min(def.health,b.health+step*2)
                            if b.health>=def.health then
                                b.state="complete"
                                state.stats.repaired+=1
                                table.insert(state.events,{kind="repaired",buildingId=b.id,time=state.elapsed})
                                clearJob(npc,state)
                            end
                        else
                            b.progress=math.min(def.buildSeconds,b.progress+step)
                            b.state="building"
                            if b.progress>=def.buildSeconds then
                                b.state="complete"
                                -- A ruin becomes physically usable only after
                                -- a completely new material-backed rebuild.
                                if b.ruined==true then
                                    b.ruined=false
                                    b.health=def.health
                                end
                                state.stats.built+=1
                                table.insert(state.events,{kind="completed",buildingId=b.id,time=state.elapsed})
                                clearJob(npc,state)
                            end
                        end
                        npc.fatigue=math.min(100,npc.fatigue+dt*0.20)
                    end
                end
            end
        end
    end
    -- Never retain unbounded event logs in a persistent slot.
    while #state.events>80 do table.remove(state.events,1) end
end

function Engine.summary(state: any): any
    -- Real inventory custody. Sources are NOT the player's backpack, and
    -- resources already delivered to structures are NOT free stock.
    local sources={wood=0,stone=0,iron=0,food=0}
    local markedTrees=0
    local carried={wood=0,stone=0,iron=0,food=0}
    local reserved={wood=0,stone=0,iron=0,food=0}
    local committed={wood=0,stone=0,iron=0,food=0}
    local deposited={wood=0,stone=0,iron=0,food=0}
    local isolated={wood=0,stone=0,iron=0,food=0}
    for _,site in ipairs(state.sites) do
        sources[site.item]=(sources[site.item] or 0)+site.remaining
        if site.item=="wood" and site.marked==true and site.remaining>0 then
            markedTrees+=1
        end
    end
    for _,npc in ipairs(state.npcs) do
        for item,count in pairs(npc.inventory.items) do
            local account=if npc.health<=0 then isolated else carried
            account[item]=(account[item] or 0)+count
        end
    end
    for _,b in ipairs(state.buildings) do
        if b.typeId=="stockpile" and b.stored and not b.ruined and b.state~="ruined" then
            for item,count in pairs(b.stored.items) do
                deposited[item]=(deposited[item] or 0)+count
            end
        end
        for item,count in pairs(b.ruinedStock or {}) do
            isolated[item]=(isolated[item] or 0)+count
        end
        for item,count in pairs(b.claimed) do
            reserved[item]=(reserved[item] or 0)+count
        end
        for item,count in pairs(b.delivered) do
            committed[item]=(committed[item] or 0)+count
        end
    end
    local buildings={}
    local districts={}
    for _,b in ipairs(state.buildings) do
        local def=Structures.get(b.typeId)
        local district=Engine.districtAt(state,b.x)
        if district then
            local tally=districts[district] or {warehouses=0,works=0,damage=0}
            if Engine.usableStorage(b) then tally.warehouses+=1 end
            if b.state=="blueprint" or b.state=="building" then tally.works+=1 end
            if b.state=="ruined" or b.state=="damaged" then tally.damage+=1 end
            districts[district]=tally
        end
        table.insert(buildings,{id=b.id,name=def.label,typeId=b.typeId,
            state=b.state,x=b.x,canCancel=Engine.canCancel(b),district=district,
            progress=math.floor(b.progress/def.buildSeconds*100),
            health=b.health,delivered=table.clone(b.delivered),
            stored=if b.stored then table.clone(b.stored.items) else {}})
    end
    local workers={}
    for _,n in ipairs(state.npcs) do
        table.insert(workers,{id=n.id,name=n.name,profession=n.profession,
            state=n.activity or n.state,defense=n.defense or "none",
            district=Engine.districtAt(state,n.x),health=n.health,arrows=n.arrows or 0,
            carryWeight=Inventory.weight(n.inventory),
            carrying=table.clone(n.inventory.items)})
    end
    return {buildings=buildings,workers=workers,districts=districts,stats=table.clone(state.stats),
        resources={sources=sources,carried=carried,reserved=reserved,
            committed=committed,stored=deposited,isolated=isolated,markedTrees=markedTrees}}
end
return Engine
