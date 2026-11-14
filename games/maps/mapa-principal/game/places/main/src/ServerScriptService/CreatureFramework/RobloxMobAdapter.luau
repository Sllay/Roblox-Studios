--!strict
-- Server kinematic ground locomotion for small grounded mobs. Bounded local route search.
-- Real Roblox queries; no terrain approximation used as a placement authority.
local D={}
local function horizontal(v:Vector3):Vector3 return Vector3.new(v.X,0,v.Z) end
local function finite(v:Vector3):boolean return v.X==v.X and v.Y==v.Y and v.Z==v.Z and v.Magnitude<1e6 end
function D.new(world:Workspace,model:Model,species:any,escape:any,options:any):any
 local mesh=assert(model:FindFirstChildWhichIsA("MeshPart",true)) :: MeshPart
 local ac=assert(model:FindFirstChildWhichIsA("AnimationController",true)) :: AnimationController
 local animator=ac:FindFirstChildWhichIsA("Animator") or Instance.new("Animator",ac)
 local self:any={peckConsumed=false,peckAge=0,actionAge=0,actionComplete=false,motionSpeed=0,world=world,model=model,mesh=mesh,animator=animator,escape=escape,options=options,tracks={},animations={},lastClip="",goal=nil,clock=0,nextPlan=0,blocked=false,stuck=false,hit=false,alive=true,aiEnabled=true,threat=nil,food=nil,stats=species.base,queries=0,routePlans=0,moveDistance=0}
 mesh.Anchored=true;mesh.CanCollide=false;mesh.CanTouch=false
 local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude;ray.FilterDescendantsInstances={model};ray.IgnoreWater=false
 local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.FilterDescendantsInstances={model};overlap.MaxParts=16;overlap.RespectCanCollide=true
 local groundRay=RaycastParams.new();groundRay.FilterType=Enum.RaycastFilterType.Include;groundRay.FilterDescendantsInstances={world.Terrain};groundRay.IgnoreWater=false
 self.ray=ray;self.overlap=overlap
 local half=mesh.Size.Y/2
 function self:ground(x:number,z:number):Vector3?
  if not self.options.contains(x,z) then return nil end
  self.queries+=1
  local hit=world:Raycast(Vector3.new(x,112,z),Vector3.new(0,-160,0),groundRay)
  if not hit or hit.Instance~=world.Terrain or hit.Material==Enum.Material.Water or hit.Normal.Y<math.cos(math.rad(35)) then return nil end
  if not self.options.materials[hit.Material] then return nil end
  local p=hit.Position
  self.queries+=1
  local parts=world:GetPartBoundsInBox(CFrame.new(p+Vector3.new(0,half+.15,0)),Vector3.new(math.max(mesh.Size.X,mesh.Size.Z)+.2,mesh.Size.Y-.2,math.max(mesh.Size.X,mesh.Size.Z)+.2),overlap)
  for _,part in parts do
   local owner=part:FindFirstAncestorOfClass("Model")
   local character=owner and owner:FindFirstChildWhichIsA("Humanoid")
   if part~=world.Terrain and part.CanCollide and not character then return nil end
  end
  return p
 end
 function self:route(from:Vector3,to:Vector3):boolean
  local distance=horizontal(to-from).Magnitude
  local n=math.max(1,math.ceil(distance/1.5))
  if n>8 then return false end
  local last=from
  for i=1,n do
   local v=from:Lerp(to,i/n);local g=self:ground(v.X,v.Z)
   if not g or math.abs(g.Y-last.Y)>.9 then return false end
   last=g
  end
  return true
 end
 function self:position():Vector3 return mesh.Position-Vector3.new(0,half,0) end
 function self:place(p:Vector3):boolean
  local g=self:ground(p.X,p.Z);if not g then return false end
  mesh.CFrame=CFrame.new(g+Vector3.new(0,half,0));return true
 end
 function self:setThreat(t:any) self.threat=t end
 function self:setFood(p:Vector3?) self.food=p end
 function self:damage(attacker:any?)
  self.hit=true
  if attacker then self.observedThreat=attacker;self.lastSeen=self.clock;self.damageThreat=attacker;self.damageUntil=self.clock+5 end
 end
 function self:sense(dt:number):any
  self.clock+=dt
  local p=self:position();local t=self.threat
  if self.options.threatProvider then t=self.options.threatProvider(p) end
  if self.damageThreat and self.clock<(self.damageUntil or 0) then
   local a=self.damageThreat
   if a.model and a.model.Parent then a.position=a.model:GetPivot().Position end
   t={position=a.position,velocity=a.velocity,model=a.model,predator=true}
  else self.damageThreat=nil end
  local dist=math.huge;local approach=0;local visible=false;local predator=false
  if t and finite(t.position) and finite(t.velocity) then
   local delta=t.position-(p+Vector3.new(0,half,0));dist=delta.Magnitude;predator=t.predator==true
   if dist>0 and dist<=30 then
    self.queries+=1
    local hit=world:Raycast(p+Vector3.new(0,half,0),delta,ray)
    visible=not hit or (t.model and hit.Instance:IsDescendantOf(t.model)) or (hit.Position-t.position).Magnitude<.3
    local flat=horizontal(delta)
    approach=if flat.Magnitude>.01 then -horizontal(t.velocity):Dot(flat.Unit) else 0
    if approach~=approach then approach=0 end
   end
  end
  if visible then self.observedThreat=t;self.lastSeen=self.clock elseif self.lastSeen and self.clock-self.lastSeen>4 then self.observedThreat=nil end
  local food=self.food
  local s={dt=dt,alive=self.alive,aiEnabled=self.aiEnabled,hit=self.hit,threatVisible=visible,threatDistance=dist,approachSpeed=approach,approachThreshold=if t and t.normalSpeed then math.max(1,t.normalSpeed*.6) else 4,predator=predator,jumping=t~=nil and t.jumping==true,actionComplete=self.actionComplete,foodConsumed=self.peckConsumed,foodAvailable=food~=nil,atFood=food~=nil and horizontal((food :: Vector3)-p).Magnitude<.8,pathBlocked=self.blocked,escapeAvailable=self.goal~=nil,stuck=self.stuck,random=self.options.random()}
  self.hit=false;return s
 end
 function self:animate(name:string,speed:number)
  if name==self.lastClip then
   local track=self.tracks[name];if track then track:AdjustSpeed(speed) end;return
  end
  local old=self.tracks[self.lastClip];if old then old:Stop(.2) end
  self.lastClip=name
  if name=="" then return end
  local track=self.tracks[name]
  if not track then
   local anim=Instance.new("Animation");anim.AnimationId="rbxassetid://"..species.animations[name]
   self.animations[name]=anim
   track=animator:LoadAnimation(anim);self.tracks[name]=track
   track.Looped=name=="Idle" or name=="Walk" or name=="Run"
  end
  track:Play(.18,1,speed)
 end
 function self:cancel() self.goal=nil;self.nextPlan=0 end
 function self:enter(intent:any)
  self.goal=nil;self.nextPlan=0;self.blocked=false;self.stuck=false;self.peckAge=0;self.peckConsumed=false;self.actionAge=0;self.actionComplete=false;self.motionSpeed=0
  if intent.state=="Static" or intent.state=="Dead" then self:animate("",1) else self:animate(intent.animation,1) end
 end
 function self:plan(flee:boolean):Vector3?
  self.routePlans+=1;self.nextPlan=self.clock+1
  local p=self:position();local t=self.observedThreat or self.threat
  local angle0=self.options.random()*math.pi*2
  local away=if flee and t then horizontal(p-t.position) else Vector3.new(math.cos(angle0),0,math.sin(angle0))
  if away.Magnitude<.01 then away=Vector3.new(0,0,-1) end
  away=away.Unit
  local choices={};local points={}
  local distance=if t then horizontal(p-t.position).Magnitude else 0
  for i=0,7 do
   local angle=math.rad(i*45)
   local dir=Vector3.new(away.X*math.cos(angle)-away.Z*math.sin(angle),0,away.X*math.sin(angle)+away.Z*math.cos(angle))
   local dest=p+dir*6;local g=self:ground(dest.X,dest.Z)
   if g and self:route(p,g) then
    if not flee then return g end
    local exits=0
    for _,turn in {-90,0,90} do
     local a=math.rad(turn);local d=Vector3.new(dir.X*math.cos(a)-dir.Z*math.sin(a),0,dir.X*math.sin(a)+dir.Z*math.cos(a))
     local q=g+d*2;local endGround=self:ground(q.X,q.Z)
     if endGround and self:route(g,endGround) then exits+=1 end
    end
    local conceal=0
    if t then
     self.queries+=1
     local hit=world:Raycast(g+Vector3.new(0,half,0),t.position-(g+Vector3.new(0,half,0)),ray)
     if hit and (not t.model or not hit.Instance:IsDescendantOf(t.model)) then conceal=1 end
    end
    local id=tostring(i);points[id]=g
    table.insert(choices,{id=id,walkable=true,wet=false,blocked=false,deadEnd=exits==0,clearance=.5,slope=0,threatDistance=if t then horizontal(g-t.position).Magnitude else 6,routeLength=6,concealment=conceal,escapeOptions=exits})
   end
  end
  local best=escape.choose(choices,distance,8);return if best then points[best.id] else nil
 end
 function self:moveToward(goal:Vector3,speed:number,dt:number):boolean
  local p=self:position();local delta=horizontal(goal-p)
  if delta.Magnitude<.01 then return true end
  local elapsed=math.clamp(dt,0,.2)
  local forward=horizontal(mesh.CFrame.LookVector).Unit
  local target=delta.Unit
  local angle=math.atan2(forward:Cross(target).Y,forward:Dot(target))
  local turn=math.clamp(angle,-math.rad(240)*elapsed,math.rad(240)*elapsed)
  local facing=CFrame.fromAxisAngle(Vector3.yAxis,turn):VectorToWorldSpace(forward)
  local alignment=math.max(0,facing:Dot(target))
  self.motionSpeed=math.min(speed,self.motionSpeed+speed*elapsed*5)
  local step=math.min(delta.Magnitude,self.motionSpeed*alignment*elapsed)
  local q=p+facing*step;local g=self:ground(q.X,q.Z)
  if not g or math.abs(g.Y-p.Y)>.6 or (self.options.canMove and not self.options.canMove(g)) then return false end
  local at=g+Vector3.new(0,half,0);mesh.CFrame=CFrame.lookAt(at,at+facing);self.moveDistance+=step
  return true
 end
 function self:execute(intent:any,dt:number):string
  local action=intent.action
  local moving=action=="ChooseSafeEscape" or action=="Wander" or action=="SeekFood" or action=="ReplanEscape"
  if not moving then
   if action=="Peck" or action=="Flap" then
    self.actionAge+=dt
    local track=self.tracks[intent.animation]
    local length=if track and track.Length>0 then track.Length else 0
    -- Never leave a loaded one-shot before it reaches its authored end.
    self.actionComplete=if length>0 then (self.actionAge>=length and (not track.IsPlaying or track.TimePosition>=length-.03)) else self.actionAge>=4
    if action=="Peck" then
    self.peckAge+=dt
    if not self.peckConsumed and self.peckAge>= (if length>0 then length*.5 else .625) and self.food and horizontal(self.food-self:position()).Magnitude<.8 and self.options.onPeck then self.peckConsumed=self.options.onPeck(self.food,dt)==true end
    end
   end
   return "Running"
  end
  local flee=action=="ChooseSafeEscape" or action=="ReplanEscape"
  local p=self:position()
  if self.goal and horizontal(self.goal-p).Magnitude<.2 then self.goal=nil end
  if not self.goal and self.clock>=self.nextPlan then
   if action=="SeekFood" and self.food and self:route(p,self.food) then self.goal=self.food else self.goal=self:plan(flee) end
   self.blocked=self.goal==nil
  end
  local goal=self.goal
  if not goal then self:animate("Idle",1);return "Running" end
  local speed=if flee then self.stats.runSpeed else self.stats.walkSpeed
  if not self:moveToward(goal,speed,dt) then self.goal=nil;self.blocked=true;self:animate("Idle",1);return "Running" end
  self.blocked=false;self:animate(if flee then "Run" else "Walk",math.clamp(self.motionSpeed/speed,.65,1))
  return "Running"
 end
 function self:destroy()
  for _,track in pairs(self.tracks) do track:Stop(0);track:Destroy() end
  for _,anim in pairs(self.animations) do anim:Destroy() end
  model:Destroy()
 end
 return self
end
return table.freeze(D)
