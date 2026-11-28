--!strict
-- T1-R3 foundation. Deterministic, server-owned and persistence-safe.
-- Gameplay rules here contain no Instance, Remote or client trust.
local World=require("../WorldProfile")
local Structures=require("./StructureDefs")
local Inventory=require("./Inventory")
local Items=require("./ItemDefs")
local Work=require("./WorkEngine")
local Story=require("./Campaign")
local R3={}
R3.storyActors=Story.actors
R3.VERSION=1
R3.DAY=240
R3.NIGHT_START=160
R3.NIGHT_END=235
R3.MAX_ENEMIES=12
R3.MAX_DROPS=48
R3.ARROW_RECIPE=table.freeze({wood=2,output=6,capacity=30})
R3.TRADE_PRICES=table.freeze({wood=1,stone=2,iron=3,food=1})

local function finite(value: any): boolean
    return type(value)=="number" and value==value
        and value~=math.huge and value~= -math.huge
end

function R3.valid(d: any): boolean
    if type(d)~="table" or d.version~=R3.VERSION or type(d.enemies)~="table"
        or type(d.drops)~="table" or type(d.ledger)~="table"
        or type(d.stats)~="table" or type(d.prologue)~="table"
        or not finite(d.wallet) or d.wallet<0 or d.wallet%1~=0
        or not finite(d.treasury) or d.treasury<0 or d.treasury%1~=0
        or not finite(d.arrows) or d.arrows<0 or d.arrows%1~=0
        or not finite(d.nextEnemyId) or not finite(d.nextDropId)
        or not finite(d.lastNight) or type(d.prologue.stage)~="string"
        or #d.enemies>R3.MAX_ENEMIES or #d.drops>R3.MAX_DROPS
        or #d.ledger>80 or not Story.valid(d.prologue) then return false end
    for _,e in ipairs(d.enemies) do
        if type(e)~="table" or not finite(e.x) or not finite(e.hp)
            or (e.side~=-1 and e.side~=1) or not finite(e.attackClock)
            or not finite(e.id) or not finite(e.loot) then return false end
    end
    if d.awaitingRecovery~=nil and type(d.awaitingRecovery)~="boolean" then return false end
    if d.playerBag~=nil and not Inventory.valid(d.playerBag) then
        return false
    end
    for _,drop in ipairs(d.drops) do
        if type(drop)~="table" or not finite(drop.id) or not finite(drop.x) or not finite(drop.value)
            or drop.value<=0 or drop.value%1~=0 or type(drop.claimed)~="boolean" then
            return false
        end
    end
    return true
end

function R3.ensure(state: any, newCampaign: boolean)
    if state.r3~=nil then
        assert(R3.valid(state.r3),"unsupported_r3_schema")
        -- Safe additive upgrade of already persisted R3 worlds, NOT a wipe.
        if state.r3.playerBag==nil then
            state.r3.playerBag=Inventory.new(24)
        end
        return state.r3
    end
    -- Existing R2 saves enter sandbox; a truly fresh campaign gets the
    -- interactive prologue. No previous world is reset or overwritten.
    state.r3={
        version=R3.VERSION, wallet=0, treasury=24, arrows=12,
        playerBag=Inventory.new(24),
        enemies={}, drops={}, ledger={}, nextEnemyId=1,nextDropId=1,
        lastNight= -1, night=0, raidActive=false, raidWarning="",
        prologue=if newCampaign then Story.new() else {stage="sandbox",time=0},
        stats={killed=0,repelled=0,coinsLost=0,structuresHit=0,shots=0},
    }
    return state.r3
end

local function ledger(d: any,kind: string,value: number,reference: string)
    table.insert(d.ledger,{kind=kind,value=value,reference=reference})
    while #d.ledger>80 do table.remove(d.ledger,1) end
end

function R3.payTravel(state: any,cost: number,asset: string): boolean
    local d=state.r3
    if not d or not finite(cost) or cost%1~=0 or cost<1 or d.wallet<cost then return false end
    d.wallet-=cost
    ledger(d,"travel_purchase",-cost,asset)
    return true
end

