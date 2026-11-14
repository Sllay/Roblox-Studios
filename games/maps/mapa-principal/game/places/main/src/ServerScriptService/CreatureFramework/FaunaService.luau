--!strict
-- Explicitly started by the future staging bootstrap; exactly one Heartbeat connection.
local F={}
function F.new(deps:any,template:Model,parent:Instance,seed:number):any
 local players=game:GetService("Players")
 local function nearest(p:Vector3):(any,number)
  local best=nil;local distance=math.huge
  for _,player in players:GetPlayers() do
   local character=player.Character
   local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
   if root and root:IsA("BasePart") then
    local d=(root.Position-p).Magnitude
    if d<distance then
     local humanoid=if character then character:FindFirstChildWhichIsA("Humanoid") else nil
     if humanoid and humanoid.Health>0 then
      local state=humanoid:GetState();distance=d;best={position=root.Position,velocity=root.AssemblyLinearVelocity,model=character,predator=false,normalSpeed=humanoid.WalkSpeed,jumping=state==Enum.HumanoidStateType.Jumping or state==Enum.HumanoidStateType.Freefall}
     end
    end
   end
  end
  return best,distance
 end
 local d=table.clone(deps)
 d.distanceProvider=function(p:Vector3) local _,distance=nearest(p);return distance end
 d.threatProvider=function(p:Vector3)
  local best,distance=nearest(p)
  if d.combatWorld and d.combatState then
   local predator,predDistance=d.combatWorld.predatorNear(d.combatState,p,22)
   if predator and predDistance<distance then return predator end
  end
  return best
 end
 d.spawnAllowed=function(p:Vector3)
  for _,player in players:GetPlayers() do
   local character=player.Character;local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
   if root and root:IsA("BasePart") then
    local dx,dz=root.Position.X-p.X,root.Position.Z-p.Z
    if dx*dx+dz*dz<144 then return false end
   end
  end
  return true
 end
 return {director=d.director.new(d,d.spawn.chicken,template,parent,seed),deps=d,clock=0,accumulator=0,nextSpawn=0,connection=nil,closed=false}
end
function F.advance(s:any,dt:number)
 assert(not s.closed,"service closed")
 if dt<=0 or dt~=dt or dt==math.huge then return end
 s.clock+=dt;s.accumulator=math.min(.5,s.accumulator+dt)
 s.deps.director.tickDeveloper(s.director,s.clock)
 if s.clock>=s.nextSpawn then
  s.deps.director.tickSpawn(s.director,s.clock)
  s.nextSpawn=s.clock+.25
 end
 if s.accumulator>=1/30 then
  local elapsed=s.accumulator;s.accumulator=0
  if s.deps.combatWorld and s.deps.combatState then s.deps.combatWorld.syncPlayers(s.deps.combatState,game:GetService("Players"):GetPlayers()) end
  s.deps.director.step(s.director,math.min(.2,elapsed),s.clock)
  if s.deps.combatWorld and s.deps.combatState then s.deps.combatWorld.step(s.deps.combatState,math.min(.2,elapsed)) end
 end
end
function F.start(s:any)
 assert(not s.closed and s.connection==nil,"already started")
 s.connection=game:GetService("RunService").Heartbeat:Connect(function(dt:number)F.advance(s,dt)end)
end
function F.stop(s:any)
 if s.closed then return end;s.closed=true
 if s.connection then s.connection:Disconnect();s.connection=nil end
 s.deps.director.destroy(s.director)
end
return table.freeze(F)
