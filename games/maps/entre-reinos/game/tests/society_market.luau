--!strict
local Living=require("../places/main/src/ReplicatedStorage/Living/LivingModel")
local Work=require("../places/main/src/ReplicatedStorage/Living/WorkEngine")
local Routes=require("../places/main/src/ReplicatedStorage/RegionalCrossings")
local Production=require("../places/main/src/ReplicatedStorage/Living/Production")
local Market=require("../places/main/src/ReplicatedStorage/Living/Market")
local Inventory=require("../places/main/src/ReplicatedStorage/Living/Inventory")
local R3=require("../places/main/src/ReplicatedStorage/Living/R3Engine")
local seed=516639272
local graph=Routes.compile(seed)
local crossing=graph.crossings[3]
local function town(x: number,foreign: boolean): any
    local city=Living.new(seed)
    if not foreign then R3.ensure(city,false) end
    city.sites={}
    city.npcs={city.npcs[1]}
    local npc=city.npcs[1]
    npc.id=if foreign then 1001 else 1
    npc.x,npc.z=x,-4.4
    npc.profession="carrier"
    city.buildings={
        {id=1,typeId="stockpile",x=x,y=14,state="complete",progress=30,health=150,
            stored=Inventory.new(250),delivered={},claimed={}},
        {id=2,typeId="castle",x=x+(if foreign then 18 else -18),y=14,state="complete",progress=80,
            health=840,delivered={},claimed={}},
    }
    city.nextBuildingId=3
    Production.ensure(city)
    Market.ensure(city)
    return city
end
local home=town(crossing.west.x-10,false)
local foreign=town(crossing.east.x+10,true)
local session={home=home,record={foreign=foreign,discovered={["2"]=true}}}
local bridges={}
Work.bindRegion(home,graph,0,function()return bridges end)
Work.bindRegion(foreign,graph,foreign.npcs[1].x,function()return bridges end)
local stock=home.buildings[1].stored
local receiving=foreign.buildings[1].stored
assert(Inventory.add(stock,"wood",12))
assert(Inventory.add(home.r3.playerBag,"wood",1))
local treasury=Market.treasury(home)
assert(Market.playerTrade(home,home.r3,"a1","sell","wood",Work))
local newPrice=Market.quote(home,"wood",Work).buy
assert(Inventory.count(stock,"wood")==13 and home.r3.wallet>0)
assert(Market.playerTrade(home,home.r3,"a1","sell","wood",Work))
assert(Inventory.count(stock,"wood")==13 and home.r3.wallet+Market.treasury(home)==treasury)
assert(newPrice>=2)
assert(not Market.openContract(session,"home","wood",4,"a2",Work))
local placed,pile=Work.place(home,"bridge_reinforced",crossing.west.x+1)
assert(placed)
pile.state="complete"
table.insert(bridges,pile)
local coins=Market.treasury(home)+Market.treasury(foreign)
assert(Market.openContract(session,"home","wood",4,"a2",Work))
for _=1,400 do
    Market.stepFreight(session,0.1,Work)
    local c=home.production.market.contract
    if c and c.stage=="delivery" then break end
end
local stored=home.production.market.contract
assert(stored.stage=="delivery" and Inventory.count(stored.cargo,"wood")==4)
pile.state="ruined"
for _=1,90 do Market.stepFreight(session,0.1,Work) end
assert(Inventory.count(receiving,"wood")==0 and Inventory.count(stored.cargo,"wood")==4)
assert(Living.valid(home) and Living.valid(foreign))
pile.state="complete"
for _=1,550 do
    Market.stepFreight(session,0.1,Work)
    if not home.production.market.contract then break end
end
assert(not home.production.market.contract and Inventory.count(receiving,"wood")==4)
assert(Inventory.count(stock,"wood")==9 and Market.treasury(home)+Market.treasury(foreign)==coins)
assert(Market.openContract(session,"home","wood",4,"a2",Work))
assert(not home.production.market.contract)
home.elapsed=240
Market.payroll(home)
assert(home.npcs[1].coins==1)
local remaining=Market.treasury(home)
Market.payroll(home)
assert(Market.treasury(home)==remaining)
print("ENTRE_REINOS_T2_R2_MARKET: finite trade, escrow, bridge interruption, delivery, retry and payroll passed")