local function makeDrop(d: any,x: number,value: number,reason: string): any
    -- Reap claimed items, while never recycling their unique IDs. Double
    -- pickup remains impossible even after old tombstones are pruned.
    if #d.drops>=R3.MAX_DROPS then
        for i=#d.drops,1,-1 do
            if d.drops[i].claimed then table.remove(d.drops,i) end
        end
    end
    if value<=0 or #d.drops>=R3.MAX_DROPS then return nil end
    local drop={id=d.nextDropId,x=x,value=value,claimed=false,reason=reason}
    d.nextDropId+=1
    table.insert(d.drops,drop)
    return drop
end

function R3.drop(state: any,x: number,value: number): (boolean, any)
    local d=state.r3
    if not finite(x) or not finite(value) or value%1~=0 or value<1 or value>d.wallet
        or math.abs(x)>World.PLAY_EDGE then return false,"invalid_coin_drop" end
    if #d.drops>=R3.MAX_DROPS then
        for i=#d.drops,1,-1 do
            if d.drops[i].claimed then table.remove(d.drops,i) end
        end
    end
    if #d.drops>=R3.MAX_DROPS then return false,"too_many_drops" end
    d.wallet-=value
    local drop=makeDrop(d,x,value,"player_drop")
    ledger(d,"drop",-value,tostring(drop.id))
    return true,drop.id
end

-- The player's bag is independent of the village's standing timber:
-- physical, finite extraction -> a real carried item -> a real recipe.
function R3.takeWood(state: any,x: number,y: number,siteId: string?): (boolean, any)
    if not finite(x) or not finite(y) then return false,"invalid_position" end
    local d=R3.ensure(state,false)
    if Inventory.weight(d.playerBag)+2*Items.get("wood").mass
        >d.playerBag.maxMass then
        return false,"player_bag_full"
    end
    local best=nil
    local bestDistance=math.huge
    for _,source in ipairs(state.sites) do
        if source.item=="wood" and (not siteId or source.id==siteId)
            and Work.sourceAvailable(state,source)>=2 then
            local distance=math.abs(x-source.x)
            local ground=World.sample(state.seed,source.x,0).height
            if distance<=11 and math.abs(y-(ground+3))<=11
                and distance<bestDistance then
                best=source
                bestDistance=distance
            end
        end
    end
    if best then
        if not Inventory.add(d.playerBag,"wood",2) then
            return false,"player_bag_full"
        end
        best.remaining-=2
        ledger(d,"wood_from_tree",0,tostring(best.id))
        return true,Inventory.count(d.playerBag,"wood")
    end
    if siteId then return false,"wood_source_too_far" end
    for _,b in ipairs(state.buildings) do
        if Work.stockAvailable(state,b,"wood")>=2
            and math.abs(x-b.x)<=13 and math.abs(y-(b.y+3))<=12 then
            if not Inventory.transfer(b.stored,d.playerBag,"wood",2) then
                return false,"player_bag_full"
            end
            ledger(d,"wood_from_galpao",0,tostring(b.id))
            return true,Inventory.count(d.playerBag,"wood")
        end
    end
    return false,"wood_source_too_far"
end

local function depotInReach(b: any, x: number, y: number?, radius: number): boolean
    return math.abs(b.x-x)<=radius and (y==nil or math.abs(y-(b.y+3))<=12)
end

function R3.arrowMaterial(state: any,x: number,y: number?): (string?, any)
    local cost=R3.ARROW_RECIPE.wood
    if Inventory.count(state.r3.playerBag,"wood")>=cost then return "bag",state.r3.playerBag end
    for _,b in ipairs(state.buildings) do
        if depotInReach(b,x,y,12) and Work.stockAvailable(state,b,"wood")>=cost then
            return "warehouse",b
        end
    end
    for _,site in ipairs(state.sites) do
        if site.item=="wood" and math.abs(site.x-x)<=9
            and Work.sourceAvailable(state,site)>=cost
            and (y==nil or math.abs(y-(World.sample(state.seed,site.x,0).height+3))<=11) then
            return "source",site
        end
    end
    return nil,nil
end

