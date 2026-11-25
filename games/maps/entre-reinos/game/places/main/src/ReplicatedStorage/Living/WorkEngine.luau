--!strict
-- T1-R2 pure, deterministic NPC work FSM. No NPC gains materials from a job:
-- sources are depleted, bags have real mass, delivery takes from those bags.
local Items=require("./ItemDefs")
local Production=require("./Production")
local Needs=require("./VillageNeeds")
local Market=require("./Market")
local Structures=require("./StructureDefs")
local Professions=require("./ProfessionDefs")
local Inventory=require("./Inventory")
local World=require("../WorldProfile")
local Regions=require("../RegionalProfile")
local Routes=require("../RegionalCrossings")
local Engine={}
Engine.learn=Needs.learn
Engine.activityRate=Needs.rate
local contexts=setmetatable({} :: {[any]: any}, {__mode="k"})
local DECK_HALF_WIDTH=3.2

-- Runtime references stay outside the persisted population.
function Engine.bindRegion(state: any, graph: Routes.Graph, origin: number,
        allBridgeRecords: () -> {any}, readyAt: ((number) -> boolean)?)
    contexts[state]={graph=graph,origin=origin,bridges=allBridgeRecords,readyAt=readyAt}
end

function Engine.crossings(state: any): Routes.Graph?
    local context=contexts[state]
    return if context then context.graph else nil
end

local function sample(state: any, x: number, z: number)
    return if contexts[state] then Regions.sample(state.seed,x,z) else World.sample(state.seed,x,z)
end

local function bridgeAt(state: any, id: string): any
    for _,b in ipairs(contexts[state].bridges()) do
        if b.crossingId==id then return b end
    end
    return nil
end

local function passable(state: any,crossing: Routes.Crossing,class: string): string?
    local building=bridgeAt(state,crossing.id)
    return Routes.passage(crossing,class,building and {
        tier=Structures.get(building.typeId).tier,state=building.state,health=building.health,load=0,
    })
end

function Engine.canReach(state: any, from: number, to: number, class: string): boolean
    local context=contexts[state]
    if not context then return true end
    local a,b=math.min(from,to),math.max(from,to)
    for _,crossing in ipairs(context.graph.crossings) do
        if a<crossing.east.x-1 and b>crossing.west.x+1 and not passable(state,crossing,class) then
            return false
        end
    end
    return true
end

local function bridgeWorkBank(state: any,b: any,fromX: number): number?
    local context=contexts[state]
    if not context or not b.crossingId then return nil end
    for _,crossing in ipairs(context.graph.crossings) do
        if crossing.id==b.crossingId then
            return if fromX<=b.x then crossing.west.x-2 else crossing.east.x+2
        end
    end
    return nil
end

local function builderTarget(state: any, npc: any, b: any): (number,number)
    local bank=bridgeWorkBank(state,b,npc.x)
    if bank then return bank,0 end
    return b.x,-4.4
end

function Engine.recoveryLocation(state: any,b: any): (number,number?)
    local context=contexts[state]
    local bank=if context then bridgeWorkBank(state,b,context.origin) else nil
    if bank then return bank,0 end
    return b.x,nil
end

function Engine.deckAt(state: any, x: number, z: number, class: string): (number?, any)
    local context=contexts[state]
    if not context or math.abs(z)>DECK_HALF_WIDTH then return nil,nil end
    for _,crossing in ipairs(context.graph.crossings) do
        if x<crossing.west.x-0.35 or x>crossing.east.x+0.35 then continue end
        if passable(state,crossing,class)~="bridge" then return nil,nil end
        local t=math.clamp((x-crossing.west.x)/crossing.span,0,1)
        return crossing.deckWestY+(crossing.deckEastY-crossing.deckWestY)*t,crossing
    end
    return nil,nil
end

function Engine.deckHasSpace(state: any,crossing: any,class: string,entrant: any?): boolean
    local b=bridgeAt(state,crossing.id)
    if not b then return false end
    local weight=if class=="mount" then 3 elseif class=="carrier" then 2 else 1
    local limit=if Structures.get(b.typeId).tier=="light" then 2 else 6
    for _,other in ipairs(state.npcs) do
        if other~=entrant and other.health>0 and other.x>crossing.west.x
            and other.x<crossing.east.x and math.abs(other.z or 0)<=DECK_HALF_WIDTH then
            weight+=if Inventory.weight(other.inventory)>0 then 2 else 1
        end
    end
    return weight<=limit
