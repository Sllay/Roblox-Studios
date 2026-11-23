--!strict
-- Deterministic T1-R2 domain regression executed by standalone Luau VM.
local Base="../places/main/src/ReplicatedStorage/"
local I=require("../places/main/src/ReplicatedStorage/Living/Inventory")
local Items=require("../places/main/src/ReplicatedStorage/Living/ItemDefs")
local P=require("../places/main/src/ReplicatedStorage/Living/ProfessionDefs")
local D=require("../places/main/src/ReplicatedStorage/Living/StructureDefs")
local S=require("../places/main/src/ReplicatedStorage/Living/LivingModel")
local W=require("../places/main/src/ReplicatedStorage/Living/WorkEngine")
local Slots=require("../places/main/src/ReplicatedStorage/SlotModel")
local World=require("../places/main/src/ReplicatedStorage/WorldProfile")

assert(Items.get("wood").mass==2)
assert(Items.get("stone").mass==3)
assert(Items.get("iron").mass==4)
assert(Items.get("food").mass==1)
assert(P.gatherYield("carpenter","wood")==3)
assert(P.gatherYield("miner","stone")==3)
assert(P.buildRate("builder")==2)
assert(P.buildRate("common")==1)
assert(D.get("shelter").cost.wood==8)
assert(D.get("stockpile").storageMass>=100)

local one=I.new(12)
local two=I.new(8)
assert(I.add(one,"wood",4))
assert(I.weight(one)==8)
assert(not I.add(one,"iron",2))
assert(not I.take(one,"stone",1))
assert(not I.transfer(one,two,"wood",5))
assert(I.transfer(one,two,"wood",3))
assert(I.weight(one)==2 and I.weight(two)==6)
assert(I.transfer(one,two,"wood",1)) -- exact remaining capacity is allowed
assert(I.weight(two)==8)
assert(not I.add(two,"food",1)) -- now full by mass
assert(I.count(one,"wood")==0 and I.count(two,"wood")==4)
assert(I.valid(one) and I.valid(two))
assert(not I.valid({maxMass=1,items={wood=2}}))
assert(not I.valid({maxMass=40,items={fake=1}}))
assert(Items.register("test_twine",{mass=0.1,stack=8,label="Twine"}))
assert(Items.get("test_twine").mass==0.1)
assert(not Items.register("test_twine",{mass=1,stack=8,label="duplicate"}))

