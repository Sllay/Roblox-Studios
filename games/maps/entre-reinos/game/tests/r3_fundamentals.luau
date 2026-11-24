--!strict
-- T1-R3 executable pure domain contracts; no Roblox engine shims.
local Living=require("../places/main/src/ReplicatedStorage/Living/LivingModel")
local R3=require("../places/main/src/ReplicatedStorage/Living/R3Engine")
local Work=require("../places/main/src/ReplicatedStorage/Living/WorkEngine")
local Structures=require("../places/main/src/ReplicatedStorage/Living/StructureDefs")
local seed=516639272

local legacy=Living.new(seed)
assert(legacy.r3==nil)
local old=Living.clone(legacy)
local sandbox=R3.ensure(legacy,false)
assert(sandbox.prologue.stage=="sandbox")
assert(Living.valid(legacy))
assert(Living.restore(Living.clone(legacy),seed))
assert(old.r3==nil, "migrating old save must not mutate previous snapshot")
assert(R3.ensure(legacy,false)==sandbox, "migration must be idempotent")
local fresh=Living.new(seed)
local d=R3.ensure(fresh,true)
-- A v16 save that has already entered this route retains its old stage graph.
d.prologue={stage="guard",time=0}
assert(d.prologue.stage=="guard" and #d.enemies==0 and d.wallet==0)
assert(R3.command(fresh,"evacuate")==false)
assert(R3.command(fresh,"training"))
assert(d.prologue.stage=="duke_fight" and #d.enemies==1)
assert(d.enemies[1].typeId=="infected_duke")
assert(R3.spawnWave(fresh,2)==false,"duke cannot be bypassed")
local originalId=d.enemies[1].id
local dukeX=d.enemies[1].x
assert(R3.hit(fresh,dukeX-1,75,1,6,99)==false,"different vertical layer")
assert(R3.hit(fresh,dukeX-1,20,1,6,99))
assert(d.stats.killed==1 and #d.enemies==0)
R3.step(fresh,0.1,0)
assert(d.prologue.stage=="crisis" and #d.enemies==4)
assert(d.enemies[1].id~=originalId)

-- Removing the actual raiders transitions the playable script into civilian
-- evacuation, then a last defensive ring; no grant until coronation.
for _,e in ipairs(d.enemies) do e.hp=0 end
R3.step(fresh,0.1,0)
assert(d.prologue.stage=="evacuation" and #d.enemies==0 and d.wallet==0)
assert(R3.command(fresh,"evacuate"))
assert(d.prologue.stage=="last_ring" and #d.enemies==4)
for _,e in ipairs(d.enemies) do e.hp=0 end
R3.step(fresh,0.1,0)
assert(d.prologue.stage=="coronation" and d.wallet==0)
assert(R3.command(fresh,"coronation"))
assert(d.prologue.stage=="sandbox" and d.wallet==8 and d.treasury==16)
assert(not R3.command(fresh,"coronation"),"crown grant must be issued only once")

-- Real currency: player may drop a minted-from-treasury coin exactly once.
local previous=d.wallet
local ok,dropId=R3.drop(fresh,0,1)
assert(ok and d.wallet==previous-1)
assert(R3.pickup(fresh,dropId,60)==false,"pickup must be near")
assert(R3.pickup(fresh,dropId,0))
assert(d.wallet==previous)
assert(R3.pickup(fresh,dropId,0)==false,"no duplicate pickup")
assert(R3.drop(fresh,0,1000)==false)
assert(R3.trade(fresh,"fake",0)==false)
local woodBefore=fresh.sites[1].remaining
local treasuryBefore=d.treasury
local balanceBefore=d.wallet
assert(not R3.trade(fresh,"wood",0),"trade cannot sell raw materials from a remote site")
local Inventory=require("../places/main/src/ReplicatedStorage/Living/Inventory")
assert(Inventory.add(d.playerBag,"wood",1))
assert(R3.trade(fresh,"wood",0))
assert(Inventory.count(d.playerBag,"wood")==0 and fresh.sites[1].remaining==woodBefore)
assert(d.treasury==treasuryBefore-1 and d.wallet==balanceBefore+1)
assert(R3.trade(fresh,"wood",100)==false,"trade not possible outside village")
assert(d.wallet+d.treasury==balanceBefore+treasuryBefore,
    "trade only transfers money, never prints new money")

-- Equipment consumes real finite resources and cannot be free-repeated.
local woodAfterTrade=fresh.sites[1].remaining
assert(not R3.arm(fresh,1,"bow"),"remote timber cannot equip a defender")
assert(Inventory.add(d.playerBag,"wood",3))
local equipped,npcId=R3.arm(fresh,1,"bow")
assert(equipped and npcId==1)
assert(fresh.sites[1].remaining==woodAfterTrade and Inventory.count(d.playerBag,"wood")==0)
assert(R3.arm(fresh,1,"bow")==false)
assert(R3.arm(fresh,999,"spear")==false)
local timber=fresh.sites[1]
local timberBefore=timber.remaining
assert(R3.craftArrows(fresh,0)==false,"do not conjure arrows from distant timber")
assert(R3.craftArrows(fresh,timber.x))
assert(timber.remaining==timberBefore-2 and d.arrows==18)
for _=1,2 do assert(R3.craftArrows(fresh,timber.x)) end
assert(d.arrows==30 and R3.craftArrows(fresh,timber.x)==false,
    "finite ammo capacity blocks excess inventory")

-- T1-F1: user reported that the on-screen arrow recipe could never
-- fire. Ownership must be clear: a forest site is NOT a player inventory.
local personal=Living.new(seed)
local bag=R3.ensure(personal,false)
local forest=personal.sites[1]
local World=require("../places/main/src/ReplicatedStorage/WorldProfile")
local treeY=World.sample(seed,forest.x,0).height+3
local sourceBefore=forest.remaining
assert(not R3.takeWood(personal,0,treeY),
    "player cannot withdraw wood from an arbitrary faraway tree")
assert(not R3.takeWood(personal,forest.x,treeY+100),
    "player may not gather wood far below/above the terrain")
assert(R3.takeWood(personal,forest.x,treeY))
assert(forest.remaining==sourceBefore-2 and bag.playerBag.items.wood==2)
assert(R3.summary(personal).playerWood==2)
assert(R3.craftArrows(personal,0),
    "player should craft anywhere from wood already carried")
assert(bag.arrows==18 and bag.playerBag.items.wood==nil)
assert(forest.remaining==sourceBefore-2)
assert(R3.takeWood(personal,forest.x,treeY))
local carried=Living.clone(personal)
local reentered=Living.restore(carried,seed)
assert(reentered and reentered.r3.playerBag.items.wood==2,
    "picked-up wood must persist across slot reload")
assert(R3.ensure(reentered,false).playerBag.items.wood==2)
assert(Living.valid(reentered))
local noBag=Living.clone(reentered)
noBag.r3.playerBag=nil -- v14 save has no playerBag: must migrate safely.
assert(Living.valid(noBag))
local beforeOld=noBag.sites[1].remaining
R3.ensure(noBag,false)
assert(noBag.r3.playerBag.items.wood==nil)
assert(noBag.sites[1].remaining==beforeOld,
    "migration may never grant or delete resources")
assert(R3.ensure(noBag,false)==noBag.r3,
    "reopening cannot reset a player's bag")
local snapshot=Living.clone(reentered)
snapshot.r3.playerBag.maxMass=1
assert(not Living.valid(snapshot),
    "overweight crafted/gathered player bag must fail save validation")
-- Harvest stored wood with exactly one transfer, never duplicates.
local warehousePickup=Living.new(seed)
local warehouseData=R3.ensure(warehousePickup,false)
local placedStorage,depot=Work.place(warehousePickup,"stockpile",18)
assert(placedStorage)
depot.state="complete"
assert(require("../places/main/src/ReplicatedStorage/Living/Inventory")
    .add(depot.stored,"wood",4))
local fromStock=depot.stored.items.wood
local depotY=World.sample(seed,depot.x,0).height+3
assert(R3.takeWood(warehousePickup,depot.x,depotY))
assert(depot.stored.items.wood==fromStock-2)
assert(warehouseData.playerBag.items.wood==2)
assert(R3.craftArrows(warehousePickup,0))
assert(warehouseData.playerBag.items.wood==nil)
assert(depot.stored.items.wood==fromStock-2)
assert(Living.valid(warehousePickup))

-- Wall exists as a true collision gate in the 2.5D raid lane.
local blocked=Living.new(seed)
local bstate=R3.ensure(blocked,false)
local placed,wall=Work.place(blocked,"wall",18)
assert(placed)
wall.progress=Structures.get("wall").buildSeconds
wall.state="complete"
wall.health=Structures.get("wall").health
assert(R3.spawnWave(blocked,2))
local right=nil
for _,e in ipairs(bstate.enemies) do if e.side==1 then right=e;break end end
assert(right~=nil)
for _=1,250 do
    Work.step(blocked,0.1)
    R3.step(blocked,0.1,0)
end
assert(wall.health>0,"do not test intact-wall blocking after a wall is destroyed")
assert(right.x>=wall.x-3,"wall must stop a raider while intact")
assert(wall.health<Structures.get("wall").health,
    "real structure must lose HP when attacked")
assert(wall.state=="damaged")
-- Destroyed defenses cannot protect forever. Salvage is emitted ONCE from
-- previously delivered material, then NPCs must re-deliver to rebuild.
wall.delivered={wood=10,stone=12}
local sitesBefore=#blocked.sites
for _=1,950 do R3.step(blocked,0.1,0) end
assert(wall.ruined==true and wall.state=="ruined" and wall.health==0)
assert(#blocked.sites==sitesBefore+2,"one wood and one stone salvage site")
local siteCount=#blocked.sites
for _=1,100 do R3.step(blocked,0.1,0) end
assert(#blocked.sites==siteCount,"ruins must never mint salvage repeatedly")
blocked.r3.enemies={}
blocked.r3.raidActive=false
for _,npc in ipairs(blocked.npcs) do npc.underAttack=false end
for _=1,6500 do
    Work.step(blocked,0.1)
    if wall.state=="complete" then break end
end
assert(wall.state=="complete" and wall.ruined==false)
assert(wall.health==Structures.get("wall").health)
assert(Living.valid(blocked),"repaired and salvaged world must remain saveable")
-- Deterministic local threat curve: first night protected; second night
-- warns at dusk and then spawns exactly one two-sided wave.
local clock=Living.new(seed)
local clockRaid=R3.ensure(clock,false)
clock.elapsed=R3.NIGHT_START+0.1
R3.step(clock,0.1,0)
assert(#clockRaid.enemies==0,"first sandbox night must be peaceful")
clock.elapsed=R3.DAY+R3.NIGHT_START-20
R3.step(clock,0.1,0)
assert(R3.summary(clock).raidForecast==true)
assert(#clockRaid.enemies==0)
clock.elapsed=R3.DAY+R3.NIGHT_START+0.1
R3.step(clock,0.1,0)
assert(#clockRaid.enemies==4 and clockRaid.lastNight==1)
R3.step(clock,0.1,0)
assert(#clockRaid.enemies==4,"each night only spawns once")
for _,e in ipairs(clockRaid.enemies) do e.hp=0 end
R3.step(clock,0.1,0)
clock.elapsed=R3.DAY*2+R3.NIGHT_START+0.1
R3.step(clock,0.1,0)
assert(#clockRaid.enemies==0,"alternating nights stay quiet")
-- Raid conditions do not roll every night and preserve existing snapshots.
local saved=Living.clone(fresh)
assert(Living.valid(saved))
local reopened=Living.restore(saved,seed)
assert(reopened and R3.valid(reopened.r3))
assert(reopened.r3.wallet==fresh.r3.wallet)
assert(reopened.r3.prologue.stage=="sandbox")
assert(reopened.r3.stats.killed==fresh.r3.stats.killed)
saved.r3.wallet=-5
assert(not Living.valid(saved),"invalid R3 ledger must block save")
print("ENTRE_REINOS_T1_R3: prologue, combat, raids, walls, trade, loot, equip, save passed")

local damagedDepot=Living.new(seed)
local raiders=R3.ensure(damagedDepot,false)
local made,building=Work.place(damagedDepot,"stockpile",0)
assert(made)
building.state="complete"
building.progress=Structures.get("stockpile").buildSeconds
building.health=1
assert(Inventory.add(building.stored,"wood",7))
assert(not R3.craftArrows(damagedDepot,0,70),"warehouse must be in vertical reach")
assert(not R3.trade(damagedDepot,"wood",0,70),"market must be in vertical reach")
assert(R3.spawnWave(damagedDepot,2))
for _=1,300 do R3.step(damagedDepot,0.1,0) end
assert(building.state=="ruined" and building.ruinedStock.wood==7)
assert(Inventory.count(building.stored,"wood")==0 and Work.stockAvailable(damagedDepot,building,"wood")==0)
assert(not R3.takeWood(damagedDepot,0,building.y+3))
assert(raiders.wallet==0 and raiders.treasury==24)
local ruins=Living.restore(damagedDepot,seed)
assert(ruins and ruins.buildings[1].ruinedStock.wood==7)
print("ENTRE_REINOS_T1_F1_RAID: a raid isolates seven stored units exactly once and blocks withdrawal")

-- 3 seeds, real collection and project custody, four saved story checkpoints,
-- distinct physical actors, damage boundaries, and life-cycle conservation.
local Trajectory=require("../places/main/src/ReplicatedStorage/Living/Trajectory")
assert(Trajectory.intersection(0,2,20,0,10,0,1,5)==0.45)
assert(not Trajectory.intersection(0,9,20,0,10,0,1,5))
assert(not Trajectory.intersection(0,2,2,0,10,0,1,5))
assert(Trajectory.intersection(20,2,-20,0,10,0,1,5)==0.45)

for _,campaignSeed in ipairs({42,1009,516639272}) do
    local campaign=Living.new(campaignSeed)
    Work.initializeVillage(campaign)
    local story=R3.ensure(campaign,true)
    assert(#R3.storyActors(story.prologue)==3)
    assert(not R3.command(campaign,"training",40))
    assert(R3.command(campaign,"training",0) and story.prologue.stage=="escort")
    for _=1,20 do R3.step(campaign,0.1,45) end
    assert(story.prologue.dukeX==-4,"duke cannot escort himself")
    for _=1,100 do
        R3.step(campaign,0.1,story.prologue.dukeX)
        if story.prologue.stage=="encounter" then break end
    end
    assert(story.prologue.stage=="encounter" and #R3.storyActors(story.prologue)==4)
    campaign=assert(Living.restore(campaign,campaignSeed))
    story=campaign.r3
    for _=1,70 do
        R3.step(campaign,0.1,story.prologue.dukeX)
        if story.prologue.stage=="duke_fight" then break end
    end
    assert(story.enemies[1].typeId=="infected_duke")
    assert(#R3.storyActors(story.prologue)==2)
    assert(R3.damageEnemy(campaign,story.enemies[1].id,64))
    R3.step(campaign,0.1,0)
    assert(story.prologue.stage=="crisis" and #story.enemies==4)
    local west,east=campaign.buildings[4],campaign.buildings[5]
    for _=1,130 do R3.step(campaign,0.1,0) end
    assert(west.ruined and east.ruined,"the two real outer fortifications must take siege damage")
    local function repel()
        while #story.enemies>0 do assert(R3.damageEnemy(campaign,story.enemies[1].id,70)) end
        R3.step(campaign,0.1,0)
    end
    repel()
    assert(story.prologue.stage=="evacuation")
    assert(not R3.command(campaign,"evacuate",30))
    assert(R3.command(campaign,"evacuate",0))
    assert(story.prologue.stage=="last_ring")
    repel()
    assert(story.prologue.stage=="coronation" and #R3.storyActors(story.prologue)==1)
    assert(campaign.elapsed%R3.DAY==0)
    assert(R3.command(campaign,"coronation",0))
    assert(story.prologue.stage=="sandbox" and story.wallet==8)
    assert(not R3.command(campaign,"coronation",0))

    local custody=Living.new(campaignSeed)
    R3.ensure(custody,false)
    custody.r3.wallet=story.wallet
    assert(Work.place(custody,"shelter",18))
    local worker=custody.npcs[1]
    assert(Inventory.add(worker.inventory,"wood",2))
    Work.step(custody,0.1)
    assert(worker.reserved>0)
    assert(R3.damageResident(custody,worker,100))
    assert(not R3.damageResident(custody,worker,100))
    assert(worker.reserved==0 and worker.state=="dead")
    local remaining=Inventory.count(worker.inventory,"wood")
    assert(remaining==2)
    local snapshot=assert(Living.restore(custody,campaignSeed))
    R3.playerDied(snapshot)
    assert(snapshot.r3.awaitingRecovery and snapshot.r3.wallet==8)
    for _=1,25 do Work.step(snapshot,0.1) end
    assert(snapshot.npcs[1].reserved==0 and snapshot.npcs[1].state=="dead")
    assert(Inventory.count(snapshot.npcs[1].inventory,"wood")==remaining)
    assert(Work.summary(snapshot).resources.isolated.wood>=remaining)
    assert(Living.valid(snapshot))
end

local ranged=Living.new(seed)
local scene=R3.ensure(ranged,false)
local defender=ranged.npcs[1]
assert(Inventory.add(scene.playerBag,"wood",3))
assert(R3.arm(ranged,defender.id,"bow"))
assert(R3.spawnWave(ranged,1))
scene.enemies[1].x=defender.x+12
scene.enemies[2].x=defender.x+13
local ammo=defender.arrows
R3.step(ranged,0.1,0,function() return false end)
assert(defender.arrows==ammo)
local fired=0
R3.step(ranged,0.1,0,function(npc,enemy)
    assert(npc.id==defender.id and enemy.hp==30)
    fired+=1
    return true
end)
assert(fired==1 and defender.arrows==ammo-1)
assert(scene.enemies[1].hp==30,"only a subsequent projectile impact deals bow damage")
print("ENTRE_REINOS_T1_F2: three campaigns, death custody, and authoritative weapon sweep")

local approach=Living.new(seed)
local raid=R3.ensure(approach,false)
assert(Work.initializeVillage(approach))
local west=approach.buildings[4]
west.state="ruined"
west.ruined=true
west.health=0
west.progress=0
local east,warehouse=approach.buildings[5],approach.buildings[2]
local warehouseHealth=warehouse.health
table.insert(raid.enemies,{id=1,x=-30,hp=30,side=-1,loot=0,attackClock=0,typeId="raider"})
raid.raidActive=true
for _=1,50 do R3.step(approach,0.1,80) end
assert(raid.enemies[1].x<=warehouse.x+1,"raider passed the exposed warehouse")
assert(warehouse.health<warehouseHealth,"western breach did not redirect the raid to exposed stock")
assert(east.state=="complete" and east.health==Structures.get("wall").health)