function R3.craftArrows(state: any,x: number,y: number?): (boolean, any)
    if not finite(x) or (y~=nil and not finite(y)) then return false,"invalid_position" end
    local d=R3.ensure(state,false)
    local recipe=R3.ARROW_RECIPE
    if d.arrows+recipe.output>recipe.capacity then return false,"ammo_capacity" end
    local kind,source=R3.arrowMaterial(state,x,y)
    local reference: string
    if kind=="bag" then
        if not Inventory.take(source,"wood",recipe.wood) then return false,"wood_stock_required" end
        reference="player_bag"
    elseif kind=="warehouse" then
        if not Inventory.take(source.stored,"wood",recipe.wood) then return false,"wood_stock_required" end
        reference="galpao:"..tostring(source.id)
    elseif kind=="source" then
        source.remaining-=recipe.wood
        reference=tostring(source.id)
    else
        return false,"wood_stock_required"
    end
    d.arrows+=recipe.output
    ledger(d,"arrow_crafting",0,reference)
    return true,d.arrows
end

local function tradeStock(state: any,item: string,x: number,y: number?): any
    for _,b in ipairs(state.buildings) do
        if depotInReach(b,x,y,24) and Work.stockAvailable(state,b,item)>=1 then return b end
    end
    return nil
end

function R3.marketNear(state: any,x: number,y: number?): boolean
    for _,b in ipairs(state.buildings) do
        if b.typeId=="castle" then
            return b.health>0 and not b.ruined and depotInReach(b,x,y,24)
        end
    end
    -- Saves anteriores à vila inicial mantêm o ponto de comércio no centro.
    return math.abs(x)<=24 and (y==nil or math.abs(y-(World.sample(state.seed,0,0).height+3))<=12)
end

function R3.canSell(state: any,item: string,x: number,y: number?): boolean
    local bag=state.r3.playerBag
    return (bag~=nil and Inventory.count(bag,item)>=1) or tradeStock(state,item,x,y)~=nil
end

function R3.trade(state: any,item: string,x: number,y: number?): (boolean, any)
    if not finite(x) or (y~=nil and not finite(y)) or not R3.marketNear(state,x,y) then
        return false,"too_far_from_market"
    end
    local price=R3.TRADE_PRICES[item]
    if not price then return false,"unknown_trade_item" end
    local d=state.r3
    if d.treasury<price then return false,"treasury_empty" end
    local depot=tradeStock(state,item,x,y)
    local stock=if depot then depot.stored else d.playerBag
    if not stock or not Inventory.take(stock,item,1) then return false,"resource_unavailable" end
    d.treasury-=price
    d.wallet+=price
    local reference=if depot then "galpao:"..tostring(depot.id) else "player_bag"
    ledger(d,"trade_income",price,reference..":"..item)
    return true,price
end

function R3.pickup(state: any,id: any,x: number): (boolean, any)
    if type(id)~="number" or id%1~=0 or not finite(x) then return false,"bad_drop" end
    local d=state.r3
    for _,drop in ipairs(d.drops) do
        if drop.id==id then
            if drop.claimed then return false,"already_claimed" end
            if math.abs(drop.x-x)>6 then return false,"too_far_from_coin" end
            drop.claimed=true
            d.wallet+=drop.value
            ledger(d,"pickup",drop.value,tostring(id))
            return true,drop.value
        end
    end
    return false,"drop_not_found"
end

function R3.spawnWave(state: any,sides: number): boolean
    local d=state.r3
    if #d.enemies>0 or sides<1 or sides>2 then return false end
    local total=math.min(R3.MAX_ENEMIES,sides*2)
    for i=1,total do
        local side=if i%2==1 then -1 else 1
        local x=side*(111-math.floor((i-1)/2)*5)
        table.insert(d.enemies,{id=d.nextEnemyId,x=x,hp=30,side=side,
            loot=0,attackClock=0,typeId="raider"})
        d.nextEnemyId+=1
    end
    d.raidActive=true
    d.raidWarning="Invasores se aproximam pelas fronteiras!"
    return true
end

local function killEnemy(state: any,index: number)
    local d=state.r3
    local e=d.enemies[index]
    if e.loot>0 then
        -- Preserve funds if the physical drop ceiling is saturated.
        if not makeDrop(d,e.x,e.loot,"recovered_loot") then
            d.treasury+=e.loot
            ledger(d,"recovered_to_treasury",e.loot,tostring(e.id))
        end
    end
    table.remove(d.enemies,index)
    d.stats.killed+=1
end

