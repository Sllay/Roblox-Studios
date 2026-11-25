--!strict
local Living=require("../places/main/src/ReplicatedStorage/Living/LivingModel")
local Work=require("../places/main/src/ReplicatedStorage/Living/WorkEngine")
local Profile=require("../places/main/src/ReplicatedStorage/RegionalProfile")
local Regions=require("../places/main/src/ReplicatedStorage/RegionalWorld")
local R3=require("../places/main/src/ReplicatedStorage/Living/R3Engine")
local seed=516639272
local home=Living.new(seed)
R3.ensure(home,false)
assert(Work.initializeVillage(home))
local session=assert(Regions.new(seed,home,nil,Profile.spawn(seed),function(x) return math.abs(x)<170 end))
local town=assert(Profile.settlement(seed,2))
local cedro=Regions.activate(session,town.x)
Regions.activate(session,0)
assert(cedro~=home)

for _,kind in ipairs({"workshop","farm"}) do
    local placed=false
    for x=22,104 do
        if Work.place(home,kind,x) or Work.place(home,kind,-x) then placed=true;break end
    end
    assert(placed)
end
for step=1,24000 do
    Work.step(home,0.1)
    Regions.stepEconomy(session,home,0.1)
    if step%6000==0 then
        assert(Living.valid(home) and Living.valid(cedro))
    end
end
for _,realm in ipairs({home,cedro}) do
    local farm,shop=false,false
    for _,b in ipairs(realm.buildings) do
        farm=farm or (b.typeId=="farm" and b.state=="complete")
        shop=shop or (b.typeId=="workshop" and b.state=="complete")
    end
    assert(farm and shop)
    for _,n in ipairs(realm.npcs) do assert(n.health>0 and n.hunger<100) end
end
print("ENTRE_REINOS_T2_R2_SOAK: both towns survived 2,400 simulated seconds")
