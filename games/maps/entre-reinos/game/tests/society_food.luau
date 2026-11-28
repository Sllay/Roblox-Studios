--!strict
local Living=require("../places/main/src/ReplicatedStorage/Living/LivingModel")
local Work=require("../places/main/src/ReplicatedStorage/Living/WorkEngine")
local Needs=require("../places/main/src/ReplicatedStorage/Living/VillageNeeds")
local Production=require("../places/main/src/ReplicatedStorage/Living/Production")
local Inventory=require("../places/main/src/ReplicatedStorage/Living/Inventory")
local Structures=require("../places/main/src/ReplicatedStorage/Living/StructureDefs")
local state=Living.new(516639272)
state.npcs={state.npcs[1]}
state.sites={}
local worker=state.npcs[1]
local function finished(id: number,kind: string,x: number)
    local def=Structures.get(kind)
    return {id=id,typeId=kind,x=x,y=14,state="complete",progress=def.buildSeconds,health=def.health,
        delivered={},claimed={},stored=Inventory.new(math.max(1,def.storageMass))}
end
local farm=finished(1,"farm",0)
local storage=finished(2,"stockpile",-15)
local shop=finished(3,"workshop",15)
state.buildings={farm,storage,shop}
state.nextBuildingId=4
worker.x,worker.z=0,-4.4
Production.ensure(state)
Needs.seedLandscape(state,0)
-- This fixture isolates cooked food from the concurrent renewable orchard.
for index,site in ipairs(state.sites) do
    if site.id=="forage_orchard" then table.remove(state.sites,index);break end
end
assert(Work.changeProfession(state,worker,"farmer"))
assert(Inventory.add(worker.inventory,"grain",1))
assert(Inventory.add(storage.stored,"wood",3))
for _=1,800 do
    Work.step(state,0.1)
    if farm.plot.stage=="grow" then break end
end
assert(farm.plot.stage=="grow" and Inventory.count(worker.inventory,"grain")==0)
assert(Living.valid(state))
for _=1,1600 do
    Work.step(state,0.1)
    if Inventory.count(storage.stored,"food")>0 then break end
end
assert(Inventory.count(storage.stored,"food")>0,"harvest must enter the food chain")
assert(worker.skills.farm>=6)
worker.hunger=95
for _=1,450 do
    Work.step(state,0.1)
    if worker.hunger<70 then break end
end
assert(worker.hunger<70,"resident must actually walk to and eat food")
assert(Living.restore(state,state.seed))

local animals=state.production.fauna
assert(#animals>=2 and #animals<=6)
Work.changeProfession(state,worker,"hunter")
if #animals>2 then
    for _=1,2400 do
        Work.step(state,0.1)
        if worker.skills.hunt then break end
    end
    assert(worker.skills.hunt>=8,"resident must pursue and finish a real hunt")
    assert(Inventory.count(worker.inventory,"meat")+Inventory.count(storage.stored,"meat")>=2)
end
assert(#animals>=2)
print("ENTRE_REINOS_T2_R2_FOOD: seed debit, growth, harvest, cooking, hunger, fauna and reload passed")
