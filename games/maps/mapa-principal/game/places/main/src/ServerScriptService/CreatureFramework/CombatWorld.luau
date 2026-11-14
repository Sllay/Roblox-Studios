--!strict
-- Actual Roblox combat queries; one bounded projectile update for the whole service.
local W={}
function W.new(workspaceRef:Workspace,gridModule:any,rules:any,maxProjectiles:number):any
 assert(maxProjectiles>=1 and maxProjectiles<=128)
 return {world=workspaceRef,gridModule=gridModule,grid=gridModule.new(32),rules=rules,actors={},projectiles={},maxProjectiles=maxProjectiles,queries=0,playerIds={}}
end
function W.register(s:any,actor:any)
 assert(not s.actors[actor.id] and actor.model and actor.getPosition and actor.applyDamage,"invalid actor")
 actor.attackMemory=s.rules.new();s.actors[actor.id]=actor
 local p=actor.getPosition();s.gridModule.upsert(s.grid,actor.id,p.X,p.Z)
end
function W.update(s:any,id:string)
 local a=s.actors[id];if not a then return end
 local p=a.getPosition();s.gridModule.upsert(s.grid,id,p.X,p.Z)
end
function W.remove(s:any,id:string)
 s.actors[id]=nil;s.gridModule.remove(s.grid,id)
end
function W.syncPlayers(s:any,players:{Player})
 local seen:{[string]:boolean}={}
 for _,player in players do
  local id="player:"..tostring(player.UserId);local character=player.Character
  local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
  local humanoid=if character then character:FindFirstChildWhichIsA("Humanoid") else nil
  if character and root and root:IsA("BasePart") and humanoid and humanoid.Health>0 then
   seen[id]=true
   local old=s.actors[id]
   if not old or old.model~=character then
    if old then W.remove(s,id) end
    local part:BasePart=root;local h:Humanoid=humanoid
    W.register(s,{id=id,model=character,faction="players",prey=false,profile="Player",alive=true,damage=0,getPosition=function()return part.Position end,getVelocity=function()return part.AssemblyLinearVelocity end,healthRatio=function()return h.Health/math.max(1,h.MaxHealth) end,applyDamage=function(amount:number)if h.Health>0 then h:TakeDamage(amount) end end})
   else W.update(s,id) end
  end
 end
 for id in pairs(s.playerIds) do if not seen[id] then W.remove(s,id) end end
 s.playerIds=seen
end
function W.predatorNear(s:any,p:Vector3,radius:number):any
 local ids=s.gridModule.query(s.grid,p.X,p.Z,radius,64,24)
 local nearest=nil;local best=radius
 for _,id in ids do
  local a=s.actors[id]
  if a and a.alive and a.profile=="Predator" then
   local d=(a.getPosition()-p).Magnitude
   if d<best then best=d;nearest=a end
  end
 end
 if nearest then return {position=nearest.getPosition(),velocity=if nearest.getVelocity then nearest.getVelocity() else Vector3.zero,model=nearest.model,predator=true},best end
 return nil,best
end
function W.visibleFrom(s:any,from:Vector3,target:any,exclude:Instance?):boolean
 local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Exclude;p.FilterDescendantsInstances=if exclude then {exclude} else {};p.IgnoreWater=false
 local delta=target.getPosition()-from
 if delta.Magnitude<.01 then return true end
 s.queries+=1
 local hit=s.world:Raycast(from,delta,p)
 return hit==nil or hit.Instance:IsDescendantOf(target.model)
end
function W.candidates(s:any,actor:any,profile:any):{any}
 local p=actor.getPosition()
 local ids=s.gridModule.query(s.grid,p.X,p.Z,profile.sight,64,24)
 local result={};local rayBudget=8
 for _,id in ids do
  local t=s.actors[id]
  if t and t.id~=actor.id and t.alive and t.faction~=actor.faction and (not profile.preyOnly or t.prey) and rayBudget>0 then
   rayBudget-=1
   local distance=(t.getPosition()-p).Magnitude
   table.insert(result,{id=t.id,faction=t.faction,alive=t.alive,prey=t.prey==true,visible=W.visibleFrom(s,p,t,actor.model),distance=distance,threat=t.threat or 0})
  end
 end
 return result
end
function W.attack(s:any,attackerId:string,targetId:string,profile:any,token:number,now:number):boolean
 local a,t=s.actors[attackerId],s.actors[targetId]
 if not a or not t or (profile.preyOnly and not t.prey) then return false end
 local from,to=a.getPosition(),t.getPosition();local distance=(to-from).Magnitude
 if profile.kind=="Ranged" and #s.projectiles>=s.maxProjectiles then return false end
 if not s.rules.authorize(a.attackMemory,profile,a,t,token,now,distance,W.visibleFrom(s,from,t,a.model)) then return false end
 if profile.kind=="Melee" then
  t.applyDamage(a.damage,a.id)
  if profile.preyOnly and t.prey and not t.alive then a.hunger=math.max(0,(a.hunger or 1)-.8) end
  return true
 end
 local flight=math.max(.08,distance/profile.projectileSpeed)
 local gravity=Vector3.new(0,-s.world.Gravity*.25,0)
 local velocity=(to-from-gravity*(.5*flight*flight))/flight
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={a.model};params.IgnoreWater=false
 table.insert(s.projectiles,{params=params,attackerId=a.id,targetId=t.id,position=from,velocity=velocity,gravity=gravity,age=0,lifetime=math.min(3,flight+.75),damage=a.damage,exclude=a.model})
 return true
end
function W.step(s:any,dt:number)
 -- Sweep each projectile segment; no per-arrow event connection or client damage.
 local remain=math.clamp(dt,0,.25)
 while remain>1e-6 do
  local step=math.min(.05,remain);remain-=step
  for i=#s.projectiles,1,-1 do
   local p=s.projectiles[i];p.age+=step
   local delta=p.velocity*step+p.gravity*(.5*step*step)
   s.queries+=1;local hit=s.world:Raycast(p.position,delta,p.params)
   if hit then
    local a,t=s.actors[p.attackerId],s.actors[p.targetId]
    if a and t and t.alive and a.faction~=t.faction and hit.Instance:IsDescendantOf(t.model) then t.applyDamage(p.damage,p.attackerId) end
    table.remove(s.projectiles,i)
   elseif p.age>=p.lifetime then table.remove(s.projectiles,i)
   else p.position+=delta;p.velocity+=p.gravity*step end
  end
 end
end
return table.freeze(W)