function R3.damageEnemy(state: any,id: number,damage: number): boolean
    if not finite(damage) or damage<=0 then return false end
    for index,e in ipairs(state.r3.enemies) do
        if e.id==id and e.hp>0 then
            e.hp-=damage
            if e.hp<=0 then killEnemy(state,index) end
            return true
        end
    end
    return false
end

function R3.hit(state: any,x: number,y: number,direction: number,
        range: number,damage: number): (boolean, any)
    local d=state.r3
    if not finite(x) or not finite(y) or not finite(direction)
        or not finite(range) or not finite(damage) or range<=0 or damage<=0
        or math.abs(direction)~=1 then return false,"invalid_attack" end
    local nearest=nil
    local shortest=math.huge
    for i,e in ipairs(d.enemies) do
        local delta=e.x-x
        local dist=math.abs(delta)
        local ground=World.sample(state.seed,e.x,0).height
        -- Server validates vertical proximity too; a swimmer below the
        -- riverbed must not slash a monster on an unrelated height layer.
        if delta*direction>= -0.5 and dist<=range and dist<shortest
            and math.abs(y-(ground+3.4))<=8 then
            nearest=i
            shortest=dist
        end
    end
    if not nearest then return false,"no_target" end
    local target=d.enemies[nearest]
    return R3.damageEnemy(state,target.id,damage),target.id
end

function R3.arm(state: any,npcId: any,weapon: string,playerData: any?): (boolean, any)
    local d=playerData or state.r3
    if weapon~="bow" and weapon~="spear" then return false,"invalid_weapon" end
    for _,npc in ipairs(state.npcs) do
        if npc.id==npcId and npc.health>0 then
            if npc.defense==weapon then
                if weapon=="bow" and (npc.arrows or 0)==0 and d.arrows>=6 then
                    d.arrows-=6
                    npc.arrows=6
                    ledger(d,"archer_reload",0,tostring(npcId))
                    return true,npcId
                end
                return false,"already_equipped"
            end
            local required=if state.production then weapon elseif weapon=="bow" then "wood" else "iron"
            local cost=if state.production then 1 elseif weapon=="bow" then 3 else 2
            local stock=nil
            for _,depot in ipairs(state.buildings) do
                if math.abs(npc.x-depot.x)<=24 and Work.stockAvailable(state,depot,required)>=cost then
                    stock=depot.stored
                    break
                end
            end
            if not stock then stock=d.playerBag end
            if state.production and npc.defense and (not Inventory.canAdd(d.playerBag,npc.defense,1)
                or d.arrows+(npc.arrows or 0)>30) then
                return false,"player_bag_full"
            end
            if not stock or not Inventory.take(stock,required,cost) then
                return false,"not_enough_equipment_materials"
            end
            if state.production and npc.defense then
                assert(Inventory.add(d.playerBag,npc.defense,1))
                d.arrows+=npc.arrows or 0
            end
            npc.defense=weapon
            npc.defenseClock=0
            local ammo=if weapon=="bow" then (if state.production then math.min(8,d.arrows) else 8) else 0
            npc.arrows=ammo
            if state.production then d.arrows-=ammo end
            ledger(d,"equipment",0,tostring(npcId)..":"..weapon)
            return true,npcId
        end
    end
    return false,"npc_not_found"
end

local function finishPrologue(state: any)
    local d=state.r3
    if d.prologue.stage=="last_ring" and #d.enemies==0 then
        Story.enter(d.prologue,"coronation")
        if d.prologue.scene then state.elapsed=(math.floor(state.elapsed/R3.DAY)+1)*R3.DAY end
        d.raidActive=false
        d.raidWarning="A cidade sobreviveu. Os moradores aguardam sua decisão."
    end
end

