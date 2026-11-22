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
    npc.carryItem=nil
    npc.reserved=0
    npc.state="idle"
end
local function availableSource(state: any, item: string, x: number): any
    local best=nil
    local bestDist=math.huge
    for _,site in ipairs(state.sites) do
        if site.item==item and site.remaining>0 then
            local distance=math.abs(x-site.x)
            if distance<bestDist then
                best=site
                bestDist=distance
            end
        end
    end
    return best
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
    return false
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

function Engine.place(state: any, typeId: string, x: number): (boolean, any)
    local def=Structures.get(typeId)
    if not def then return false,"invalid_structure" end
    if type(x)~="number" or x~=x or x< -112 or x>112 then
        return false,"outside_region"
    end
    if #state.buildings>=120 then return false,"building_limit" end
    local center=World.sample(state.seed,x,0)
    local left=World.sample(state.seed,x-def.footprint/2,0)
    local right=World.sample(state.seed,x+def.footprint/2,0)
    if center.wet or left.wet or right.wet or center.shore or
        math.abs(left.height-right.height)>def.maxSlope then
        return false,"invalid_footprint_or_slope"
    end
    for _,b in ipairs(state.buildings) do
        local other=Structures.get(b.typeId)
        if other and math.abs(x-b.x)<(def.footprint+other.footprint)*0.5+2 then
            return false,"overlapping_footprint"
        end
    end
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
            if npc.state~="idle" and (not b or b.state=="complete") then
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
    local buildings={}
    for _,b in ipairs(state.buildings) do
        local def=Structures.get(b.typeId)
        table.insert(buildings,{id=b.id,name=def.label,state=b.state,
            x=b.x,progress=math.floor(b.progress/def.buildSeconds*100),
            health=b.health,delivered=table.clone(b.delivered)})
    end
    local workers={}
    for _,n in ipairs(state.npcs) do
        table.insert(workers,{id=n.id,name=n.name,profession=n.profession,
            state=n.state,carryWeight=Inventory.weight(n.inventory),
            carrying=table.clone(n.inventory.items)})
    end
    return {buildings=buildings,workers=workers,stats=table.clone(state.stats)}
end
return Engine
