do
local result={noPlaceWrites=true,passed=false}
local folder=Instance.new("Folder");folder.Name="S095_F_Probe";folder.Parent=workspace
local state=World.new(workspace,Grid,Rules,16)
local actors={}
local function actor(id,faction,pos,prey,damage)
 local m=Instance.new("Model");m.Name=id;m.Parent=folder
 local part=Instance.new("Part");part.Size=Vector3.new(1.2,2,1.2);part.Anchored=true;part.CanQuery=true;part.Position=pos;part.Parent=m
 local a={id=id,faction=faction,model=m,alive=true,damage=damage,prey=prey,health=20,hunger=1,profile="Fixture"}
 a.getPosition=function()return part.Position end
 a.healthRatio=function()return a.health/20 end
 a.applyDamage=function(n)a.health=math.max(0,a.health-n);a.alive=a.health>0 end
 actors[id]=a
 local base={aiEnabled=true,mesh=part,stats={walkSpeed=2,runSpeed=4},lastClip=""}
 function base:animate(n)self.lastClip=n end
 function base:cancel()end
 function base:destroy()m:Destroy()end
 function base:position()return part.Position end
 function base:ground(x,z)return Vector3.new(x,pos.Y,z)end
 function base:route()return true end
 function base:moveToward(g,speed,dt)
  local delta=g-part.Position;if delta.Magnitude>.01 then part.Position+=delta.Unit*math.min(delta.Magnitude,speed*dt) end;return true
 end
 function base:plan()return part.Position-Vector3.new(5,0,0)end
 return a,base
end
local ok,err=pcall(function()
 local melee=assert(Profiles.get("Melee"));local ranged=assert(Profiles.get("Ranged"));local predator=assert(Profiles.get("Predator"))
 local a,base=actor("melee","enemy",Vector3.new(-80,100,-80),false,5)
 local t=actor("target","players",Vector3.new(-77.5,100,-80),false,0)
 World.register(state,t)
 local deps={profiles=Profiles,brain=Passive,combatBrain=Brain,agent=Agent,kernel=Kernel,combatWorld=World,combatAdapter=Adapter,targetSelector=Targets}
 local agent=Factory.new(deps,{profile="Melee"},base,a,state)
 local first=Agent.step(agent,.1);assert(first.intent.state=="Windup" and t.health==20)
 for _=1,8 do Agent.step(agent,.1) end
 assert(t.health==15,"melee damage not exactly once")
 result.meleeDamage=20-t.health
 assert(not World.attack(state,a.id,t.id,melee,1,10) and t.health==15)
 local wall=Instance.new("Part");wall.Name="Wall";wall.Anchored=true;wall.CanQuery=true;wall.Size=Vector3.new(.5,6,5);wall.Position=Vector3.new(-78.75,100,-80);wall.Parent=folder
 assert(not World.attack(state,a.id,t.id,melee,2,10) and t.health==15,"melee through wall")
 wall:Destroy()
 result.meleeBlocked=true
 local r,rb=actor("archer","enemy",Vector3.new(-40,100,-80),false,7)
 local rt=actor("rangedtarget","players",Vector3.new(-24,100,-80),false,0)
 World.register(state,rt)
 local ar=Factory.new(deps,{profile="Ranged"},rb,r,state)
 for _=1,9 do Agent.step(ar,.1) end
 assert(#state.projectiles==1 and rt.health==20,"ranged did not launch")
 for _=1,20 do World.step(state,.05) end
 assert(rt.health==13 and #state.projectiles==0,"arrow hit failed")
 result.rangedDamage=20-rt.health
 assert(World.attack(state,r.id,rt.id,ranged,2,10))
 local shield=Instance.new("Part");shield.Name="ArrowBlocker";shield.Anchored=true;shield.CanQuery=true;shield.Size=Vector3.new(1,25,8);shield.Position=Vector3.new(-32,100,-80);shield.Parent=folder
 for _=1,20 do World.step(state,.05) end
 assert(rt.health==13 and #state.projectiles==0,"arrow crossed obstacle")
 result.rangedBlocked=true;shield:Destroy()
 local wolf=actor("wolf","predator",Vector3.new(10,100,-80),false,6);wolf.profile="Predator";World.register(state,wolf)
 local prey=actor("prey","animal",Vector3.new(18,100,-80),true,0);World.register(state,prey)
 local other=actor("other","players",Vector3.new(11,100,-77),false,0);World.register(state,other)
 local chosen=Targets.choose(World.candidates(state,wolf,predator),wolf.faction,predator,nil,24)
 assert(chosen and chosen.id=="prey","predator selected nonprey")
 assert(not World.attack(state,wolf.id,other.id,predator,1,10))
 local sensed=World.predatorNear(state,prey.getPosition(),22)
 assert(sensed and sensed.predator)
 result.preySelected=chosen.id;result.predatorSensed=true
 result.queries=state.queries;result.passed=true
 Agent.destroy(agent);Agent.destroy(ar)
end)
result.ok=ok;if not ok then result.error=tostring(err):sub(1,500) end
folder:Destroy()
return syncResult(result)
end
