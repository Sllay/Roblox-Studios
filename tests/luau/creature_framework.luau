--!strict
local R=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/CreatureRegistry")
local B=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/BookCore")
local M=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/MobBrain")
local Q=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/SimulationBudget")
local S=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/SummonPlan")
local c=assert(R.get("210080"));assert(R.validate(c) and #R.all()==1)
assert(R.stats(c,10,false).health==20 and R.stats(c,10,true).health==34)
assert(R.previewStats(c).level10.damage==0)
assert(not pcall(function()R.stats(c,11,true)end))
assert(not pcall(function()c.name="changed" end))
local a=B.new();assert(not B.discover(a,{speciesId=c.id,reason="Kill",at=10,verified=false,origin="Natural"},true))
assert(not B.discover(a,{speciesId=c.id,reason="Kill",at=10,verified=true,origin="Developer"},true))
assert(B.discover(a,{speciesId=c.id,reason="Interaction",at=20,verified=true,origin="Natural"},true))
assert(not B.discover(a,{speciesId=c.id,reason="Kill",at=21,verified=true,origin="Natural"},true))
local b=B.new();assert(B.discover(b,{speciesId=c.id,reason="Kill",at=10,verified=true,origin="Natural"},true))
local merged=B.merge(a,b);assert(merged.mobs[c.id].firstAt==10)
local n,total,p=B.progress(merged,{c});assert(n==1 and total==1 and p==100)
assert(B.publicRow(c,false).id==nil and B.publicRow(c,true).id==c.id)
assert(#B.ordered(merged,{c},"Discovery")==1)
local m=M.new()
local sense:M.Sense={dt=.1,alive=true,aiEnabled=true,hit=false,threatVisible=true,threatDistance=6,approachSpeed=.1,predator=false,foodAvailable=false,atFood=false,pathBlocked=false,escapeAvailable=true,stuck=false,random=.5}
assert(M.step(m,sense).state=="Idle")
sense.approachSpeed=5;assert(M.step(m,sense).state=="Flee")
sense.pathBlocked=true;sense.escapeAvailable=false;assert(M.step(m,sense).state=="Recover")
sense.pathBlocked=false;sense.escapeAvailable=true;sense.hit=true;assert(M.step(m,sense).state=="Flee")
sense.hit=false;sense.threatVisible=false;sense.dt=1
assert(M.step(m,sense).state=="Flee");assert(M.step(m,sense).state=="Flee");assert(M.step(m,sense).state=="Idle")
sense.aiEnabled=false;assert(M.step(m,sense).state=="Static")
sense.alive=false;assert(M.step(m,sense).state=="Dead")
local slots:{Q.Slot}={};for i=1,10000 do slots[i]={id=tostring(i),tier="Near",due=0} end
local cursor=1;local seen:{[string]:boolean}={}
for i=1,100 do
 local out,nextCursor,checks=Q.take(slots,cursor,0,200,100);cursor=nextCursor
 assert(#out==100 and checks==100)
 for _,id in out do assert(not seen[id]);seen[id]=true end
end
assert(cursor==1 and Q.tier(54,"Near")=="Near" and Q.tier(56,"Near")=="Mid")
assert(S.parse({"mob",c.id,"3","here","true"},false,true,10)==nil)
assert(S.parse({"mob",c.id,"21","here","true"},true,true,100)==nil)
local plan=assert(S.parse({"mob",c.id,"3","here","false"},true,true,10));assert(plan.count==3 and not plan.aiEnabled and plan.origin=="Developer")
local at=assert(S.parse({"mob",c.id,"2","1","2","3","true"},true,true,10));assert(at.position and at.position[2]==2)
print("S09.5 core: registry, levels, Book, passive decisions, 10000-slot scheduler and summon policy passed")