end

-- Stop at the supported entrance before the bank slopes into a closed
-- crossing. A mount parked on the lower bank by an older save can turn back.
function Engine.mountStep(state: any, old: {x: number,y: number,z: number}, targetX: number): (number?, number?)
    local context=contexts[state]
    if not context then return nil,nil end
    for _,crossing in ipairs(context.graph.crossings) do
        local west,east=crossing.west.x,crossing.east.x
        if math.min(old.x,targetX)>=east or math.max(old.x,targetX)<=west
            or passable(state,crossing,"mount") then continue end
        if old.x<=west and targetX>west then
            targetX=west
        elseif old.x>=east and targetX<east then
            targetX=east
        elseif old.x>west and old.x<east then
            local middle=(west+east)/2
            if (old.x<middle and targetX>old.x) or (old.x>=middle and targetX<old.x) then
                return nil,nil
            end
        end
    end

    local previousDeck=Engine.deckAt(state,old.x,0,"mount")
    local ridingDeck=previousDeck~=nil and math.abs(previousDeck-old.y)<0.8
    for _=1,4 do
        local ground=Regions.sample(state.seed,targetX,0)
        local depth=(ground.waterSurface or ground.height)-ground.height
        local deck,crossing=Engine.deckAt(state,targetX,0,"mount")
        -- The tabuleiro is above a lower shore surface. A saved rider under
        -- it can regain the ramp without snapping vertically onto the deck.
        if deck and not ridingDeck and deck-old.y>2.8 then deck=nil end
        if deck and crossing and not ridingDeck and not Engine.deckHasSpace(state,crossing,"mount") then
            return nil,nil
        end
        local surface=deck or ground.height
        if (depth<=2 or deck~=nil) and math.abs(surface-old.y)<=2.8 then
            return targetX,surface
        end
        -- Slow across steeper continuous ground with a shorter step. A
        -- fixed speed step could otherwise repeatedly stall at the old rim.
        targetX=(old.x+targetX)*0.5
    end
    return nil,nil
end

function Engine.bridgePlan(state: any,x: number): (Routes.Crossing?,string?)
    local graph=Engine.crossings(state)
    if not graph then return nil,"invalid_structure" end
    return Routes.bridgePlan(graph,x)
end
local NEAR=1.6

local function findBuilding(state: any, id: any): any
    for _,b in ipairs(state.buildings) do
        if b.id==id then return b end
    end
    return nil
end
Engine.findBuilding=findBuilding
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
    Production.release(state,npc)
    npc.jobId=nil
    npc.siteId=nil
    npc.storageId=nil
    npc.carryItem=nil
    npc.reserved=0
    npc.actionProgress=nil
    npc.state="idle"
    npc.steerSide=nil
end
function Engine.releaseWorker(state: any,npc: any)
    clearJob(npc,state)
end

function Engine.changeProfession(state: any,npc: any,role: string): boolean
    local def=Professions.get(role)
    if not state.production or not def or npc.health<=0 or npc.profession==role then return false end
    clearJob(npc,state)
    npc.profession=role
    npc.inventory.maxMass=math.max(def.carryCapacity,Inventory.weight(npc.inventory))
    return true
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

local function availableSource(state: any, item: string, x: number, target: number?): any
    local best=nil
    local bestDist=math.huge
    for _,site in ipairs(state.sites) do
        if site.item==item and Engine.sourceAvailable(state,site)>0
            and Engine.canReach(state,x,site.x,"worker")
            and (target==nil or Engine.canReach(state,site.x,target,"carrier")) then
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

local STOCK_TARGET: {[string]:number}={wood=24,stone=15,iron=10,food=20}
local WORK_ITEMS={"wood","stone","iron","food","plank","metal","grain","meat","leather","axe","pick","hammer","hoe","bow","spear"}
local function gatherTool(item: string): string
    return if item=="wood" then "axe" elseif item=="food" then "hoe" else "pick"
end
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

Engine.storageFree=storageSpace

