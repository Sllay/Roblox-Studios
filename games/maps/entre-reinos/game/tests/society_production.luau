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

local requestState=Living.new(516639272)
requestState.sites={}
local receiver,other=requestState.npcs[1],requestState.npcs[2]
requestState.npcs={receiver,other}
receiver.x,receiver.z=-23,-4.4
other.x,other.z=-27,-4.4
requestState.buildings={finished(1,"stockpile",-12),finished(2,"workshop",0),finished(3,"forge",12)}
requestState.nextBuildingId=4
Production.ensure(requestState)
assert(not Production.enqueue(requestState,"planks",12,3))
assert(Inventory.add(requestState.buildings[1].stored,"spear",1))
assert(Work.orderGear(requestState,receiver,"spear") and Work.orderGear(requestState,other,"spear"))
Work.step(requestState,0.1)
assert(receiver.defense==nil and receiver.gearDepot==1 and other.gearDepot==nil)
assert(Work.stockAvailable(requestState,requestState.buildings[1],"spear")==0)
requestState=assert(Living.restore(requestState,requestState.seed))
for _=1,200 do Work.step(requestState,0.1) end
assert(requestState.npcs[1].defense=="spear" and requestState.npcs[2].defense==nil)
assert(Inventory.count(requestState.buildings[1].stored,"spear")==0 and Living.valid(requestState))
print("ENTRE_REINOS_V20_GEAR: one reserved spear retrieved on foot after restore")

local Crowd=require("../places/main/src/ReplicatedStorage/Living/Crowd")
local queue=Living.new(516639272)
for _,worker in ipairs(queue.npcs) do worker.x,worker.z=0,0 end
local first,second,third,fourth=queue.npcs[1],queue.npcs[2],queue.npcs[3],queue.npcs[4]
local stands={0,-2.15,2.15}
assert(Crowd.stand(queue,first,1,stands)==0)
assert(Crowd.stand(queue,second,1,stands)==-2.15)
assert(Crowd.stand(queue,third,1,stands)==2.15)
assert(Crowd.stand(queue,fourth,1,stands)==nil)
assert(Crowd.stand(queue,second,1,stands)==-2.15)
Crowd.release(queue,first)
assert(Crowd.stand(queue,fourth,1,stands)==0)
print("ENTRE_REINOS_V20_CROWD: distinct service points and queue release")
