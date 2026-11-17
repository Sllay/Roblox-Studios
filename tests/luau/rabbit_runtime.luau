--!strict
-- S09.10: genuine shared ecological runtime, no duplicate AI or event system.
local root="../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/"
local Registry=require(root.."CreatureRegistry")
local Fauna=require(root.."FaunaService")
local Gameplay=require(root.."BookGameplay")
local Profiles=require(root.."WildlifeProfiles")
local Spawn=require(root.."SpawnPolicy")
local Brain=require(root.."MobBrain")
local Kernel=require(root.."AIKernel")

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
print("Rabbit S09.10 native-independent species/Book/spawn/AI contract PASS")