local function assignStorage(npc: any,state: any): boolean
    -- Low priority after construction. Stocking is not a free resource mint:
    -- resources first enter a real worker bag, then a finite galpão inventory.
    local best=nil
    local item=nil
    local source=nil
    local distance=math.huge
    for _,b in ipairs(state.buildings) do
        if Engine.usableStorage(b) then
            for _,id in ipairs(WORK_ITEMS) do
                if storageSpace(state,b,id)<=0 then continue end
                local carried=Inventory.count(npc.inventory,id)
                local s=if carried==0 and freeUnits(npc.inventory,id)>0
                    then availableSource(state,id,npc.x,b.x) else nil
                local ordered=s and s.marked==true and id=="wood"
                if (carried>0 and Engine.canReach(state,npc.x,b.x,"carrier"))
                    or (s and (ordered or Inventory.count(b.stored,id)<(STOCK_TARGET[id] or 0))) then
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
            else (STOCK_TARGET[item] or 0)-Inventory.count(best.stored,item)
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
        local target=builderTarget(state,npc,b)
        if b.state~="complete" and ready(b) and Engine.canReach(state,npc.x,target,"worker") then
            local distance=math.abs(npc.x-target)
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
            local target=builderTarget(state,npc,b)
            local district=Engine.districtAt(state,b.x)
            for _,item in ipairs(WORK_ITEMS) do
                local missing=needed(b,item)
                if missing<=0 or not def.cost[item] then continue end
                if Engine.canReach(state,npc.x,target,"carrier") then
                    consider(b,item,math.min(missing,Inventory.count(npc.inventory,item)),
                        500-math.abs(npc.x-target),nil,nil)
                end
                local limit=math.min(missing,freeUnits(npc.inventory,item),
                    Professions.gatherYield(npc.profession,item))
                if limit<=0 then continue end
                for _,depot in ipairs(state.buildings) do
                    local free=Engine.stockAvailable(state,depot,item)
                    if free>0 and Engine.canReach(state,npc.x,depot.x,"worker")
                        and Engine.canReach(state,depot.x,target,"carrier") then
                        local localDepot=district~=nil and Engine.districtAt(state,depot.x)==district
                        consider(b,item,math.min(limit,free),
                            325-(math.abs(npc.x-depot.x)+math.abs(depot.x-b.x))*0.35
                                +(if localDepot then 8 else 0),nil,depot)
                    end
                end
                local site=availableSource(state,item,npc.x,target)
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

local function freeGround(state: any,npc: any,x: number,z: number): boolean
    if math.abs(z)>20 then return false end
    local context=contexts[state]
    if context and context.readyAt and not context.readyAt(x) then return false end
    local class=if npc.tradeLoad or Inventory.weight(npc.inventory)>0 then "carrier" else "worker"
    local current=sample(state,npc.x,npc.z or 0)
    local nextGround=sample(state,x,z)
    local deck,crossing=Engine.deckAt(state,x,z,class)
    local fromDeck=Engine.deckAt(state,npc.x,npc.z or 0,class)
    local shallow=context and nextGround.waterSurface
        and nextGround.waterSurface-nextGround.height<=2
    if nextGround.wet and not shallow and not deck then return false end
    if math.abs((deck or nextGround.height)-(fromDeck or current.height))>(if deck or fromDeck then 2.4 else 1.4) then return false end
    if crossing and not fromDeck and not Engine.deckHasSpace(state,crossing,class,npc) then return false end
    for _,site in ipairs(state.sites) do
        if site.item=="wood" and site.remaining>0 and not site.salvage then
            local after=(x-site.x)^2+(z-(site.z or -6))^2
            if after<1.26^2 and after<(npc.x-site.x)^2+((npc.z or 0)-(site.z or -6))^2 then return false end
        end
    end
    for _,b in ipairs(state.buildings) do
        if b.health<=0 or b.ruined or b.crossingId or (b.typeId=="gate" and b.open) then continue end
        local width=Structures.get(b.typeId).footprint/2+0.45
        local depth=if b.typeId=="gate" then 0 else Structures.DEPTH_Z
        if math.abs(x-b.x)<width and math.abs(z-depth)<4.65 then
            -- A legacy resident may have been saved inside a structure.
            local wasInside=math.abs(npc.x-b.x)<width and math.abs((npc.z or 0)-depth)<4.65
            if not wasInside or math.abs(z-depth)<=math.abs((npc.z or 0)-depth) then return false end
        end
    end
    return true
end

