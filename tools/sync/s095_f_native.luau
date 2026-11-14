do
local result={passed=false,noPlaceWrites=true}
local folder=Instance.new("Folder");folder.Name="S095_F_Probe";folder.Parent=workspace
local template=game:GetService("AssetService"):LoadAssetAsync(76960331636475)
local ok,err=pcall(function()
 local world=World.new(workspace,Grid,Rules,4)
 local function fixture(id,faction,prey,pos,damage)
  local m=Instance.new("Model");m.Name=id;m.Parent=folder
  local p=Instance.new("Part");p.Name="Body";p.Size=Vector3.new(1.5,2,1.5);p.Anchored=true;p.CanCollide=false;p.CanQuery=true;p.Position=pos;p.Parent=m
  local a={id=id,faction=faction,prey=prey,alive=true,damage=damage,model=m,health=20,hunger=1,hits=0}
  a.getPosition=function()return p.Position end
  a.healthRatio=function()return a.health/20 end
  a.applyDamage=function(n,source)a.health=math.max(0,a.health-n);a.hits+=1;a.lastSource=source;a.alive=a.health>0 end
  a.move=function(pos)p.Position=pos;World.update(world,id)end
  World.register(world,a);return a
 end
 local predator=Profiles.get("Predator");local melee=Profiles.get("Melee");local ranged=Profiles.get("Ranged")
 local hunter=fixture("hunter","hunter",false,Vector3.new(0,150,0),5);hunter.profile="Predator"
 local prey=fixture("prey","prey",true,Vector3.new(2.3,150,0),0)
 local nonprey=fixture("nonprey","npc",false,Vector3.new(0,150,2.2),0)
 local ally=fixture("ally","hunter",true,Vector3.new(0,150,-2.2),0)
 local candidates=World.candidates(world,hunter,predator)
 assert(Targets.choose(candidates,hunter.faction,predator,nil,24).id=="prey")
 assert(not World.attack(world,"hunter","nonprey",predator,1,0))
 assert(not World.attack(world,"hunter","ally",predator,1,0))
 assert(World.attack(world,"hunter","prey",predator,1,0) and prey.health==15)
 assert(not World.attack(world,"hunter","prey",predator,1,2))
 assert(not World.attack(world,"hunter","prey",predator,2,.5))
 result.predator={preyHealth=prey.health,nonPreyHealth=nonprey.health,allyHealth=ally.health,duplicateRejected=true}
 hunter.damage=20;assert(World.attack(world,"hunter","prey",predator,2,2) and not prey.alive and hunter.hunger<.4)
 result.predator.satiated=true;result.predator.hunger=hunter.hunger
 -- Exercise the actual shared runtime / combat adapter, including cancellation on loss of LOS.
 local swordsman=fixture("swordsman","swordsman",false,Vector3.new(40,150,0),4)
 local target=fixture("target","target",false,Vector3.new(42.8,150,0),0)
 local base={aiEnabled=true,stats={walkSpeed=2,runSpeed=4},mesh={Size=Vector3.new(1,2,1)},lastClip=""}
 function base:position()return swordsman.getPosition()end
 function base:animate(name,speed)self.lastClip=name end
 function base:cancel()end
 function base:destroy()end
 function base:ground(x,z)return Vector3.new(x,150,z)end
 function base:route()return true end
 function base:moveToward(g,speed,dt)swordsman.move(g);return true end
 function base:plan()return self:position()+Vector3.new(-3,0,0)end
 local combat=CombatAdapter.new(base,swordsman,melee,world,World,Targets)
 local agent=Agent.new(Brain.withProfile(melee),Kernel,combat)
 local first=Agent.step(agent,.1);assert(first.intent.state=="Windup")
 local wall=Instance.new("Part");wall.Size=Vector3.new(.3,5,5);wall.Position=Vector3.new(41.4,150,0);wall.Anchored=true;wall.Parent=folder
 local interrupted=Agent.step(agent,.5);assert(interrupted.intent.state=="Search" and target.health==20)
 wall:Destroy()
 assert(Agent.step(agent,.1).intent.state=="Windup")
 local attack=Agent.step(agent,.5);assert(attack.intent.state=="Attack" and target.health==16)
 Agent.act(agent,.1);assert(target.health==16)
 assert(Agent.step(agent,.1).intent.state=="Recover")
 result.melee={windup=first.intent.state,interrupted=interrupted.intent.state,health=target.health,recovery=true}
 -- Actual projectile raycasts, collision after launch, and a hard global projectile cap.
 local archer=fixture("archer","archer",false,Vector3.new(80,150,0),6)
 local victim=fixture("victim","victim",false,Vector3.new(96,150,0),0)
 assert(World.attack(world,"archer","victim",ranged,1,0) and #world.projectiles==1 and victim.health==20)
 for i=1,12 do World.step(world,.05) end
 assert(victim.health==14 and #world.projectiles==0,"projectile failed")
 assert(World.attack(world,"archer","victim",ranged,2,2))
 local cover=Instance.new("Part");cover.Size=Vector3.new(1,8,8);cover.Position=Vector3.new(88,151,0);cover.Anchored=true;cover.Parent=folder
 for i=1,12 do World.step(world,.05) end
 assert(victim.health==14 and #world.projectiles==0,"cover failed")
 assert(not World.attack(world,"archer","victim",ranged,3,4),"LOS attack not rejected")
 cover:Destroy()
 local rb=Brain.withProfile(ranged);local rm=rb.new()
 local close=rb.step(rm,{dt=.1,alive=true,aiEnabled=true,healthRatio=1,hunger=1,targetId="victim",targetAlive=true,targetVisible=true,targetDistance=3,pathBlocked=false,atGoal=false})
 assert(close.state=="Retreat")
 result.ranged={health=victim.health,coverBlocked=true,closeState=close.state,projectileCount=#world.projectiles}
 -- Real Chicken V2 on the current native terrain, predator sensed at a non-player velocity.
 local chicken=template:Clone();chicken.Parent=folder
 local species=Registry.get("210080")
 local a=Adapter.new(workspace,chicken,species,Escape,{contains=function(x,z)return x>=-384 and x<384 and z>=-384 and z<384 end,materials={[Enum.Material.Grass]=true,[Enum.Material.Ground]=true},random=function()return .5 end})
 local start=nil
 for z=-96,96,8 do
  for x=-96,96,8 do local g=a:ground(x,z);if g and a:route(g,g+Vector3.new(0,0,6)) and a:route(g,g+Vector3.new(6,0,0)) then start=g;break end end
  if start then break end
 end
 assert(start and a:place(start),"no safe native fixture")
 local realActor={id="realChicken",model=chicken,faction=species.faction,prey=true,profile=species.profile,alive=true,damage=0,getPosition=function()return a.mesh.Position end,healthRatio=function()return 1 end,applyDamage=function()end}
 local real=Factory.new({profiles=Profiles,brain=Passive,combatBrain=Brain,agent=Agent,kernel=Kernel,combatWorld=World,combatAdapter=CombatAdapter,targetSelector=Targets},species,a,realActor,world)
 assert(world.actors.realChicken==realActor)
 hunter.move(start+Vector3.new(0,1.3,6))
 local threat=World.predatorNear(world,start,22);assert(threat and threat.predator)
 result.predator.actualThreat=true
 a:setThreat(threat);local state=Agent.step(real,.1);assert(state.intent.state=="Flee")
 local before=a:position();for i=1,15 do Agent.step(real,.1) end
 local after=a:position();local gain=(after-threat.position).Magnitude-(before-threat.position).Magnitude
 assert(gain>.4,"prey did not escape predator")
 result.chicken={state=state.intent.state,escapeGain=gain,moved=(after-before).Magnitude,groundError=math.abs(after.Y-a:ground(after.X,after.Z).Y)}
 World.remove(world,"realChicken");Agent.destroy(real)
 result.queries=world.queries;result.passed=true
end)
result.ok=ok;if not ok then result.error=tostring(err):sub(1,500) end
folder:Destroy();template:Destroy()
return syncResult(result)
end
