--!strict
-- T1-R3 foundation. Deterministic, server-owned and persistence-safe.
-- Gameplay rules here contain no Instance, Remote or client trust.
local World=require("../WorldProfile")
local Structures=require("./StructureDefs")
local R3={}
R3.VERSION=1
R3.DAY=240
R3.NIGHT_START=160
R3.NIGHT_END=235
R3.MAX_ENEMIES=12
R3.MAX_DROPS=48

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
        or #d.ledger>80 then return false end
    for _,e in ipairs(d.enemies) do
        if not finite(e.x) or not finite(e.hp) or not finite(e.side)
            or not finite(e.id) or not finite(e.loot) then return false end
    end
    for _,drop in ipairs(d.drops) do
        if not finite(drop.id) or not finite(drop.x) or not finite(drop.value)
            or drop.value<=0 or drop.value%1~=0 or type(drop.claimed)~="boolean" then
            return false
        end
    end
    return true
end

function R3.ensure(state: any, newCampaign: boolean)
    if state.r3~=nil then
        assert(R3.valid(state.r3),"unsupported_r3_schema")
        return state.r3
    end
    -- Existing R2 saves enter sandbox; a truly fresh campaign gets the
    -- interactive prologue. No previous world is reset or overwritten.
    state.r3={
        version=R3.VERSION, wallet=0, treasury=24, arrows=12,
        enemies={}, drops={}, ledger={}, nextEnemyId=1,nextDropId=1,
        lastNight= -1, night=0, raidActive=false, raidWarning="",
        prologue={stage=if newCampaign then "guard" else "sandbox",time=0},
        stats={killed=0,repelled=0,coinsLost=0,structuresHit=0,shots=0},
    }
    return state.r3
end

local function ledger(d: any,kind: string,value: number,reference: string)
    table.insert(d.ledger,{kind=kind,value=value,reference=reference})
    while #d.ledger>80 do table.remove(d.ledger,1) end
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
        or math.abs(x)>120 then return false,"invalid_coin_drop" end
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

function R3.craftArrows(state: any,x: number): (boolean, any)
    if not finite(x) then return false,"invalid_position" end
    local d=state.r3
    if d.arrows>24 then return false,"ammo_capacity" end
    -- The player must stand beside an existing finite timber stock. Each
    -- bundle consumes two real units of wood and produces six arrows.
    for _,site in ipairs(state.sites) do
        if site.item=="wood" and site.remaining>=2 and math.abs(site.x-x)<=9 then
            site.remaining-=2
            d.arrows+=6
            ledger(d,"arrow_crafting",0,tostring(site.id))
            return true,d.arrows
        end
    end
    return false,"wood_stock_required"
end

function R3.trade(state: any,item: string,x: number): (boolean, any)
    -- Small local exchange backed by a finite village stock AND the
    -- persisted ducal treasury; no infinite coins from trees or kills.
    if not finite(x) or math.abs(x)>24 then return false,"too_far_from_market" end
    local price=if item=="wood" then 1 else if item=="stone" then 2
        else if item=="iron" then 3 else if item=="food" then 1 else 0
    if price==0 then return false,"unknown_trade_item" end
    local d=state.r3
    if d.treasury<price then return false,"treasury_empty" end
    for _,site in ipairs(state.sites) do
        if site.item==item and site.remaining>=1 then
            site.remaining-=1
            d.treasury-=price
            d.wallet+=price
            ledger(d,"trade_income",price,item)
            return true,price
        end
    end
    return false,"resource_unavailable"
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
        -- Exactly the coins already stolen from an existing ground record.
        makeDrop(d,e.x,e.loot,"recovered_loot")
    end
    table.remove(d.enemies,index)
    d.stats.killed+=1
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
    target.hp-=damage
    local id=target.id
    if target.hp<=0 then killEnemy(state,nearest) end
    return true,id
end

function R3.arm(state: any,npcId: any,weapon: string): (boolean, any)
    local d=state.r3
    if weapon~="bow" and weapon~="spear" then return false,"invalid_weapon" end
    for _,npc in ipairs(state.npcs) do
        if npc.id==npcId then
            if npc.defense==weapon then return false,"already_equipped" end
            -- Equipment consumes finite raw material at an existing site.
            local required=if weapon=="bow" then "wood" else "iron"
            local cost=if weapon=="bow" then 3 else 2
            local source=nil
            for _,site in ipairs(state.sites) do
                if site.item==required and site.remaining>=cost then
                    source=site
                    break
                end
            end
            if not source then return false,"not_enough_equipment_materials" end
            source.remaining-=cost
            npc.defense=weapon
            npc.defenseClock=0
            npc.arrows=if weapon=="bow" then 8 else 0
            ledger(d,"equipment",0,tostring(npcId)..":"..weapon)
            return true,npcId
        end
    end
    return false,"npc_not_found"
end

local function finishPrologue(state: any)
    local d=state.r3
    if d.prologue.stage=="last_ring" and #d.enemies==0 then
        d.prologue.stage="coronation"
        d.raidActive=false
        d.raidWarning="A cidade sobreviveu. Os moradores aguardam sua decisão."
    end
end

