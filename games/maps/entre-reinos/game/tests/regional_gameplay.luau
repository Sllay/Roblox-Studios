--!strict
local Profile=require("../places/main/src/ReplicatedStorage/RegionalProfile")
local Regions=require("../places/main/src/ReplicatedStorage/RegionalWorld")
local Routes=require("../places/main/src/ReplicatedStorage/RegionalCrossings")
local Slots=require("../places/main/src/ReplicatedStorage/SlotModel")
local Living=require("../places/main/src/ReplicatedStorage/Living/LivingModel")
local Work=require("../places/main/src/ReplicatedStorage/Living/WorkEngine")
local Inventory=require("../places/main/src/ReplicatedStorage/Living/Inventory")
local R3=require("../places/main/src/ReplicatedStorage/Living/R3Engine")

for _,seed in ipairs({1,42,1009,870001,123456789,516639272,2147483646}) do
    local slot:any=Slots.newWorld(seed,100,Profile.spawn(seed))
    local home=Living.new(seed)
    assert(Work.initializeVillage(home))
    slot.living=home
    assert(Slots.validWorld(slot))
    local session=assert(Regions.new(seed,home,nil,slot.position))
    local castleX=home.buildings[1].x
    assert(Regions.activate(session,0)==home and session.record.foreign==nil)
    local settlement=assert(Profile.settlement(seed,2))
    local capital=Regions.activate(session,settlement.x)
    assert(capital~=home and capital.npcs[1].id==1001 and #capital.buildings>=5)
    assert(capital.buildings[1].x==settlement.x and home.buildings[1].x==castleX)
    for _=1,750 do Work.step(capital,0.1) end
    assert((capital.stats.stored or 0)>0,"second settlement must really store materials")
    capital.npcs[2].health=0
    local elapsed=capital.elapsed
    local stock=Inventory.count(capital.buildings[2].stored,"wood")
    for _=1,4 do
        assert(Regions.activate(session,0)==home and session.phases[2]=="aggregated")
        local returned=Regions.activate(session,settlement.x)
        assert(returned==capital and returned.elapsed==elapsed and returned.npcs[2].health==0)
        assert(Inventory.count(returned.buildings[2].stored,"wood")==stock)
    end
    session.record.position={x=settlement.x,y=settlement.y+4,z=0}
    session.record.mount={id="horse:1",position={x=settlement.x,y=settlement.y,z=0},energy=66,health=75}
    session.record.rider="mount"
    slot.regionWorld=Regions.snapshot(session)
    slot.rulesetVersion=4
    assert(Slots.validWorld(slot) and Slots.spawnPosition(slot).x==settlement.x)
    local loaded=assert(Regions.new(seed,home,slot.regionWorld,Slots.spawnPosition(slot)))
    local reentered=Regions.activate(loaded,settlement.x)
    assert(reentered~=capital and reentered.npcs[1].id==capital.npcs[1].id and reentered.npcs[2].health==0)
    assert(loaded.record.mount.energy==66 and loaded.record.rider=="mount")
    slot.regionWorld.mount.id="other_rider"
    assert(not Slots.validWorld(slot))
end

local seed=516639272
local home=Living.new(seed)
home.npcs={home.npcs[3]}
home.sites={}
local npc=home.npcs[1]
local graph=Routes.compile(seed)
local bridge=graph.crossings[3]
assert(bridge.region==0 and bridge.buildable)
assert(Regions.new(seed,home,nil,Profile.spawn(seed)))
local west=bridge.west.x-5
local east=bridge.east.x+7
npc.x=west
local start=home.nextBuildingId
local store={id=start,typeId="stockpile",x=west-4,y=17,state="complete",progress=30,
    health=150,delivered={},claimed={},stored=Inventory.new(250)}
home.nextBuildingId+=1
table.insert(home.buildings,store)
assert(Inventory.add(store.stored,"wood",44))
assert(Inventory.add(store.stored,"stone",16))
local placed,work=Work.place(home,"bridge_light",bridge.west.x+1)
assert(placed)
assert(not Work.place(home,"bridge_light",bridge.east.x-1))
for _=1,4000 do
    Work.step(home,0.1)
    assert(npc.x<bridge.east.x)
    if work.state=="complete" then break end
end
assert(work.state=="complete" and work.delivered.wood==12)
assert(Work.deckAt(home,work.x,0,"worker"))
assert(not Work.deckAt(home,work.x,0,"mount"))
assert(Work.place(home,"bridge_reinforced",bridge.west.x+1))
for _=1,5500 do
    Work.step(home,0.1)
    if work.state=="complete" then break end
end
assert(work.state=="complete" and work.delivered.wood==20 and work.delivered.stone==12)
assert(Work.deckAt(home,work.x,0,"carrier"))
local incoming=Inventory.count(npc.inventory,"wood")
assert(Inventory.add(npc.inventory,"wood",math.max(1,2-incoming)))
for _=1,2500 do
    if Work.walkResident(home,npc,east,0.1,0) then break end
end
assert(npc.x>bridge.east.x,"loaded worker must reach the opposite bank through the deck")
R3.ensure(home,false)
assert(R3.damageStructure(home,work,270) and work.state=="ruined")
assert(not Work.deckAt(home,work.x,0,"carrier"))
for _=1,200 do assert(not Work.walkResident(home,npc,west,0.1,0)) end
assert(npc.x>bridge.east.x and Inventory.count(npc.inventory,"wood")>0)

R3.ensure(home,false)
home.r3.wallet=13
assert(R3.payTravel(home,12,"horse:1"))
assert(home.r3.wallet==1 and not R3.payTravel(home,12,"horse:1"))
print("ENTRE_REINOS_T2_R1_GAMEPLAY: regional custody, construction, crossing, reload and purchase passed")
