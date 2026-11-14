--!strict
-- Combat agent shares the ground/animation adapter; target data comes from bounded CombatWorld.
local C={}
function C.new(base:any,actor:any,profile:any,world:any,worldModule:any,selector:any):any
 local self:any={base=base,actor=actor,profile=profile,world=world,current=nil,lastKnown=nil,clock=0,goal=nil,nextPlan=0,blocked=false,lastAttackToken=0}
 function self:sense(dt:number):any
  self.clock+=dt;worldModule.update(world,actor.id)
  local candidates=worldModule.candidates(world,actor,profile)
  local best=selector.choose(candidates,actor.faction,profile,self.current,24)
  if best then self.current=best.id;self.lastKnown=world.actors[best.id].getPosition() end
  local target=if best then world.actors[best.id] else nil
  return {dt=dt,alive=actor.alive,aiEnabled=base.aiEnabled,healthRatio=actor.healthRatio(),hunger=actor.hunger or 1,targetId=if best then best.id else nil,targetAlive=target~=nil and target.alive,targetVisible=best~=nil,targetDistance=if best then best.distance else math.huge,pathBlocked=self.blocked,atGoal=false,attackAcknowledged=self.lastAttackToken}
 end
 function self:cancel() self.goal=nil;self.nextPlan=0;base:cancel() end
 function self:enter(intent:any)
  self:cancel();self.blocked=false
  if intent.state=="Dead" or intent.state=="Static" then base:animate("",1) else base:animate(intent.animation,1) end
 end
 function self:plan(intent:any):Vector3?
  local p=base:position();local t=world.actors[intent.targetId or ""]
  local target=if intent.action=="Search" then self.lastKnown elseif t then t.getPosition() else self.lastKnown
  if not target then return nil end
  local delta=Vector3.new(target.X-p.X,0,target.Z-p.Z);if delta.Magnitude<.01 then return nil end
  if intent.action=="Retreat" then base.observedThreat={position=target};return base:plan(true) end
  local desired=if intent.action=="Position" then profile.idealRange else math.max(1,profile.idealRange*.85)
  local best=nil;local score=-math.huge
  for i=0,7 do
   local a=math.rad(i*45);local u=delta.Unit
   local dir=Vector3.new(u.X*math.cos(a)-u.Z*math.sin(a),0,u.X*math.sin(a)+u.Z*math.cos(a))
   local distance=math.clamp(delta.Magnitude-desired,1.5,6)
   if intent.action=="Position" and math.abs(delta.Magnitude-desired)<3 then distance=3 end
   local q=p+dir*distance;local g=base:ground(q.X,q.Z)
   if g and base:route(p,g) then
    local value=-math.abs((g-target).Magnitude-desired)
    if t and worldModule.visibleFrom(world,g+Vector3.new(0,base.mesh.Size.Y/2,0),t,actor.model) then value+=5 end
    if value>score then best=g;score=value end
   end
  end
  return best
 end
 function self:execute(intent:any,dt:number):string
  if intent.action=="AttackMelee" or intent.action=="AttackRanged" then
   if intent.attackToken>self.lastAttackToken then
    self.lastAttackToken=intent.attackToken
    worldModule.attack(world,actor.id,intent.targetId,profile,intent.attackToken,self.clock)
   end
   return "Success"
  end
  if intent.action=="Approach" or intent.action=="Retreat" or intent.action=="Position" or intent.action=="Search" then
   local p=base:position()
   if self.goal and (self.goal-p).Magnitude<.25 then self.goal=nil end
   if self.clock>=self.nextPlan and (not self.goal or intent.action~="Search") then self.goal=self:plan(intent);self.nextPlan=self.clock+1 end
   if not self.goal then self.blocked=true;return "Running" end
   local speed=if intent.animation=="Run" then base.stats.runSpeed else base.stats.walkSpeed
   self.blocked=not base:moveToward(self.goal,speed,dt)
   if self.blocked then self.goal=nil end
  end
  return "Running"
 end
 function self:destroy()worldModule.remove(world,actor.id);base:destroy()end
 return self
end
return table.freeze(C)