function R3.command(state: any,command: string,x: number?): (boolean, any)
    local d=state.r3
    local stage=d.prologue.stage
    if d.prologue.scene then
        local accepted,reason=Story.command(d.prologue,command,x)
        if not accepted then return false,reason end
        if command=="training" then return true,"escort" end
    end
    if command=="evacuate" and stage=="evacuation" then
        Story.enter(d.prologue,"last_ring")
        R3.spawnWave(state,2)
        if d.prologue.scene then
            for _,e in ipairs(d.enemies) do e.x=e.side*(38+(e.id%2)*4) end
        end
        return true,"last_ring"
    elseif command=="coronation" and stage=="coronation" then
        d.prologue.stage="sandbox"
        local stipend=math.min(8,d.treasury)
        d.treasury-=stipend
        d.wallet+=stipend
        ledger(d,"ducal_treasury",-stipend,"prologue_coronation")
        d.raidWarning="A cidade agora depende de suas decisões."
        return true,stipend
    elseif command=="training" and stage=="guard" then
        -- Scripted infection, NEVER a random newbie-save infection. The
        -- infected duke is a distinct real target, defeated by player hits
        -- before the two-front invasion begins.
        d.prologue.stage="duke_fight"
        table.insert(d.enemies,{id=d.nextEnemyId,x=18,hp=64,side=1,
            loot=0,attackClock=0,typeId="infected_duke"})
        d.nextEnemyId+=1
        d.raidActive=true
        d.raidWarning="O duque foi infectado! Derrote-o e proteja os guardas."
        return true,"duke_fight"
    end
    return false,"action_unavailable"
end

-- An actual lost building requires rebuilding from finite materials.
-- Salvage is a bounded fraction of material PREVIOUSLY consumed there;
-- a persistent flag prevents repeated raids from creating infinite stocks.
-- Keep destroyed stock out of circulation until the recovery split is approved.
-- The same migration isolates remaining stock left in old v15 ruins.
function R3.isolateRuinedStock(b: any)
    if b.typeId~="stockpile" or not b.stored or next(b.stored.items)==nil then return end
    b.ruinedStock=b.ruinedStock or {}
    for item,amount in pairs(b.stored.items) do
        b.ruinedStock[item]=(b.ruinedStock[item] or 0)+amount
    end
    b.stored.items={}
end

local function ruin(state: any,b: any)
    if b.health>0 or b.ruined==true then return end
    local def=Structures.get(b.typeId)
    if not def then return end
    Work.releaseBuildingJobs(state,b.id)
    b.ruined=true
    b.state="ruined"
    R3.isolateRuinedStock(b)
    b.progress=0
    b.ruinCount=(b.ruinCount or 0)+1
    local recoveryX,recoveryZ=Work.recoveryLocation(state,b)
    for item,amount in pairs(b.delivered) do
        local recover=math.min(amount,math.floor((def.cost[item] or 0)*0.2))
        if recover>0 and #state.sites<256 then
            table.insert(state.sites,{id="salvage_"..tostring(b.id).."_"..item.."_"..tostring(b.ruinCount),
                item=item,x=recoveryX,z=recoveryZ,remaining=recover,salvage=true})
        end
    end
    b.delivered={}
    b.claimed={}
    b.health=0
    table.insert(state.events,{kind="ruined",buildingId=b.id,time=state.elapsed})
end

function R3.damageStructure(state: any,b: any,amount: number): boolean
    if not b or not finite(amount) or amount<=0 or b.health<=0
        or (b.state~="complete" and b.state~="damaged") then return false end
    b.health=math.max(0,b.health-amount)
    b.state="damaged"
    ruin(state,b)
    return true
end

local function bridgeAtEnemy(state: any,e: any): (any, number?)
    local graph=Work.crossings(state)
    if not graph then return nil,nil end
    for _,b in ipairs(state.buildings) do
        if not b.crossingId or b.health<=0 or (b.state~="complete" and b.state~="damaged") then continue end
        for _,crossing in ipairs(graph.crossings) do
            if b.crossingId~=crossing.id then continue end
            local x=if e.side==1 then crossing.east.x else crossing.west.x
            if b.x*e.side>0 and (e.x-x)*e.side>=-1 then return b,x end
        end
    end
    return nil,nil
end

local function wallBeforeTown(state: any,e: any): any
    local best=nil
    local nearest=math.huge
    for _,b in ipairs(state.buildings) do
        local def=Structures.get(b.typeId)
        if def and (b.typeId=="wall" or b.typeId=="fence" or (b.typeId=="gate" and not b.open))
            and b.health>0 and b.progress>=def.buildSeconds and b.x*e.side>=0 then
            -- A gate behind the town cannot divert an invader through it.
            local approach=(b.x-e.x)*(-e.side)
            if approach>= -2 and approach<nearest then
                nearest=approach
                best=b
            end
        end
    end
    return best
end