local seed=516639272
local old=Slots.newWorld(seed,100,World.spawn(seed))
assert(Slots.validWorld(old))
assert(old.living==nil)
local living=S.restore(old.living,seed)
assert(living~=nil and S.valid(living))
assert(#living.npcs==4 and #living.sites>=4)
old.living=S.clone(living)
assert(Slots.validWorld(old))
local clone=S.clone(old.living)
clone.sites[1].remaining=0
assert(old.living.sites[1].remaining>0) -- no shared mutable nested bags
assert(S.restore(clone,seed)~=nil)
assert(S.restore(old.living,seed+1)==nil)
old.living.version=999
assert(not Slots.validWorld(old)) -- fail closed on unknown population revision
old.living=nil
assert(Slots.validWorld(old)) -- original R1 save remains valid

-- Preview the caller's coordinate without assigning another site or writing
-- state. Confirmation must agree and reject duplicate/overlapping orders.
local planned=S.new(seed)
assert(W.canPlace(planned,"shelter",18))
assert(#planned.buildings==0 and planned.nextBuildingId==1)
local builtFirst,firstBlueprint=W.place(planned,"shelter",18)
assert(builtFirst and firstBlueprint.x==18)
assert(not W.place(planned,"shelter",18))
assert(not W.canPlace(planned,"shelter",17))
assert(W.canPlace(planned,"shelter",0))
assert(not W.canPlace(planned,"shelter",76))
assert(not W.canPlace(planned,"shelter",105)) -- opposite bank without a route
assert(not W.canPlace(planned,"shelter",-42)) -- live harvestable tree
assert(not W.canPlace(planned,"shelter",999))
assert(not W.canPlace(planned,"invalid",18))
assert(not W.canPlace(planned,"shelter",0/0))
local persisted=S.restore(S.clone(planned),seed)
assert(persisted and persisted.buildings[1].x==18)
assert(W.cancel(persisted,firstBlueprint.id))
assert(not W.cancel(persisted,firstBlueprint.id))
assert(W.canPlace(persisted,"shelter",18))

for _,worldSeed in ipairs({1,42,1009,870001,516639272,123456789,2147483646}) do
    local village=S.new(worldSeed)
    assert(W.initializeVillage(village))
    assert(village.buildings[1].typeId=="castle")
    assert(W.usableStorage(village.buildings[2]) and W.usableStorage(village.buildings[3]))
    assert(village.buildings[4].x<0 and village.buildings[5].x>0)
    local savedVillage=S.restore(village,worldSeed)
    assert(savedVillage and not W.initializeVillage(savedVillage))
    assert(#savedVillage.buildings==#village.buildings)
end
assert(not W.initializeVillage(planned),"legacy settlement must be retained")
print("ENTRE_REINOS_T1_F1_PLACEMENT: chosen coordinate, footprint, worker access and seeded village")

local state=S.new(seed)
-- v13 UX: the village UI may only show real finite resource custody.
local initial=W.summary(state)
assert(initial.resources.sources.wood==144)
assert(initial.resources.sources.stone==132)
assert(initial.resources.sources.iron==40)
assert(initial.resources.sources.food==70)
assert(initial.resources.carried.wood==0)
assert(initial.resources.reserved.wood==0)
assert(initial.resources.committed.wood==0)
assert(W.place(state,"invalid",12)==false)
assert(W.place(state,"shelter",76)==false) -- river / slope
assert(W.place(state,"shelter",999)==false)
local good,b=W.place(state,"shelter",18)
assert(good and b.typeId=="shelter")
assert(W.place(state,"shelter",18)==false)
assert(b.progress==0 and b.delivered.wood==nil)
local beforeWood=0
local beforeStone=0
for _,site in ipairs(state.sites) do
    if site.item=="wood" then beforeWood+=site.remaining end
    if site.item=="stone" then beforeStone+=site.remaining end
end
for i=1,4500 do W.step(state,0.1) end
assert(b.state=="complete", "NPC workers must finish the real blueprint")
assert(b.progress==D.get("shelter").buildSeconds)
assert(b.delivered.wood==D.get("shelter").cost.wood)
assert(b.delivered.stone==D.get("shelter").cost.stone)
assert(state.stats.delivered==11,"no duplicate material delivery")
assert(state.stats.built==1,"one building completion per building")
local snapshot=W.summary(state)
assert(snapshot.resources.sources.wood<=144 and snapshot.resources.sources.stone<=132)
assert(snapshot.resources.committed.wood==8 and snapshot.resources.committed.stone==3)
assert(snapshot.resources.sources.wood+snapshot.resources.carried.wood+
    snapshot.resources.committed.wood<=144,"UI material ledger must conserve wood")
assert(snapshot.resources.sources.stone+snapshot.resources.carried.stone+
    snapshot.resources.committed.stone<=132,"UI material ledger must conserve stone")
local wood=0
local stone=0
for _,site in ipairs(state.sites) do
    assert(site.remaining>=0)
    if site.item=="wood" then wood+=site.remaining end
    if site.item=="stone" then stone+=site.remaining end
end
assert(beforeWood-wood>=8 and beforeStone-stone>=3)
for _,npc in ipairs(state.npcs) do
    assert(I.valid(npc.inventory),"bag always mass bounded")
    assert(npc.health>0)
end
assert(S.valid(state))
local saved=S.clone(state)
local reopened=S.restore(saved,seed)
assert(reopened and reopened.stats.delivered==11)
assert(reopened.buildings[1].state=="complete")
assert(reopened.sites[1].remaining==saved.sites[1].remaining)
assert(W.damage(reopened,1,24))
assert(reopened.buildings[1].state=="damaged")
for i=1,500 do W.step(reopened,0.1) end
assert(reopened.buildings[1].state=="complete")
assert(reopened.stats.repaired>=1)
assert(reopened.stats.built==1,"repair must not increment construction completion")
-- A complete galpão creates a real autonomous logistics cycle with
-- finite sources, bags, storage and recipes, not virtual map-wide crafting.
local warehouseWorld=S.new(seed)
local started,warehouse=W.place(warehouseWorld,"stockpile",18)
assert(started)
warehouseWorld.sites[1].marked=true
assert(W.summary(warehouseWorld).resources.markedTrees==1)
for i=1,5000 do W.step(warehouseWorld,0.1) end
assert(warehouse.state=="complete","warehouse must be truly finished first")
assert(I.valid(warehouse.stored))
local inventory=I.count(warehouse.stored,"wood")
assert(inventory>=2,"idle NPCs must actually deliver spare wood to the galpão")
local summaryBefore=W.summary(warehouseWorld)
local totalWood=summaryBefore.resources.sources.wood+
    summaryBefore.resources.carried.wood+
    summaryBefore.resources.committed.wood+
    summaryBefore.resources.stored.wood
assert(totalWood==144,"no wooden resources may be minted by warehouse")
local R3=require("../places/main/src/ReplicatedStorage/Living/R3Engine")
local d=R3.ensure(warehouseWorld,false)
local ammo=d.arrows
assert(R3.craftArrows(warehouseWorld,warehouse.x))
assert(I.count(warehouse.stored,"wood")==inventory-2)
assert(d.arrows==ammo+6)
local after=W.summary(warehouseWorld)
assert(after.resources.stored.wood==inventory-2)
assert(after.resources.sources.wood+after.resources.carried.wood+
    after.resources.committed.wood+after.resources.stored.wood==142,
    "crafting may consume exactly two stored pieces and nothing else")
local reload=S.restore(S.clone(warehouseWorld),seed)
assert(reload and I.valid(reload.buildings[1].stored))
assert(reload.buildings[1].stored.items.wood==inventory-2)
local damaged=S.clone(warehouseWorld)
damaged.buildings[1].stored.maxMass=1
assert(not S.valid(damaged),"invalid stored mass must fail closed")
print("ENTRE_REINOS_T1_R3_STOCK: marked timber, deposit, crafting and saved inventories passed")

print("ENTRE_REINOS_T1_R2: weighted atomic transfer, professions, finite sites, deliveries, build, repair, save/load passed")

-- Exhausted natural sources must not strand a funded village. Persist an
-- active reservation, deliver it once, and conserve the entire stock.
local logistics=S.new(seed)
for _,site in ipairs(logistics.sites) do site.remaining=0 end
local sourcePlaced,depot=W.place(logistics,"stockpile",-15)
assert(sourcePlaced)
depot.state="complete"
depot.progress=D.get("stockpile").buildSeconds
depot.delivered={wood=10,stone=6}
assert(I.add(depot.stored,"wood",8) and I.add(depot.stored,"stone",3))
local targetPlaced,target=W.place(logistics,"shelter",15)
assert(targetPlaced)
W.step(logistics,0.1)
assert(target.claimed.wood and target.claimed.wood>0)
assert(W.stockAvailable(logistics,depot,"wood")<8)
local resumed=S.restore(logistics,seed)
assert(resumed and resumed.npcs[1].storageId==depot.id)
local function total(state: any, item: string): number
    local resources=W.summary(state).resources
    return resources.sources[item]+resources.carried[item]+resources.stored[item]+
        resources.committed[item]+resources.isolated[item]
end
for _=1,1200 do
    W.step(resumed,0.1)
    assert(total(resumed,"wood")==18 and total(resumed,"stone")==9)
end
assert(resumed.buildings[2].state=="complete")
assert(resumed.stats.delivered==11 and resumed.stats.gathered==0)
assert(I.count(resumed.buildings[1].stored,"wood")==0)
assert(S.valid(resumed))

-- Two workers and the player's requests cannot spend the same four units.
local contested=S.new(seed)
for _,site in ipairs(contested.sites) do site.remaining=0 end
local placedDepot,contestedDepot=W.place(contested,"stockpile",-12)
assert(placedDepot)
contestedDepot.state="complete"
assert(I.add(contestedDepot.stored,"wood",4))
assert(W.place(contested,"shelter",15))
W.step(contested,0.1)
assert(W.stockAvailable(contested,contestedDepot,"wood")==0)
R3.ensure(contested,false)
assert(not R3.craftArrows(contested,contestedDepot.x))
assert(not R3.takeWood(contested,contestedDepot.x,contestedDepot.y+3))
assert(not R3.trade(contested,"wood",contestedDepot.x))
assert(I.count(contestedDepot.stored,"wood")==4)

-- Migration v15: stocks stranded in destroyed buildings are preserved in
-- an isolated account. Reopening again or rebuilding cannot duplicate them.
contestedDepot.state="ruined"
contestedDepot.ruined=true
local migrated=S.restore(contested,seed)
assert(migrated and migrated.buildings[1].ruinedStock.wood==4)
assert(contestedDepot.stored.items.wood==4,"restore never modifies the input record")
assert(migrated.buildings[1].stored.items.wood==nil)
migrated.buildings[1].state="complete"
migrated.buildings[1].ruined=false
local rebuilt=S.restore(migrated,seed)
assert(rebuilt and rebuilt.buildings[1].ruinedStock.wood==4)
assert(W.stockAvailable(rebuilt,rebuilt.buildings[1],"wood")==0)
assert(W.summary(rebuilt).resources.isolated.wood==4)
print("ENTRE_REINOS_T1_F1_STOCK: finite warehouse supply, reservation across reload, conservation and ruin isolation")

local cancelling=S.new(seed)
local timberSite=cancelling.sites[1]
timberSite.marked=true
local placed,blueprint=W.place(cancelling,"shelter",18)
assert(placed)
W.step(cancelling,0.1)
assert(blueprint.claimed.wood and blueprint.claimed.wood>0)
assert(W.cancel(cancelling,blueprint.id))
assert(W.sourceAvailable(cancelling,timberSite)==timberSite.remaining)
assert(#cancelling.buildings==0 and cancelling.nextBuildingId==2)
local placedAgain,replacement=W.place(cancelling,"shelter",18)
assert(placedAgain and replacement.id~=blueprint.id)
for _=1,800 do
    W.step(cancelling,0.1)
    if next(replacement.delivered) then break end
end
assert(next(replacement.delivered))
assert(not W.cancel(cancelling,replacement.id),"delivered materials must not disappear")
print("ENTRE_REINOS_T1_F1_CANCEL: abort releases reservations without losing or minting materials")

local marked=S.new(seed)
local made,markedDepot=W.place(marked,"stockpile",-15)
assert(made)
markedDepot.state="complete"
assert(I.add(markedDepot.stored,"wood",24)) -- ordinary stocking target already met
local orderedTree=marked.sites[2]
marked.sites[1].remaining=10
orderedTree.remaining=4
orderedTree.marked=true
local savedOrder=S.restore(marked,seed)
assert(savedOrder and savedOrder.sites[2].marked==true)
for _=1,850 do W.step(savedOrder,0.1) end
assert(savedOrder.sites[2].remaining==0 and savedOrder.sites[1].remaining==10)
assert(I.count(savedOrder.buildings[1].stored,"wood")==28)
print("ENTRE_REINOS_T1_F1_TREES: marked tree restores, gets priority and supplies the depot beyond routine stock")