local steering={0,0.61,-0.61,1.15,-1.15,1.84,-1.84}
function Engine.walkResident(state: any,npc: any,destX: number,dt: number,destZ: number?,speed: number?): boolean
    local z=npc.z or 0
    local targetZ=destZ or z
    local finalX,finalZ=destX,targetZ
    local context=contexts[state]
    if context then
        local class=if npc.tradeLoad or Inventory.weight(npc.inventory)>0 then "carrier" else "worker"
        local entry=npc.bridgeEntry
        if entry then
            local deck=Engine.deckAt(state,npc.x,z,class)
            if not deck then
                npc.x,npc.z=entry.x,entry.z
                npc.bridgeEntry=nil
                clearJob(npc,state)
                return false
            end
        end
        if not Engine.canReach(state,npc.x,destX,class) then
            -- Keep a loaded worker and its materials on the current bank.
            -- Release the claim only if no route returns within the wait window.
            npc.routeBlocked=(npc.routeBlocked or 0)+dt
            if npc.routeBlocked>=14 then clearJob(npc,state); npc.routeBlocked=nil end
            return false
        end
        npc.routeBlocked=nil
        local east=destX>=npc.x
        for i=1,#context.graph.crossings do
            local crossing=context.graph.crossings[if east then i else #context.graph.crossings-i+1]
            local enter,exit=if east then crossing.west.x else crossing.east.x,
                if east then crossing.east.x else crossing.west.x
            local dir=if east then 1 else -1
            if (destX-enter)*dir>1 and (exit-npc.x)*dir>0 then
                destX=if (enter-npc.x)*dir>0.8 and math.abs(z)>0.7 then enter-dir*1.2 else exit+dir*1.4
                targetZ=0
                break
            end
        end
    end
    npc.targetX=destX
    npc.targetZ=targetZ
    local dx,dz=destX-npc.x,targetZ-z
    local distance=math.sqrt(dx*dx+dz*dz)
    if distance<=(if destX~=finalX or targetZ~=finalZ then 0.48 else NEAR) then
        return (finalX-npc.x)^2+(finalZ-z)^2<=NEAR^2
    end
    local travel=math.min(distance,(speed or Professions.get(npc.profession).moveSpeed)*dt)
    local angle=math.atan2(dz,dx)
    local bestX,bestZ=npc.x,z
    local bestScore=-math.huge
    for _,offset in ipairs(steering) do
        local x=npc.x+math.cos(angle+offset)*travel
        local nextZ=z+math.sin(angle+offset)*travel
        if not freeGround(state,npc,x,nextZ) then continue end
        local score=math.cos(offset)
        for _,other in ipairs(state.npcs) do
            if other==npc or other.health<=0 then continue end
            local before=(npc.x-other.x)^2+(z-(other.z or 0))^2
            local after=(x-other.x)^2+(nextZ-(other.z or 0))^2
            if after<2.4 and after<before then score-=3*(2.4-after) end
        end
        -- Keep the chosen turning side while skirting corners.
        if offset*(npc.steerSide or 0)>0 then score+=0.18 end
        if score>bestScore then
            bestScore,bestX,bestZ=score,x,nextZ
        end
        if score>=1 then break end
    end
    if bestScore==-math.huge then return false end
    npc.motionX=(bestX-npc.x)/dt
    npc.motionZ=(bestZ-z)/dt
    local turn=dx*(bestZ-z)-dz*(bestX-npc.x)
    npc.steerSide=if math.abs(turn)<0.01 then nil elseif turn>0 then 1 else -1
    if context then
        local class=if Inventory.weight(npc.inventory)>0 then "carrier" else "worker"
        local deck=Engine.deckAt(state,bestX,bestZ,class)
        if deck and not npc.bridgeEntry then
            npc.bridgeEntry={x=npc.x,z=z}
        elseif not deck then
            npc.bridgeEntry=nil
        end
    end
    npc.x,npc.z=bestX,bestZ
    npc.fatigue=math.min(100,npc.fatigue+dt*0.03)
    return (finalX-npc.x)^2+(finalZ-npc.z)^2<=NEAR^2
end

local function wander(npc: any,state: any,dt: number)
    -- No job available: roam independently inside the central village's
    -- open courtyard (inside west/east walls). This is saved NPC state,
    -- not a modulo-ID lane drawn by the renderer.
    if npc.wanderPause and state.elapsed<npc.wanderPause then
        npc.activity="idle"
        return
    end
    if npc.wanderX==nil or npc.wanderZ==nil then
        local epoch=math.floor((state.elapsed+npc.id*1.6)/5)
        for attempt=0,11 do
            local targetX=((state.seed%997)*17+npc.id*53+epoch*71+attempt*19)%53-26
                +(if contexts[state] then contexts[state].origin else 0)
            local targetZ=1+(((state.seed%89)*13+npc.id*29+epoch*31+attempt*7)%12)
            local free=not sample(state,targetX,targetZ).wet
            if free then
                for _,other in ipairs(state.npcs) do
                    if other~=npc and other.health>0
                        and math.sqrt((other.x-targetX)^2+
                            ((other.z or 0)-targetZ)^2)<3.4 then
                        free=false
                        break
                    end
                end
            end
            if free then
                npc.wanderX=targetX
                npc.wanderZ=targetZ
                break
            end
        end
        if npc.wanderX==nil then
            npc.wanderPause=state.elapsed+2
            return
        end
    end
    npc.activity="wander"
    if Engine.walkResident(state,npc,npc.wanderX,dt,npc.wanderZ) then
        npc.wanderX=nil
        npc.wanderZ=nil
        npc.wanderPause=state.elapsed+1.4+(npc.id%3)*0.6
    end
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
    if type(x)~="number" or x~=x or math.abs(x)+def.footprint/2>(if contexts[state] then Regions.PLAY_EDGE else World.PLAY_EDGE) then
        return false,"outside_region"
    end
    local territory=contexts[state]
    if territory and (Regions.regionAt(x)==2)~=(territory.origin~=0) then
        return false,"outside_kingdom"
    end
    if def.kind=="crossing" then
        local crossing,reason=Engine.bridgePlan(state,x)
        if not crossing then return false,reason end
        local existing=bridgeAt(state,crossing.id)
        if existing and (def.tier~="reinforced" or existing.typeId~="bridge_light"
            or existing.state~="complete" or findBuilding(state,existing.id)~=existing) then
            return false,"overlapping_footprint"
        end
        return #state.buildings<120 or existing~=nil, "building_limit"
    end
    if #state.buildings>=120 then return false,"building_limit" end
    local low=math.huge
    local high=-math.huge
    for _,z in ipairs({World.LANE_Z,Structures.DEPTH_Z-3.5,Structures.DEPTH_Z+3.5}) do
        for step=-2,2 do
            local sample=sample(state,x+step*def.footprint/4,z)
            if sample.wet or sample.shore then return false,"invalid_footprint_or_slope" end
            low=math.min(low,sample.height)
            high=math.max(high,sample.height)
        end
    end
    if high-low>def.maxSlope then return false,"invalid_footprint_or_slope" end
    local context=contexts[state]
    if context then
        if not Engine.canReach(state,context.origin,x,"carrier") then return false,"no_worker_route" end
    else
        local direction=if x<0 then -1 else 1
        for distance=4,math.abs(x),4 do
            if World.sample(state.seed,distance*direction,World.LANE_Z).wet then
                return false,"no_worker_route"
            end
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
    local crossing=if def.kind=="crossing" then Engine.bridgePlan(state,x) else nil
    if crossing then
        local existing=bridgeAt(state,crossing.id)
        x=(crossing.west.x+crossing.east.x)*0.5
        groundY=(crossing.deckWestY+crossing.deckEastY)*0.5
        if existing then
            Engine.releaseBuildingJobs(state,existing.id)
            existing.typeId=typeId
            existing.health=def.health
            existing.state="blueprint"
            existing.progress=0
            existing.upgrading=true
            return true,existing
        end
    end
    local center=sample(state,x,if typeId=="gate" then 0 else Structures.DEPTH_Z)
    local b={id=state.nextBuildingId,typeId=typeId,x=x,y=groundY or center.height,
        state="blueprint",progress=0,health=def.health,
        delivered={},claimed={},stored=Inventory.new(if def.storageMass>0 then def.storageMass else 1)}
    if crossing then b.crossingId=crossing.id end
    state.nextBuildingId+=1
    table.insert(state.buildings,b)
    table.insert(state.events,{kind="placed",buildingId=b.id,time=state.elapsed})
    return true,b
end

function Engine.canCancel(b: any): boolean
    return b~=nil and (b.state=="blueprint" or b.state=="building") and b.ruined~=true and not b.upgrading
end

function Engine.cancel(state: any, id: number): (boolean, string?)
    for i,b in ipairs(state.buildings) do
        if b.id==id then
            if not Engine.canCancel(b) then return false,"building_cannot_cancel" end
            -- Staging policy: delivered material remains in a physical
            -- recovery pile at the site. No credit to a second inventory.
            local returns={}
            local recoveryX,recoveryZ=Engine.recoveryLocation(state,b)
            for item,amount in pairs(b.delivered) do
                if amount>0 then
                    table.insert(returns,{id="cancelled_"..tostring(id).."_"..item,
                        item=item,x=recoveryX,z=recoveryZ,remaining=amount,salvage=true})
                end
            end
            if #state.sites+#returns>256 then return false,"no_recovery_space" end
            Engine.releaseBuildingJobs(state,id)
            Production.removeStation(state,b.id)
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

function Engine.initializeVillage(state: any, origin: number?): boolean
    if #state.buildings>0 or state.nextBuildingId~=1 then return false end
    local plan={
        {typeId="castle",x=0},
        {typeId="stockpile",x=-17}, {typeId="stockpile",x=17},
        {typeId="wall",x=-33}, {typeId="wall",x=33},
        {typeId="shelter",x=-55},
    }
    for _,entry in ipairs(plan) do
        local id=entry.typeId
        local placed,b=Engine.place(state,id,(origin or 0)+entry.x)
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
    if state.production then
        local context=contexts[state]
        Needs.seedLandscape(state,if context then context.origin else 0)
        Needs.stepLand(state,dt)
        Market.ensure(state)
        Market.payroll(state)
    end
    if state.production and math.floor(state.elapsed/4)~=math.floor((state.elapsed-dt)/4) then
        for _,depot in ipairs(state.buildings) do
            if not Engine.usableStorage(depot) or Inventory.count(depot.stored,"food")>=8
                or Engine.stockAvailable(state,depot,"wood")<1 then continue end
            local recipe=if Engine.stockAvailable(state,depot,"grain")>=3 then "bread"
                elseif Engine.stockAvailable(state,depot,"meat")>=2 then "cook" else nil
            if recipe then
                local queued=false
                for _,order in ipairs(state.production.orders) do
                    if order.recipe=="bread" or order.recipe=="cook" then queued=true;break end
                end
                if not queued then
                    for _,station in ipairs(state.buildings) do
                        if station.typeId=="workshop" and station.state=="complete"
                            and Engine.canReach(state,depot.x,station.x,"carrier") then
                            Production.enqueue(state,recipe,station.x)
                            break
                        end
                    end
                end
                break
            end
        end
    end
    for _,npc in ipairs(state.npcs) do
        npc.motionX=0
        npc.motionZ=0
        npc.activity=nil
        if npc.health<=0 then Production.release(state,npc); continue end
        if state.production then
            npc.inventory.maxMass=math.max(Professions.get(npc.profession).carryCapacity,Inventory.weight(npc.inventory))
        end
        npc.hunger=math.min(100,npc.hunger+dt*0.045)
        -- During a real nearby raid, civilians pause their tasks without
        -- canceling reserved materials or losing work progress. R3Engine
        -- determines danger and defensive/escape movement after this tick.
        if npc.underAttack or npc.state=="freight" then continue end
        if Needs.care(state,npc,dt,Engine) then continue end
        if not state.production and npc.hunger>70 and Inventory.count(npc.inventory,"food")>0 then
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
            if Production.step(state,npc,dt,Engine) then continue end
            if Needs.work(state,npc,dt,Engine) then continue end
            if npc.state=="idle" then
                assign(npc,state)
                if npc.state=="idle" then wander(npc,state,dt) end
            end
            local b=findBuilding(state,npc.jobId)
            if npc.state=="store_gather" then
                local storage=storeBuilding(state,npc.storageId)
                local source=findSite(state,npc.siteId)
                local item=npc.carryItem
                if not storage or not source or not item
                    or source.item~=item then
                    clearJob(npc,state)
                elseif Engine.walkResident(state,npc,source.x,dt,source.z or (if source.item=="wood" then -6 else -4)) and working(npc,dt*Production.toolRate(npc,gatherTool(item))*Needs.rate(npc,"gather"),"collect") then
                    local n=math.min(npc.reserved,Engine.sourceAvailable(state,source,npc),
                        storageSpace(state,storage,item,npc))
                    if n>0 and Inventory.add(npc.inventory,item,n) then
                        Production.wear(npc,gatherTool(item))
                        source.remaining-=n
                        state.stats.gathered+=n
                        Needs.learn(state,npc,"gather",2)
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
                elseif Engine.walkResident(state,npc,storage.x,dt,-4.4) then
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
                local targetX,targetZ=builderTarget(state,npc,b)
                if npc.state=="gather" and item then
                    local site=findSite(state,npc.siteId)
                    local storage=storeBuilding(state,npc.storageId)
                    if not storage and (not site or site.item~=item) then
                        clearJob(npc,state)
                    elseif Engine.walkResident(state,npc,if storage then storage.x else site.x,dt,
                        if storage then -5 else site.z or (if site.item=="wood" then -6 else -4))
                        and working(npc,dt*(if storage then 1 else Production.toolRate(npc,gatherTool(item))*Needs.rate(npc,"gather")),
                            if storage then "load" else "collect") then
                        local available=if storage then Engine.stockAvailable(state,storage,item,npc)
                            else Engine.sourceAvailable(state,site,npc)
                        local n=math.min(npc.reserved,available)
                        local pickedUp=n>0 and (if storage then
                            Inventory.transfer(storage.stored,npc.inventory,item,n)
                            else Inventory.add(npc.inventory,item,n))
                        if pickedUp then
                            if not storage then
                                Production.wear(npc,gatherTool(item))
                                site.remaining-=n
                                state.stats.gathered+=n
                                Needs.learn(state,npc,"gather",2)
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
                    if Engine.walkResident(state,npc,targetX,dt,targetZ) then
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
                    elseif Engine.walkResident(state,npc,targetX,dt,targetZ) then
                        npc.activity="build"
                        local def=Structures.get(b.typeId)
                        local rate=Professions.buildRate(npc.profession)*Production.toolRate(npc,"hammer")*Needs.rate(npc,"build")
                        local step=dt*rate
                        if b.state=="damaged" then
                            b.health=math.min(def.health,b.health+step*2)
                            if b.health>=def.health then
                                b.state="complete"
                                Needs.learn(state,npc,"build",6)
                                Production.wear(npc,"hammer")
                                state.stats.repaired+=1
                                table.insert(state.events,{kind="repaired",buildingId=b.id,time=state.elapsed})
                                clearJob(npc,state)
                            end
                        else
                            b.progress=math.min(def.buildSeconds,b.progress+step)
                            b.state="building"
                            if b.progress>=def.buildSeconds then
                                b.state="complete"
                                b.upgrading=nil
                                -- A ruin becomes physically usable only after
                                -- a completely new material-backed rebuild.
                                if b.ruined==true then
                                    b.ruined=false
                                    b.health=def.health
                                end
                                Production.wear(npc,"hammer")
                                Needs.learn(state,npc,"build",10)
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
            health=b.health,plot=b.plot and table.clone(b.plot),delivered=table.clone(b.delivered),
            stored=if b.stored then table.clone(b.stored.items) else {}})
    end
    local workers={}
    for _,n in ipairs(state.npcs) do
        table.insert(workers,{id=n.id,name=n.name,profession=n.profession,
            state=n.activity or n.state,defense=n.defense or "none",
            district=Engine.districtAt(state,n.x),health=n.health,arrows=n.arrows or 0,hunger=n.hunger,fatigue=n.fatigue,homeId=n.homeId,
            level=math.max(Needs.level(n,"craft"),Needs.level(n,"build"),Needs.level(n,"gather"),
                Needs.level(n,"hunt"),Needs.level(n,"farm")),
            carryWeight=Inventory.weight(n.inventory),tool=n.tool and table.clone(n.tool),
            carrying=table.clone(n.inventory.items)})
    end
    local production=nil
    if state.production then
        local orders={}
        for _,order in ipairs(state.production.orders) do table.insert(orders,table.clone(order)) end
        production={orders=orders,completed=state.production.completed}
    end
    return {buildings=buildings,workers=workers,districts=districts,stats=table.clone(state.stats),production=production,market=Market.summary(state,Engine),
        resources={sources=sources,carried=carried,reserved=reserved,
            committed=committed,stored=deposited,isolated=isolated,markedTrees=markedTrees}}
end
return Engine