local function raiderGoal(state: any,e: any): any
    local selected=nil
    local closest=math.huge
    for _,b in ipairs(state.buildings) do
        local ahead=(b.x-e.x)*(-e.side)
        if math.abs(b.x)<=32 and ahead>=-2 and ahead<closest and b.health>0 and not b.ruined
            and (b.state=="complete" or b.state=="damaged") then
            selected=b
            closest=ahead
        end
    end
    return selected
end

function R3.storyAction(state: any,x: number): string?
    local p=state.r3.prologue
    local phase=p.stage
    if phase=="guard" then
        return if not p.scene or math.abs(x-p.dukeX)<=8 then "training" else nil
    end
    if not p.scene or math.abs(x)<=9 then
        if phase=="evacuation" then return "evacuate" end
        if phase=="coronation" then return "coronation" end
    end
    return nil
end

function R3.damageResident(state: any,npc: any,damage: number): boolean
    if npc.health<=0 or not finite(damage) or damage<=0 then return false end
    npc.health=math.max(0,npc.health-damage)
    if npc.health==0 then
        Work.releaseWorker(state,npc)
        npc.state="dead"
        npc.activity=nil
        npc.motionX=0
        npc.underAttack=false
        -- Bag, gear and ammunition remain on this record until a recovery
        -- policy is approved. The corpse is excluded from the active economy.
        return true
    end
    return false
end

function R3.playerDied(state: any)
    local stats=state.r3.stats
    stats.playerDeaths=(stats.playerDeaths or 0)+1
    state.r3.awaitingRecovery=true
end

local function shelterFor(state: any,npc: any,threat: any,evacuating: boolean): any
    local best=nil
    local distance=math.huge
    for _,b in ipairs(state.buildings) do
        local kind=Structures.get(b.typeId).kind
        if (kind=="habitation" or kind=="treasury") and b.health>0 and not b.ruined
            and (b.state=="complete" or b.state=="damaged")
            and Work.canReach(state,npc.x,b.x,if Inventory.weight(npc.inventory)>0 then "carrier" else "worker")
            and (not threat or (b.x-threat.x)*(npc.x-threat.x)>=0) then
            local range=math.abs(b.x-npc.x)+(if evacuating and b.typeId~="castle" then 25 else 0)
            if range<distance then best=b; distance=range end
        end
    end
    return best
end

