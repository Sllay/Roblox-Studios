--!strict
local Living=require("../places/main/src/ReplicatedStorage/Living/LivingModel")
local Work=require("../places/main/src/ReplicatedStorage/Living/WorkEngine")
local Profile=require("../places/main/src/ReplicatedStorage/RegionalProfile")
local Regions=require("../places/main/src/ReplicatedStorage/RegionalWorld")
local Slots=require("../places/main/src/ReplicatedStorage/SlotModel")
local R3=require("../places/main/src/ReplicatedStorage/Living/R3Engine")
local Market=require("../places/main/src/ReplicatedStorage/Living/Market")
local Inventory=require("../places/main/src/ReplicatedStorage/Living/Inventory")
local seed=516639272
local home=Living.new(seed)
R3.ensure(home,false)
assert(Work.initializeVillage(home))
local session=assert(Regions.new(seed,home,nil,Profile.spawn(seed),function(x) return math.abs(x)<170 end))
local town=assert(Profile.settlement(seed,2))
local cedro=Regions.activate(session,town.x)
Regions.activate(session,0)
assert(cedro~=home)
local start=os.clock()
for _=1,1600 do
    Work.step(home,0.1)
    Regions.stepEconomy(session,home,0.1)
end
local simulationMs=(os.clock()-start)*1000
assert(math.abs(home.elapsed-160)<0.1 and math.abs(cedro.elapsed-160)<0.1)
assert(cedro.npcs[1].id==1001 and cedro.stats.gathered>0,"offscreen kingdom must move and work")
assert(cedro.production.stewardPlanned)
assert(Market.diplomacy(session,"trade"))
local amount=Market.treasury(home)+Market.treasury(cedro)
assert(Market.diplomacy(session,"tribute") and not Market.diplomacy(session,"tribute"))
assert(Market.treasury(home)+Market.treasury(cedro)==amount)
assert(not Market.diplomacy(session,"alliance"))
home.elapsed+=91
assert(Market.diplomacy(session,"tribute"))
assert(Market.diplomacy(session,"alliance") and Market.relations(session).accord=="alliance")
assert(Market.diplomacy(session,"withdraw") and Market.relations(session).accord==nil)
local worker=home.npcs[1]
Work.releaseWorker(home,worker)
assert(Work.setOrder(home,worker,"stock"))
assert(not Work.setOrder(home,worker,"not-a-job"))
local originX=worker.x
local beforeStock=Inventory.count(cedro.buildings[2].stored,"wood")
local slot=Slots.newWorld(seed,100,Profile.spawn(seed))
slot.living=Living.clone(home)
slot.regionWorld=Regions.snapshot(session)
slot.rulesetVersion=5
assert(Slots.validWorld(slot))
slot.rulesetVersion=4
assert(not Slots.validWorld(slot),"old ruleset must never contain society state")
slot.rulesetVersion=5
local resumed=assert(Regions.new(seed,slot.living,slot.regionWorld,slot.position))
assert(resumed.home.npcs[1].order=="stock" and resumed.home.npcs[1].x==originX)
assert(resumed.home.elapsed==home.elapsed and resumed.record.foreign.elapsed==cedro.elapsed)
assert(Regions.activate(resumed,town.x).npcs[1].id==cedro.npcs[1].id)
assert(Inventory.count(resumed.record.foreign.buildings[2].stored,"wood")==beforeStock)
print(string.format("ENTRE_REINOS_T2_R2_REGIONS: two populations, 160 seconds each, detached work and reload, %.2f ms",simulationMs))
