--!strict
local R=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/CreatureRegistry")
local B=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/BookCore")
local M=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/MobBrain")
local Q=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/SimulationBudget")
local S=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/SummonPlan")
local c=assert(R.get("210080"));assert(R.validate(c) and #R.all()==1)
assert(c.preview.assetId=="107933673393998" and R.biomeName("emerald_valley")=="Vale Esmeralda" and not R.levelsEnabled)
assert(R.stats(c,10,false).health==20 and R.stats(c,10,true).health==34)
assert(R.previewStats(c).level10.damage==0)
assert(not pcall(function()R.stats(c,11,true)end))
assert(not pcall(function()c.name="changed" end))
local a=B.new();assert(not B.discover(a,{speciesId=c.id,reason="Kill",at=10,verified=false,origin="Natural"},c))
assert(not B.discover(a,{speciesId=c.id,reason="Kill",at=10,verified=true,origin="Developer"},c))
assert(B.discover(a,{speciesId=c.id,reason="Interaction",at=20,verified=true,origin="Natural"},c))
assert(not B.discover(a,{speciesId=c.id,reason="Kill",at=21,verified=true,origin="Natural"},c))
local b=B.new();assert(B.discover(b,{speciesId=c.id,reason="Kill",at=10,verified=true,origin="Natural"},c))
local merged=B.merge(a,b);assert(merged.mobs[c.id].firstAt==10)
local n,total,p=B.progress(merged,{c});assert(n==1 and total==1 and p==100)
local public=assert(R.bookRow(c.id,false));local developer=assert(R.bookRow(c.id,true))
assert(public.id==nil and developer.id==c.id and public.previewAssetId==c.preview.assetId and public.stats.level10.health==34 and public.biomes[1]=="Vale Esmeralda")
assert(R.bookRow("999999",false)==nil)
local ave=table.clone(c);ave.id="345678";ave.name="Ave"
local other=B.new();assert(B.discover(other,{speciesId=c.id,reason="Interaction",at=100,verified=true,origin="Natural"},c))
local discovered,total,pct=B.progress(other,{c,ave});assert(discovered==1 and total==2 and pct==50)
assert(not B.discover(other,{speciesId=ave.id,reason="Kill",at=200,verified=true,origin="Natural"},c))
assert(B.discover(other,{speciesId=ave.id,reason="Interaction",at=200,verified=true,origin="Natural"},ave))
assert(B.ordered(other,{c,ave},"Discovery")[1].id==c.id and B.ordered(other,{c,ave},"Alphabetical")[1].id==ave.id)
assert(not B.discover(other,{speciesId="999999",reason="Kill",at=300,verified=true,origin="Natural"},nil))
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

local K=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/AIKernel")
local E=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/EscapePlanner")
local board:K.Blackboard={ticks=0,cancelled=0,log={}}
local node:K.Node={id="root",kind="Sequence",children={
 {id="check",kind="Action",tick=function(b,dt) b.check=(b.check or 0)+1;return "Success" end},
 {id="move",kind="Action",tick=function(b,dt) b.ticks+=1;return if b.ticks>=2 then "Success" else "Running" end,cancel=function(b)b.cancelled+=1 end}
}}
assert(K.validate(node))
local mem=K.memory();local mem2=K.memory()
assert(K.tick(node,mem,board,.1,10)=="Running")
assert(K.tick(node,mem,board,.1,10)=="Success" and board.check==1)
board.ticks=0;assert(K.tick(node,mem,board,.1,10)=="Running");K.abort(node,mem,board);assert(board.cancelled==1)
assert(K.tick(node,mem2,board,.1,1)=="Running" and board.check==2)
local selector:K.Node={id="s",kind="Selector",children={{id="bad",kind="Action",tick=function()return "Failure" end},{id="good",kind="Action",tick=function()return "Success" end}}}
assert(K.validate(selector) and K.tick(selector,K.memory(),board,0,10)=="Success")
local states:{[string]:K.State}={
 Alive={enter=function(b)table.insert(b.log,"+Alive")end,exit=function(b)table.insert(b.log,"-Alive")end},
 Routine={parent="Alive",enter=function(b)table.insert(b.log,"+Routine")end,exit=function(b)table.insert(b.log,"-Routine")end},
 Flee={parent="Alive",enter=function(b)table.insert(b.log,"+Flee")end,exit=function(b)table.insert(b.log,"-Flee")end},
 Dead={enter=function(b)table.insert(b.log,"+Dead")end}
}
local machine=K.machine(states,board);assert(K.transition(machine,"Routine"));assert(K.transition(machine,"Flee"));assert(not K.transition(machine,"Flee"));assert(K.transition(machine,"Dead"))
assert(table.concat(board.log,",")=="+Alive,+Routine,-Routine,+Flee,-Flee,-Alive,+Dead")
local a:E.Candidate={id="trap",walkable=true,wet=false,blocked=false,deadEnd=true,clearance=1,slope=0,threatDistance=30,routeLength=10,concealment=1,escapeOptions=0}
local b:E.Candidate={id="safe",walkable=true,wet=false,blocked=false,deadEnd=false,clearance=1,slope=10,threatDistance=20,routeLength=9,concealment=.8,escapeOptions=2}
assert(E.choose({a,b},5,2)==b and E.choose({a},5,1)==nil)
print("S09.5 AI kernel: BT execution/cancellation, hierarchy enter/exit and safe escape scoring passed")

local P=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/PopulationBudget")
local pm=P.new({global=4,active=2,perChunk=2,perBiome={emerald_valley=4},perSpecies={["210080"]=4}})
assert(P.reserve(pm,"a","210080","emerald_valley","0:0",true,0,5))
assert(P.commit(pm,"a",1))
assert(P.reserve(pm,"b","210080","emerald_valley","0:0",true,0,5))
assert(not P.reserve(pm,"c","210080","emerald_valley","0:0",false,0,5))
assert(not P.reserve(pm,"c","210080","emerald_valley","1:0",true,0,5))
assert(P.reserve(pm,"c","210080","emerald_valley","1:0",false,0,5))
assert(P.commit(pm,"c",1));assert(not P.setActive(pm,"c",true))
assert(P.expire(pm,"b",5) and not P.expire(pm,"a",5))
assert(P.setActive(pm,"c",true) and pm.active==2)
assert(P.move(pm,"c","emerald_valley","0:0") and pm.chunks["emerald_valley/0:0"]==2)
assert(P.setActive(pm,"a",false) and pm.active==1)
assert(P.release(pm,"a") and not P.release(pm,"a") and pm.total==1)
assert(P.release(pm,"c") and pm.total==0 and pm.active==0)
print("S09.5 population: reservations, caps, expiration, materialization and release passed")

local SP=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/SpawnPolicy")
local BI=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/BiomeRegions")
local FO=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/FoodSites")
local clock=SP.new();local policy=SP.chicken
for n=0,14 do assert(SP.next(clock,policy,n,n));SP.result(clock,policy,n+1,n,true) end
assert(not SP.next(clock,policy,15,15))
assert(not SP.next(clock,policy,12,20) and clock.due==320)
assert(not SP.next(clock,policy,12,319.99))
assert(SP.next(clock,policy,12,320));SP.result(clock,policy,13,320,true)
assert(clock.due==620 and not SP.next(clock,policy,13,619))
assert(SP.next(clock,policy,13,620));SP.result(clock,policy,13,620,false)
assert(not SP.next(clock,policy,13,624) and SP.next(clock,policy,13,625))
SP.result(clock,policy,14,625,true);assert(clock.due==925)
assert(SP.next(clock,policy,14,1000));SP.result(clock,policy,15,1000,true)
assert(clock.due==nil and not SP.next(clock,policy,15,2000))
assert(#BI.regions("emerald_valley")==9 and BI.regionAt("emerald_valley",-384,-384) and BI.regionAt("emerald_valley",384,0)==nil)
local fs=FO.new(2);assert(FO.claim(fs,"a","one",0));assert(not FO.claim(fs,"a","two",1))
assert(FO.consume(fs,"a","one",1) and not FO.consume(fs,"a","one",2));assert(not FO.claim(fs,"a","two",120));assert(FO.claim(fs,"a","two",121))
FO.release(fs,"a","two");FO.prune(fs,122,10);assert(fs.count==0)
print("S09.5-C: initial 15, serial 300s replenishment, retry/no burst, biome and food leases passed")

local BP=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/BookPersistence")
local BE=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/BookGameplay")
local db:any={u_1={schema=1,mobs={["345678"]={firstAt=1,reason="Kill"}}}}
local getFail=true;local writeFail=true;local writes=0
local store={canRead=function()return true end,canWrite=function()return true end,get=function(k)if getFail then error("read fail")end;return db[k] end,update=function(k,f)if writeFail then error("write fail")end;writes+=1;db[k]=f(db[k]);return db[k] end}
local book=BP.new(B,R,store);local session=BP.session(book,1)
assert(BP.discover(book,1,"210080","Interaction","Natural",20))
assert(not BP.load(book,session,0) and not session.ready and session.dirty)
assert(not BP.flush(book,session,0) and writes==0)
getFail=false;assert(BP.load(book,session,2) and session.ledger.mobs["345678"])
assert(not BP.flush(book,session,2) and session.dirty)
writeFail=false;assert(BP.flush(book,session,4) and db.u_1.mobs["210080"].firstAt==20 and db.u_1.mobs["345678"])
local b2=BP.new(B,R,store);local p2=BP.session(b2,1);assert(BP.load(b2,p2,0))
local snap=BP.snapshot(b2,1,"Alphabetical",false);assert(snap.ready and snap.discovered==1 and snap.percent==100 and snap.rows[1].id==nil and snap.rows[1].key=="entry_1")
assert(BP.snapshot(b2,1,"Discovery",true).rows[1].id=="210080")
-- Unknown schema is not overwritten.
db.u_2={schema=2,mobs={}};local p3=BP.session(book,2);assert(BP.discover(book,2,"210080","Kill","Natural",1));assert(not BP.load(book,p3,0) and not BP.flush(book,p3,0))
-- Discovery only via validated server event. Test hit/death once and no dev credit.
local model={SetAttribute=function()end}
local fakeDirector:any={agents={one={adapter={alive=true,model=model,damage=function()end},origin="Natural",speciesId="210080",health=20},dev={adapter={alive=true,model=model,damage=function()end},origin="Developer",speciesId="210080",health=20}}}
local allowed=false
local event=BE.new(book,BP,fakeDirector,function()return allowed end)
assert(not BE.interact(event,{UserId=3},"one",0,100))
allowed=true;assert(BE.interact(event,{UserId=3},"one",1,101));assert(not BE.interact(event,{UserId=3},"one",2,102))
assert(not BE.interact(event,{UserId=4},"dev",3,103))
local removals=0;local dm={remove=function(d,id,now)d.agents[id]=nil;removals+=1;return true end}
assert(BE.damage(event,dm,"one",5,4,3,104) and fakeDirector.agents.one.health==15)
assert(BE.damage(event,dm,"one",15,4,4,105) and removals==1)
assert(not BE.damage(event,dm,"one",1,4,5,106) and book.sessions[4].ledger.mobs["210080"].reason=="Kill")
assert(BE.damage(event,dm,"dev",20,5,6,107) and (not book.sessions[5] or not book.sessions[5].ledger.mobs["210080"]))
print("S09.5-D: safe persistence merge, load/write failure, reload, unknown schema, verified discovery/death passed")

local DP=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/DeveloperPolicy")
assert(DP.authorized(8136365379,8136365379,"User",{}) and not DP.authorized(10,8136365379,"User",{}) and not DP.authorized(8136365379,8136365379,"Group",{}))
assert(DP.tokens("/summon mob 210080 2 here false")[2]=="210080" and DP.tokens("/other mob")==nil and DP.tokens(string.rep("x",161))==nil)
print("S09.5-E developer authorization and command tokenization passed")

local CP=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/CombatProfiles")
local CB=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/CombatBrain")
local CT=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/CombatTargets")
local CG=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/CombatSpatialIndex")
local CR=require("../../games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/CombatRules")
local melee=assert(CP.get("Melee"));local ranged=assert(CP.get("Ranged"));local predator=assert(CP.get("Predator"))
local mb=CB.withProfile(melee);local mem=mb.new()
local cs:CB.Sense={dt=.1,alive=true,aiEnabled=true,healthRatio=1,hunger=1,targetId="target",targetAlive=true,targetVisible=true,targetDistance=10,pathBlocked=false,atGoal=false}
assert(mb.step(mem,cs).state=="Chase")
cs.targetDistance=2;assert(mb.step(mem,cs).state=="Windup")
cs.targetVisible=false;assert(mb.step(mem,cs).state=="Search" and mem.attackToken==0)
cs.targetVisible=true;assert(mb.step(mem,cs).state=="Windup")
cs.dt=.5;local strike=mb.step(mem,cs);assert(strike.state=="Attack" and strike.attackToken==1)
assert(mb.step(mem,cs).state=="Recover")
cs.healthRatio=.1;assert(mb.step(mem,cs).state=="Retreat")
cs.aiEnabled=false;assert(mb.step(mem,cs).state=="Static")
cs.alive=false;assert(mb.step(mem,cs).state=="Dead")
local rb=CB.withProfile(ranged);local rm=rb.new()
cs={dt=.1,alive=true,aiEnabled=true,healthRatio=1,hunger=1,targetId="target",targetAlive=true,targetVisible=true,targetDistance=3,pathBlocked=false,atGoal=false}
assert(rb.step(rm,cs).state=="Retreat")
cs.targetDistance=16;assert(rb.step(rm,cs).state=="Windup")
cs.dt=.7;assert(rb.step(rm,cs).action=="AttackRanged")
local pb=CB.withProfile(predator);local pmem=pb.new();cs.targetDistance=15;cs.hunger=.2
assert(pb.step(pmem,cs).state=="Idle");cs.hunger=.9;assert(pb.step(pmem,cs).state=="Stalk")
local candidates: {CT.Candidate}={{id="ally",faction="wolf",alive=true,prey=true,visible=true,distance=1,threat=0},{id="notprey",faction="npc",alive=true,prey=false,visible=true,distance=2,threat=0},{id="chicken",faction="bird",alive=true,prey=true,visible=true,distance=8,threat=0}}
assert(CT.choose(candidates,"wolf",predator,nil,3).id=="chicken")
local index=CG.new(32);for i=1,10000 do CG.upsert(index,tostring(i),i*4,0) end
local nearby,checks=CG.query(index,100,0,20,64,24);assert(#nearby==11 and checks<=64)
assert(CG.remove(index,"25"));local after=CG.query(index,100,0,20,64,24);assert(#after==10)
local attack=CR.new();local aa={id="a",faction="x",alive=true,damage=5};local tt={id="b",faction="y",alive=true,damage=0}
assert(not CR.authorize(attack,melee,aa,tt,1,0,2,false))
assert(CR.authorize(attack,melee,aa,tt,1,0,2,true))
assert(not CR.authorize(attack,melee,aa,tt,1,2,2,true))
assert(not CR.authorize(attack,melee,aa,tt,2,.5,2,true))
assert(CR.authorize(attack,melee,aa,tt,2,2,2,true))
assert(not CR.authorize(CR.new(),ranged,aa,tt,1,0,3,true))
print("S09.5-F: predator prey filter, melee/ranged states, windup interruption, cooldown, spatial index and attack dedup passed")