type Fire = (any, any) -> boolean
function R3.step(state: any,dt: number,playerX: number,fire: Fire?,playerY: number?): number
    local d=state.r3
    if not finite(dt) or dt<=0 or not finite(playerX) then return 0 end
    dt=math.min(dt,0.25)
    local story=d.prologue
    story.time+=dt
    if Story.advance(story,dt,playerX,playerY==nil or playerY> -24) then
        table.insert(d.enemies,{id=d.nextEnemyId,x=story.dukeX,hp=64,side=-1,
            loot=0,attackClock=0,typeId="infected_duke"})
        d.nextEnemyId+=1
        d.raidActive=true
    end
    local day=math.floor(state.elapsed/R3.DAY)
    local dayTick=state.elapsed%R3.DAY
    d.night=day
    local night=dayTick>=R3.NIGHT_START and dayTick<R3.NIGHT_END
    local scheduled=day>=1 and (day-1)%3==0
    -- First night is peaceful; from night two every third night can bring
    -- a local raid. Warn while there is still daylight to prepare defenses.
    if d.prologue.stage=="sandbox" and not night and scheduled
        and dayTick>=R3.NIGHT_START-25 and #d.enemies==0
        and d.lastNight<day then
        d.raidWarning="Batedores viram invasores! Proteja as muralhas."
    end
    if d.prologue.stage=="sandbox" and night and day>d.lastNight then
        d.lastNight=day
        -- First sandbox night is protected; later local raids alternate with
        -- genuinely quiet nights. This is not a copied external game curve.
        if scheduled and #d.enemies==0 then
            R3.spawnWave(state,2)
        else
            d.raidWarning="Noite tranquila. Mantenha suas defesas prontas."
        end
    end

    local playerDamage=0
    for i=#d.enemies,1,-1 do
        local e=d.enemies[i]
        local block=if e.typeId=="infected_duke" then nil else wallBeforeTown(state,e)
        local innerLine=story.scene and story.stage=="last_ring" and e.typeId~="infected_duke"
        local target=if block or innerLine or e.typeId=="infected_duke" then nil else raiderGoal(state,e)
        local bridge,bank=bridgeAtEnemy(state,e)
        local goal=if bridge and bank and story.stage=="sandbox" then bank elseif block then block.x elseif e.typeId=="infected_duke" then math.clamp(playerX,-118,118)
            elseif innerLine then e.side*7 elseif target then target.x else 0
        local diff=goal-e.x
        local delta=math.clamp(diff,-4.8*dt,4.8*dt)
        e.motionX=0
        if e.hp<=0 then continue end
        if math.abs(diff)>2.8 then
            e.x+=delta
            e.motionX=delta/dt
        elseif bridge and bank and story.stage=="sandbox" then
            R3.damageStructure(state,bridge,9*dt)
        elseif block then
            local siege=story.scene and story.stage=="crisis" and block.districtBoundary
            block.health=math.max(0,block.health-(if siege then 115 else 7)*dt)
            if block.state=="complete" then block.state="damaged" end
            ruin(state,block)
            d.stats.structuresHit+=dt
        else
            e.attackClock=math.max(0,e.attackClock-dt)
            local surface=World.sample(state.seed,e.x,0)
            local altitude=(if surface.wet then World.WATER_SURFACE else surface.height)+3
            if math.abs(e.x-playerX)<4 and e.attackClock<=0
                and (playerY==nil or math.abs(playerY-altitude)<6) then
                e.attackClock=1.7
                playerDamage+=if e.typeId=="infected_duke" then 7 else 4
            end
            if target then
                target.health=math.max(0,target.health-4*dt)
                if target.state=="complete" then target.state="damaged" end
                ruin(state,target)
            end
            for _,drop in ipairs(d.drops) do
                if not drop.claimed and math.abs(drop.x-e.x)<2 then
                    drop.claimed=true
                    e.loot+=drop.value
                    ledger(d,"stolen",-drop.value,tostring(drop.id))
                    break
                end
            end
        end
        -- An enemy that reaches the opposing border escapes with stolen
        -- coins rather than minting them back.
        if math.abs(e.x)>125 then
            d.stats.coinsLost+=e.loot
            table.remove(d.enemies,i)
        end
    end

    local evacuating=story.scene and (story.stage=="evacuation" or story.stage=="last_ring")
    local confirmed=false
    for _,enemy in ipairs(d.enemies) do
        if enemy.hp>0 and enemy.typeId~="infected_duke" and math.abs(enemy.x)<92 then
            confirmed=true
            break
        end
    end
    for _,npc in ipairs(state.npcs) do
        if npc.health<=0 then continue end
        local nearest=nil
        local dist=math.huge
        for _,e in ipairs(d.enemies) do
            local delta=math.sqrt((npc.x-e.x)^2+(npc.z or 0)^2)
            if e.hp>0 and delta<dist then nearest=e; dist=delta end
        end
        local direct=nearest~=nil and dist<19
        local ordered=evacuating or (confirmed and math.abs(npc.x)<108)
        if ordered or direct then
            npc.threatUntil=state.elapsed+4
        end
        npc.underAttack=ordered or direct or (npc.threatUntil or 0)>state.elapsed
        npc.defenseClock=math.max(0,(npc.defenseClock or 0)-dt)
        local defender=npc.defense=="spear" or (npc.defense=="bow" and (npc.arrows or 0)>0)
        if npc.underAttack and not defender then
            local shelter=shelterFor(state,npc,nearest,evacuating==true)
            local safe=if shelter then shelter.x elseif nearest then npc.x+(if npc.x>=nearest.x then 8 else -8) else 0
            local target=if state.production and shelter then safe else math.clamp(safe,-116,116)
            local depth=if shelter then -4.4 else math.clamp((npc.z or 0)+4,-3,15)
            npc.activity="flee"
            if Work.walkResident(state,npc,target,dt,depth,7.2) and shelter then npc.activity="sheltered" end
            npc.safety=if npc.activity=="sheltered" then "sheltered" else "evacuating"
        elseif nearest and defender and npc.underAttack then
            npc.safety="defending"
            local wall=wallBeforeTown(state,nearest)
            local blocked=wall and (npc.x-wall.x)*(nearest.x-wall.x)<0
            if npc.defenseClock<=0 and npc.defense=="bow" and dist>=4 and dist<=24 and fire and fire(npc,nearest) then
                npc.arrows-=1
                npc.activity="strike"
                npc.defenseClock=if npc.profession=="archer" then 1.18 else 1.5
            elseif npc.defenseClock<=0 and npc.defense=="spear" and dist<4.5 and not blocked
                and math.abs(World.sample(state.seed,npc.x,0).height-World.sample(state.seed,nearest.x,0).height)<3 then
                nearest.hp-=if npc.profession=="spearman" then 10 else 7
                npc.activity="strike"
                npc.defenseClock=if npc.profession=="guard" then 0.95 else 1.2
            elseif dist>(if npc.defense=="bow" then 20 else 3.7) then
                local side=if npc.x>=nearest.x then 1 else -1
                local position=if blocked then wall.x+side*6
                    else nearest.x+side*(if npc.defense=="bow" then 14 else 2.8)
                if Work.canReach(state,npc.x,position,"guard") then
                    Work.walkResident(state,npc,position,dt,0,6)
                end
            end
        else
            npc.safety=if npc.safety=="evacuating" or npc.safety=="sheltered" or npc.safety=="defending"
                then "resuming" else if story.stage=="sandbox" and scheduled and not night and dayTick>=R3.NIGHT_START-25
                    and dayTick<R3.NIGHT_START and d.lastNight<day then "alert" else "safe"
        end
        if nearest and dist<2.8 and npc.activity~="sheltered" and nearest.typeId~="infected_duke" then
            local wall=wallBeforeTown(state,nearest)
            if not wall or (npc.x-wall.x)*(nearest.x-wall.x)>=0 then
                R3.damageResident(state,npc,2*dt)
            end
        end
    end
    for i=#d.enemies,1,-1 do
        if d.enemies[i].hp<=0 then killEnemy(state,i) end
    end
    if d.raidActive and #d.enemies==0 then
        d.raidActive=false
        d.stats.repelled+=1
        d.raidWarning="A invasão terminou. As obras podem continuar."
        if d.prologue.stage=="duke_fight" then
            Story.enter(story,"crisis")
            R3.spawnWave(state,2)
            if story.scene then
                for index,e in ipairs(d.enemies) do e.x=e.side*(48+math.floor((index-1)/2)*5) end
            end
        elseif d.prologue.stage=="crisis" then
            if story.scene then
                for _,b in ipairs(state.buildings) do
                    if b.districtBoundary then b.health=0; ruin(state,b) end
                end
            end
            Story.enter(story,"evacuation")
            d.raidWarning="Evacue os moradores para o último anel."
        else
            finishPrologue(state)
        end
    end
    return playerDamage
