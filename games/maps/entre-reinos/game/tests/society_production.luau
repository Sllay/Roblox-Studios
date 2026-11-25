--!strict
local Living=require("../places/main/src/ReplicatedStorage/Living/LivingModel")
local Work=require("../places/main/src/ReplicatedStorage/Living/WorkEngine")
local Production=require("../places/main/src/ReplicatedStorage/Living/Production")
local Inventory=require("../places/main/src/ReplicatedStorage/Living/Inventory")
local Structures=require("../places/main/src/ReplicatedStorage/Living/StructureDefs")

local state=Living.new(516639272)
state.npcs={state.npcs[1]}
state.sites={}
local npc=state.npcs[1]
npc.x,npc.z=-12,-4.4
local function finished(id: number,typeId: string,x: number)
    local def=Structures.get(typeId)
    return {id=id,typeId=typeId,x=x,y=16,state="complete",progress=def.buildSeconds,health=def.health,
        delivered={},claimed={},stored=Inventory.new(math.max(1,def.storageMass))}
end
local depot=finished(1,"stockpile",-12)
state.buildings={depot,finished(2,"workshop",0),finished(3,"forge",12)}
state.nextBuildingId=4
Production.ensure(state)
assert(Inventory.add(depot.stored,"wood",4))
assert(Inventory.add(depot.stored,"iron",2))
assert(Inventory.add(depot.stored,"hammer",1))
assert(Work.changeProfession(state,npc,"artisan"))
assert(not Work.changeProfession(state,npc,"made_up"))
assert(not Production.enqueue(state,"planks",56))
assert(Production.enqueue(state,"planks",0))
assert(Production.enqueue(state,"smelt",12))
for _=1,200 do
    Work.step(state,0.1)
    if state.production.orders[1] and state.production.orders[1].progress>1 then break end
end
assert(state.production.orders[1].progress>0)
assert(Inventory.count(npc.inventory,"wood")==2 and Inventory.count(depot.stored,"wood")==2)
state=assert(Living.restore(state,state.seed))
npc=state.npcs[1]
depot=state.buildings[1]
for _=1,1600 do
    Work.step(state,0.1)
    if state.production.completed==2 and Inventory.count(depot.stored,"metal")==2 then break end
end
assert(state.production.completed==2 and #state.production.orders==0)
assert(Inventory.count(depot.stored,"plank")==3 and Inventory.count(depot.stored,"metal")==2)
assert(Inventory.count(depot.stored,"iron")==0)
assert(Inventory.count(depot.stored,"wood")==1)
assert(npc.tool.item=="hammer" and npc.tool.remaining==14)
assert(Living.valid(state))
assert(Production.enqueue(state,"spear",12))
for _=1,500 do Work.step(state,0.1) end
assert(state.production.completed==3 and Inventory.count(depot.stored,"metal")==1)
assert(Inventory.count(depot.stored,"spear")+Inventory.count(npc.inventory,"spear")==1)
assert(Production.enqueue(state,"bow",0))
for _=1,400 do Work.step(state,0.1) end
assert(state.production.completed==3 and #state.production.orders==1)
print("ENTRE_REINOS_T2_R2_PRODUCTION: persisted craft, actual reagents, output, tool wear and missing input passed")
