--!strict
-- S09.10: genuine shared ecological runtime, no duplicate AI or event system.
local Registry=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/CreatureRegistry")
local Fauna=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/FaunaService")
local Gameplay=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/BookGameplay")
local Profiles=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/WildlifeProfiles")
local Spawn=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/SpawnPolicy")
local Brain=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/MobBrain")
local Kernel=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/AIKernel")

local chicken=assert(Registry.get("210080"))
local rabbit=assert(Registry.get("210081"))
assert(Registry.validate(chicken) and Registry.validate(rabbit))
assert(#Registry.all()==2 and rabbit.animations.Death=="113737115841702")
assert(Profiles.rabbit.groupKind=="Solo" and Profiles.rabbit.groupMax==1)
assert(Spawn.rabbit.maximum==8 and Spawn.rabbit.initial==4 and Spawn.rabbit.allowedMaterials.Grass)

local one={speciesId="210080",id="chicken-a"}
local two={speciesId="210081",id="rabbit-b"}
local directorChicken={p={speciesId="210080"},agents={["chicken-a"]=one}}
local directorRabbit={p={speciesId="210081"},agents={["rabbit-b"]=two}}
local service={director=directorChicken,directors={directorChicken,directorRabbit}}
assert(Fauna.find(service,"rabbit-b")==directorRabbit)
local d,record=Fauna.find(service,"chicken-a")
assert(d==directorChicken and record==one)
assert(Fauna.find(service,"missing")==nil)
assert(Fauna.forSpecies(service,"210081")==directorRabbit)

local calls={}
local persistence={discover=function(_,uid,id,reason,origin,at)
 table.insert(calls,{uid=uid,id=id,reason=reason,origin=origin,at=at})
 return true
end}
local aliveModel={SetAttribute=function()end}
local rabbitActor={adapter={alive=true,model=aliveModel,damage=function()end},health=16,origin="Natural",speciesId="210081"}
directorRabbit.agents["rabbit-b"]=rabbitActor
local event=Gameplay.new({},persistence,service,function()return true end)
assert(Gameplay.interact(event,{UserId=123},"rabbit-b",10,100))
assert(calls[1].id=="210081" and calls[1].reason=="Interaction")
assert(not Gameplay.interact(event,{UserId=123},"rabbit-b",10.1,101),"Interaction rate limit")
local removed=nil
local directorModule={remove=function(target,id)
 removed={target=target,id=id};target.agents[id]=nil;return true
end}
assert(Gameplay.damage(event,directorModule,"rabbit-b",16,123,11,101))
assert(removed and removed.target==directorRabbit and removed.id=="rabbit-b")
assert(calls[2].id=="210081" and calls[2].reason=="Kill")

local memory=Brain.new()
local base={dt=.1,alive=true,aiEnabled=true,hit=false,threatVisible=true,
 threatDistance=8,approachSpeed=3,approachThreshold=9.6,predator=false,
 jumping=false,actionComplete=false,foodConsumed=false,foodAvailable=false,
 atFood=false,pathBlocked=false,escapeAvailable=false,stuck=false,random=.5}
assert(Brain.step(memory,base,Kernel.canInterrupt).state=="Idle")
base.jumping=true
assert(Brain.step(memory,base,Kernel.canInterrupt).state=="Flee")
-- A rabbit's longer idle permits a grooming one-shot to finish naturally.
-- Survival must still interrupt a cosmetic action in the same tick.
local groom=Brain.new()
local calm=table.clone(base)
calm.dt=2
calm.threatVisible=false
calm.hit=false
calm.jumping=false
calm.predator=false
calm.routineFood=false
calm.routineFlap=false
calm.idleSeconds=3.25
calm.exploreSeconds=9.5
calm.cosmeticActionPlaying=true
assert(Brain.step(groom,calm,Kernel.canInterrupt).state=="Idle")
assert(Brain.step(groom,calm,Kernel.canInterrupt).state=="Idle","Groom must finish before leaving idle")
calm.cosmeticActionPlaying=false
assert(Brain.step(groom,calm,Kernel.canInterrupt).state=="Explore")
for _=1,5 do Brain.step(groom,calm,Kernel.canInterrupt) end
assert(groom.state=="Idle","Rabbit routine must return for another grooming chance")
calm.cosmeticActionPlaying=true
calm.threatVisible=true
calm.predator=true
calm.threatDistance=2
assert(Brain.step(groom,calm,Kernel.canInterrupt).state=="Flee","Danger must interrupt any grooming")

-- Chicken/other species retain the original idle duration by default.
local normal=Brain.new()
local regular=table.clone(calm)
regular.threatVisible=false
regular.predator=false
regular.cosmeticActionPlaying=nil
regular.idleSeconds=nil
regular.exploreSeconds=nil
assert(Brain.step(normal,regular,Kernel.canInterrupt).state=="Explore","Default idle stays two seconds")

print("Rabbit S09.10 native-independent species/Book/spawn/AI contract PASS")
