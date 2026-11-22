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

-- v11: choose the closest valid free plot, without touching the saved
-- work world until the order is actually accepted.
local planned=S.new(seed)
local okSite,siteX=W.findPlacement(planned,"shelter",18)
assert(okSite and siteX==18)
assert(#planned.buildings==0 and planned.nextBuildingId==1)
local builtFirst,firstBlueprint=W.place(planned,"shelter",siteX)
assert(builtFirst and firstBlueprint.x==18)
local pickedAgain,nextX=W.findPlacement(planned,"shelter",18)
assert(pickedAgain and math.abs(nextX-firstBlueprint.x)>=D.get("shelter").footprint+2)
assert(#planned.buildings==1 and planned.nextBuildingId==2,
    "search must never create a construction or charge resources")
local builtSecond,secondBlueprint=W.place(planned,"shelter",nextX)
assert(builtSecond and secondBlueprint.x~=firstBlueprint.x)
assert(not W.canPlace(planned,"shelter",18))
assert(W.findPlacement(planned,"shelter",999)==false)
assert(W.findPlacement(planned,"invalid",18)==false)
assert(W.findPlacement(planned,"shelter",0/0)==false)
local persisted=S.restore(S.clone(planned),seed)
assert(persisted and #persisted.buildings==2)
local foundBefore,candidateBefore=W.findPlacement(planned,"house",18)
local foundAfter,candidateAfter=W.findPlacement(persisted,"house",18)
assert(foundBefore==foundAfter and candidateBefore==candidateAfter,
    "plot search must remain deterministic across save/load")
for _,b in ipairs(planned.buildings) do
    assert(b.progress==0 and next(b.delivered)==nil)
end
print("ENTRE_REINOS_V11_PLOTS: server-only nearest free site, overlap, no side effects and save/load passed")

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
print("ENTRE_REINOS_T1_R2: weighted atomic transfer, professions, finite sites, deliveries, build, repair, save/load passed")