function R3.command(state: any,command: string): (boolean, any)
    local d=state.r3
    local stage=d.prologue.stage
    if command=="evacuate" and stage=="evacuation" then
        d.prologue.stage="last_ring"
        R3.spawnWave(state,2)
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
local function ruin(state: any,b: any)
    if b.health>0 or b.ruined==true then return end
    local def=Structures.get(b.typeId)
    if not def then return end
    b.ruined=true
    b.state="ruined"
    b.progress=0
    for item,amount in pairs(b.delivered) do
        local recover=math.min(amount,math.floor((def.cost[item] or 0)*0.2))
        if recover>0 and #state.sites<256 then
            table.insert(state.sites,{id="salvage_"..tostring(b.id).."_"..item,
                item=item,x=b.x,remaining=recover})
        end
    end
    b.delivered={}
    b.claimed={}
    b.health=0
    table.insert(state.events,{kind="ruined",buildingId=b.id,time=state.elapsed})
end

local function wallBeforeTown(state: any,e: any): any
    local best=nil
    local nearest=math.huge
    for _,b in ipairs(state.buildings) do
        local def=Structures.get(b.typeId)
        if def and (b.typeId=="wall" or b.typeId=="fence")
            and b.health>0 and b.progress>=def.buildSeconds then
            -- Only an intact barrier on this enemy's approach blocks the path.
            local approach=(b.x-e.x)*(-e.side)
            if approach>= -2 and approach<nearest then
                nearest=approach
                best=b
            end
        end
    end
    return best
end

function R3.step(state: any,dt: number,playerX: number): number
    local d=state.r3
    if not finite(dt) or dt<=0 or not finite(playerX) then return 0 end
    dt=math.min(dt,0.25)
    d.prologue.time+=dt
    local day=math.floor(state.elapsed/R3.DAY)
    local dayTick=state.elapsed%R3.DAY
    d.night=day
    local night=dayTick>=R3.NIGHT_START and dayTick<R3.NIGHT_END
    if d.prologue.stage=="sandbox" and night and day>d.lastNight then
        d.lastNight=day
        -- First sandbox night is protected; later local raids alternate with
        -- genuinely quiet nights. This is not a copied external game curve.
        if day>=2 and (day+state.seed)%3==0 and #d.enemies==0 then
            R3.spawnWave(state,2)
        else
            d.raidWarning="Noite tranquila. Mantenha suas defesas prontas."
        end
    end

    local playerDamage=0
    for i=#d.enemies,1,-1 do
        local e=d.enemies[i]
        local block=wallBeforeTown(state,e)
        local goal=if block then block.x else 0
        local diff=goal-e.x
        if math.abs(diff)>2.8 then
            local delta=math.min(math.abs(diff),4.8*dt)
            e.x+=if diff>0 then delta else -delta
        elseif block then
            block.health=math.max(0,block.health-7*dt)
            if block.state=="complete" then block.state="damaged" end
            ruin(state,block)
            d.stats.structuresHit+=dt
        else
            if math.abs(e.x-playerX)<4 then
                e.attackClock-=dt
                if e.attackClock<=0 then
                    e.attackClock=1.7
                    playerDamage+=4
                end
            end
            for _,b in ipairs(state.buildings) do
                if math.abs(b.x-e.x)<4 and b.health>0 then
                    b.health=math.max(0,b.health-4*dt)
                    if b.state=="complete" then b.state="damaged" end
                    ruin(state,b)
                    break
                end
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

    -- Guard / archer behavior uses existing real NPCs and finite ammo.
    for _,npc in ipairs(state.npcs) do
        local nearest=nil
        local dist=math.huge
        for _,e in ipairs(d.enemies) do
            local delta=math.abs(npc.x-e.x)
            if delta<dist then nearest=e; dist=delta end
        end
        npc.underAttack=nearest~=nil and dist<12
        if npc.underAttack and nearest and npc.defense==nil then
            local away=if npc.x>=nearest.x then 1 else -1
            npc.x=math.clamp(npc.x+away*5*dt,-116,116)
            npc.motionX=away*5
        end
        if nearest then
            if npc.defense=="bow" and (npc.arrows or 0)>0 and dist<30
                and (npc.defenseClock or 0)<=0 then
                npc.arrows-=1
                nearest.hp-=10
                npc.defenseClock=1.5
            elseif npc.defense=="spear" and dist<5 and (npc.defenseClock or 0)<=0 then
                nearest.hp-=7
                npc.defenseClock=1.2
            end
        end
        npc.defenseClock=math.max(0,(npc.defenseClock or 0)-dt)
    end
    for i=#d.enemies,1,-1 do
        if d.enemies[i].hp<=0 then killEnemy(state,i) end
    end
    if d.raidActive and #d.enemies==0 then
        d.raidActive=false
        d.stats.repelled+=1
        d.raidWarning="A invasão terminou. As obras podem continuar."
        if d.prologue.stage=="duke_fight" then
            d.prologue.stage="crisis"
            R3.spawnWave(state,2)
        elseif d.prologue.stage=="crisis" then
            d.prologue.stage="evacuation"
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
        clock=state.elapsed%R3.DAY,day=math.floor(state.elapsed/R3.DAY)+1,
        night=(state.elapsed%R3.DAY)>=R3.NIGHT_START
            and (state.elapsed%R3.DAY)<R3.NIGHT_END,
        phase=d.prologue.stage,raidActive=d.raidActive,
        warning=d.raidWarning,enemies=#d.enemies,
        drops=d.drops,stats=d.stats}
end
return R3