end

function R3.summary(state: any): any
    local d=state.r3
    return {wallet=d.wallet,treasury=d.treasury,arrows=d.arrows,
        playerItems=if d.playerBag then table.clone(d.playerBag.items) else {},
        playerWood=if d.playerBag then Inventory.count(d.playerBag,"wood") else 0,
        bagMass=if d.playerBag then Inventory.weight(d.playerBag) else 0,
        bagCapacity=if d.playerBag then d.playerBag.maxMass else 24,
        clock=state.elapsed%R3.DAY,day=math.floor(state.elapsed/R3.DAY)+1,
        night=(state.elapsed%R3.DAY)>=R3.NIGHT_START
            and (state.elapsed%R3.DAY)<R3.NIGHT_END,
        phase=d.prologue.stage,raidActive=d.raidActive,
        warning=Story.hint(d.prologue) or d.raidWarning,enemies=#d.enemies,
        deaths=d.stats.playerDeaths or 0,
        raidForecast=d.prologue.stage=="sandbox" and not d.raidActive
            and d.lastNight<math.floor(state.elapsed/R3.DAY)
            and (math.floor(state.elapsed/R3.DAY)-1)%3==0
            and math.floor(state.elapsed/R3.DAY)>=1
            and state.elapsed%R3.DAY>=R3.NIGHT_START-25
            and state.elapsed%R3.DAY<R3.NIGHT_START,
        drops=d.drops,stats=d.stats}
end
return R3
