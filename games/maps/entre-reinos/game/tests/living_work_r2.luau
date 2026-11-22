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
assert(not I.transfer(one,two,"wood",1))
assert(I.count(one,"wood")==1 and I.count(two,"wood")==3)
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

local state=S.new(seed)
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
