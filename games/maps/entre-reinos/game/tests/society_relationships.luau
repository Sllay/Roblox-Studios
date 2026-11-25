--!strict
local Living=require("../places/main/src/ReplicatedStorage/Living/LivingModel")
local Work=require("../places/main/src/ReplicatedStorage/Living/WorkEngine")
local Social=require("../places/main/src/ReplicatedStorage/Living/Social")
local Inventory=require("../places/main/src/ReplicatedStorage/Living/Inventory")
local Production=require("../places/main/src/ReplicatedStorage/Living/Production")
local state=Living.new(516639272)
assert(Work.initializeVillage(state))
Production.ensure(state)
local a,b=state.npcs[1],state.npcs[2]
local bag=Inventory.new(12)
assert(Inventory.add(bag,"plank",1) and Inventory.add(bag,"food",1))
assert(Social.interact(state,a,"talk",bag,Work))
assert(Social.interact(state,a,"talk",bag,Work) and a.social.trust==1)
assert(Social.interact(state,a,"gift",bag,Work) and Inventory.count(a.inventory,"plank")==1)
assert(not Social.interact(state,a,"gift",bag,Work) and a.social.trust==5)
a.hunger=75
state.elapsed=50
assert(Social.interact(state,a,"help",bag,Work))
assert(a.hunger==40 and a.social.trust==12 and Inventory.count(bag,"food")==0)
a.underAttack=true
assert(Social.interact(state,a,"rescue",bag,Work))
assert(a.social.trust==12)
a.underAttack=false
for _=1,100 do Work.step(state,0.1) end
assert(a.social.trust==21 and a.social.memories[#a.social.memories].kind=="rescue")
a.x,b.x=a.x,a.x+2
a.state="idle"
a.z,b.z=-4.4,-4.4
a.social.care,a.social.nextHelp=100,0
b.hunger=90
assert(Inventory.add(a.inventory,"food",1))
Social.stepResident(state,a,0.1,Work)
assert(Inventory.count(b.inventory,"food")==1 and b.social.links[1].id==a.id)
local restored=assert(Living.restore(state,state.seed))
assert(restored.npcs[1].social.trust==21 and restored.npcs[2].social.links[1].trust==5)
print("ENTRE_REINOS_T2_R2_SOCIAL: proximity-domain aid, bounded memory, rescue arrival and restoration passed")
