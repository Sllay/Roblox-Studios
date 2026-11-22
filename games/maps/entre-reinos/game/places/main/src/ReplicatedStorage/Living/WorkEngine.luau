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
    npc.state="idle"
end
local function availableSource(state: any, item: string, x: number): any
    local best=nil
    local bestDist=math.huge
    for _,site in ipairs(state.sites) do
        if site.item==item and site.remaining>0 then
            -- Player-marked harvest trees are preferred by carpenters.
            -- Marking never duplicates wood or bypasses the NPC bag.
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
local function storeBuilding(state: any, id: any): any
    for _,b in ipairs(state.buildings) do
        if b.id==id and b.typeId=="stockpile" and b.state=="complete"
            and b.health>0 and b.stored then return b end
    end
    return nil
end
local function assignStorage(npc: any,state: any): boolean
    -- Low priority after construction. Stocking is not a free resource mint:
    -- resources first enter a real worker bag, then a finite galpão inventory.
    local best=nil
    local item=nil
    local source=nil
    local distance=math.huge
    for _,b in ipairs(state.buildings) do
        if storeBuilding(state,b.id) then
            for _,id in ipairs({"wood","stone","iron","food"}) do
                local current=Inventory.count(b.stored,id)
                local stockedSpace=b.stored.maxMass-Inventory.weight(b.stored)
                local def=Items.get(id)
                if current<STOCK_TARGET[id] and stockedSpace>=def.mass then
                    -- Return already-carried items before gathering any more.
                    local carried=Inventory.count(npc.inventory,id)
                    local s=if carried>0 then nil else availableSource(state,id,npc.x)
                    if carried>0 or (s and s.remaining>0) then
                        local score=math.abs(npc.x-b.x)
                            +(if s then math.abs(s.x-b.x) else 0)
                            -(if carried>0 then 500 else 0)
                        if score<distance then
                            distance=score;best=b;item=id;source=s
                        end
                    end
                end
            end
        end
    end
    if best and item then
        local available=if source then source.remaining
            else Inventory.count(npc.inventory,item)
        local free=math.floor((npc.inventory.maxMass-
            Inventory.weight(npc.inventory))/Items.get(item).mass)
        local maxCount=math.floor((best.stored.maxMass-
            Inventory.weight(best.stored))/Items.get(item).mass)
        local amount=if source then math.min(available,free,maxCount,
            STOCK_TARGET[item]-Inventory.count(best.stored,item),
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
    -- Choose a valid site/building pair. A worker claims quantities *before*
    -- travelling; two NPCs therefore never reserve the same missing boards.
    local winner=nil
    local chosenItem=nil
    local source=nil
    local bestUtility=-math.huge
    for _,b in ipairs(state.buildings) do
        if b.state~="complete" then
            local def=Structures.get(b.typeId)
            if def then
                for item,quantity in pairs(def.cost) do
                    local missing=needed(b,item)
                    if missing>0 then
                        local s=availableSource(state,item,npc.x)
                        if s then
                            local score=200-(math.abs(npc.x-s.x)+math.abs(s.x-b.x))*0.35
                                -npc.fatigue*0.15+math.min(25,missing*2)
                                +(Professions.gatherYield(npc.profession,item)-1)*12
                            if score>bestUtility then
                                bestUtility=score
                                winner=b
                                chosenItem=item
                                source=s
                            end
                        end
                    end
                end
            end
        end
    end
    if winner and chosenItem and source then
        local itemDef=Items.get(chosenItem)
        local free=math.floor((npc.inventory.maxMass-Inventory.weight(npc.inventory))
            /itemDef.mass)
        local amount=math.min(needed(winner,chosenItem),free,
            Professions.gatherYield(npc.profession,chosenItem),source.remaining)
        if amount>0 then
            winner.claimed[chosenItem]=(winner.claimed[chosenItem] or 0)+amount
            npc.jobId=winner.id
            npc.siteId=source.id
            npc.carryItem=chosenItem
            npc.reserved=amount
            npc.state="gather"
            return true
        end
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

-- Pure planning: only server-selected candidate positions are tested. Never
-- mutate a saved world, reserve materials, or add a blueprint during search.
function Engine.findPlacement(state: any, typeId: string, nearX: number): (boolean, any)
    local def=Structures.get(typeId)
    if not def then return false,"invalid_structure" end
    if type(nearX)~="number" or nearX~=nearX or math.abs(nearX)==math.huge then
        return false,"invalid_position"
    end
    if #state.buildings>=120 then return false,"building_limit" end

    -- Search nearest valid spot on the X gameplay lane, checking both sides.
    -- 48 studs is bounded and keeps new blueprints around the player.
    local origin=math.round(nearX/2)*2
    for step=0,24 do
        local candidate=origin+step*2
        local allowed=Engine.canPlace(state,typeId,candidate)
        if allowed then return true,candidate end
        if step>0 then
            candidate=origin-step*2
            allowed=Engine.canPlace(state,typeId,candidate)
            if allowed then return true,candidate end
        end
    end
    return false,"no_available_build_site"
end

-- Shared preflight for planner and final atomic server-side placement.
function Engine.canPlace(state: any, typeId: string, x: number): (boolean, string?)
    local def=Structures.get(typeId)
    if not def then return false,"invalid_structure" end
    if type(x)~="number" or x~=x or x< -112 or x>112 then
        return false,"outside_region"
    end
    if #state.buildings>=120 then return false,"building_limit" end
    local center=World.sample(state.seed,x,0)
    local left=World.sample(state.seed,x-def.footprint/2,0)
    local right=World.sample(state.seed,x+def.footprint/2,0)
    if center.wet or left.wet or right.wet
        or center.shore or left.shore or right.shore
        or math.abs(left.height-right.height)>def.maxSlope then
        return false,"invalid_footprint_or_slope"
    end
    for _,b in ipairs(state.buildings) do
        local other=Structures.get(b.typeId)
        if other and math.abs(x-b.x)<(def.footprint+other.footprint)*0.5+2 then
            return false,"overlapping_footprint"
        end
    end
    return true,nil
end

function Engine.place(state: any, typeId: string, x: number): (boolean, any)
    local valid,reason=Engine.canPlace(state,typeId,x)
    if not valid then return false,reason end
    local def=Structures.get(typeId)
    local center=World.sample(state.seed,x,0)
    local b={id=state.nextBuildingId,typeId=typeId,x=x,y=center.height,
        state="blueprint",progress=0,health=def.health,
        delivered={},claimed={},stored=Inventory.new(if def.storageMass>0 then def.storageMass else 1)}
    state.nextBuildingId+=1
    table.insert(state.buildings,b)
    table.insert(state.events,{kind="placed",buildingId=b.id,time=state.elapsed})
    return true,b
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
                    or source.remaining<=0 then
                    clearJob(npc,state)
                elseif walk(npc,source.x,dt) then
                    local n=math.min(npc.reserved,source.remaining)
                    if n>0 and Inventory.add(npc.inventory,item,n) then
                        source.remaining-=n
                        state.stats.gathered+=n
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
                    local availableMass=storage.stored.maxMass-
                        Inventory.weight(storage.stored)
                    local amount=math.min(carried,math.floor(availableMass/
                        Items.get(item).mass))
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
                    if not site or site.remaining<=0 then
                        clearJob(npc,state)
                    elseif walk(npc,site.x,dt) then
                        local n=math.min(npc.reserved,site.remaining)
                        if n>0 and Inventory.add(npc.inventory,item,n) then
                            site.remaining-=n
                            state.stats.gathered+=n
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
    for _,site in ipairs(state.sites) do
        sources[site.item]=(sources[site.item] or 0)+site.remaining
        if site.item=="wood" and site.marked==true and site.remaining>0 then
            markedTrees+=1
        end
    end
    for _,npc in ipairs(state.npcs) do
        for item,count in pairs(npc.inventory.items) do
            carried[item]=(carried[item] or 0)+count
        end
    end
    for _,b in ipairs(state.buildings) do
        if b.typeId=="stockpile" and b.stored then
            for item,count in pairs(b.stored.items) do
                deposited[item]=(deposited[item] or 0)+count
            end
        end
        for item,count in pairs(b.claimed) do
            reserved[item]=(reserved[item] or 0)+count
        end
        for item,count in pairs(b.delivered) do
            committed[item]=(committed[item] or 0)+count
        end
    end
    local buildings={}
    for _,b in ipairs(state.buildings) do
        local def=Structures.get(b.typeId)
        table.insert(buildings,{id=b.id,name=def.label,typeId=b.typeId,
            state=b.state,x=b.x,
            progress=math.floor(b.progress/def.buildSeconds*100),
            health=b.health,delivered=table.clone(b.delivered),
            stored=if b.stored then table.clone(b.stored.items) else {}})
    end
    local workers={}
    for _,n in ipairs(state.npcs) do
        table.insert(workers,{id=n.id,name=n.name,profession=n.profession,
            state=n.state,defense=n.defense or "none",
            carryWeight=Inventory.weight(n.inventory),
            carrying=table.clone(n.inventory.items)})
    end
    return {buildings=buildings,workers=workers,stats=table.clone(state.stats),
        resources={sources=sources,carried=carried,reserved=reserved,
            committed=committed,stored=deposited,markedTrees=markedTrees}}
end
return Engine
