--!strict
-- Server-only natural spawn controller. Dependencies are injected to keep tests identical to runtime.
local D={}
function D.new(deps:any,policy:any,template:Model,parent:Instance,seed:number):any
 local regions=deps.biomes.regions(policy.biomeId);assert(#regions>0)
 local caps={global=policy.maximum,active=policy.maximum,perChunk=3,perBiome={[policy.biomeId]=policy.maximum},perSpecies={[policy.speciesId]=policy.maximum}}
 return {d=deps,p=policy,template=template,parent=parent,regions=regions,budget=deps.population.new(caps),clock=deps.spawn.new(),agents={},rng=Random.new(seed),cursor=1,food=deps.food.new(256),now=0,lastPrune=0,attempts=0,foodConsumed=0,naturalCount=0,closed=false}
end
function D.count(s:any):number return s.budget.total end
function D.remove(s:any,id:string,now:number?):boolean
 local r=s.agents[id];if not r then return false end
 if r.actor and s.d.combatWorld then r.actor.alive=false;s.d.combatWorld.remove(s.d.combatState,id) end
 if r.foodKey then s.d.food.release(s.food,r.foodKey,id) end
 s.d.agent.destroy(r.agent);s.agents[id]=nil
 local released=s.d.population.release(s.budget,id)
 if released and r.origin=="Natural" then
  s.naturalCount-=1
  if not s.closed then s.d.spawn.next(s.clock,s.p,s.naturalCount,now or s.now) end
 end
 return released
end
local function create(s:any,aiEnabled:boolean?):(any,any,Model,string)
 local d,p=s.d,s.p
 local species=assert(d.registry.get(p.speciesId))
 local model=s.template:Clone()
 local materials:{[Enum.Material]:boolean}={}
 for _,material in Enum.Material:GetEnumItems() do if p.allowedMaterials[material.Name] then materials[material]=true end end
 local options={contains=function(x:number,z:number)return d.biomes.regionAt(p.biomeId,x,z)~=nil end,materials=materials,random=function()return s.rng:NextNumber() end,threatProvider=d.threatProvider}
 local adapter=d.adapter.new(workspace,model,species,d.escape,options)
 adapter.aiEnabled=aiEnabled~=false
 return species,adapter,model,game:GetService("HttpService"):GenerateGUID(false)
end
local function finish(s:any,species:any,adapter:any,model:Model,id:string,origin:string,now:number):string
 local d,p=s.d,s.p
 adapter.options.canMove=function(g:Vector3)
  local region=d.biomes.regionAt(p.biomeId,g.X,g.Z)
  return region~=nil and d.population.move(s.budget,id,p.biomeId,region.id)
 end
 model.Name="Creature_"..id
 model:SetAttribute("CreatureInstanceId",id);model:SetAttribute("CreatureOrigin",origin)
 model:SetAttribute("CreatureHealth",species.base.health);model:SetAttribute("CreatureAIEnabled",adapter.aiEnabled)
 model.Parent=s.parent
 local record:any={agent=nil,adapter=adapter,origin=origin,speciesId=p.speciesId,profile=species.profile,health=species.base.health,foodKey=nil,nextFood=0,nextDecision=0,lastDecision=now,lastMotion=now,tier=nil}
 if d.factory then
  local actor:any={id=id,model=model,faction=species.faction,prey=species.prey,profile=species.profile,alive=true,damage=species.base.damage,hunger=1,getPosition=function()return adapter.mesh.Position end,getVelocity=function()return adapter.mesh.AssemblyLinearVelocity end,healthRatio=function()return record.health/species.base.health end}
  actor.applyDamage=function(amount:number,attackerId:string?)
   if not actor.alive or amount<=0 then return end
   record.health=math.max(0,record.health-amount);model:SetAttribute("CreatureHealth",record.health)
   if record.health==0 then actor.alive=false;adapter.alive=false else
    local attacker=if attackerId and d.combatState then d.combatState.actors[attackerId] else nil
    adapter:damage(if attacker then {position=attacker.getPosition(),velocity=attacker.getVelocity(),model=attacker.model,predator=attacker.profile=="Predator"} else nil)
   end
  end
  record.actor=actor
  record.agent=d.factory.new(d,species,adapter,actor,d.combatState)
 else record.agent=d.agent.new(d.brain,d.kernel,adapter) end
 s.agents[id]=record
 if origin=="Natural" then s.naturalCount+=1 end
 if d.onSpawn then d.onSpawn(id,record) end
 return id
end
local function place(s:any,adapter:any,id:string,region:any,x:number,z:number,now:number,y:number?):boolean
 local d,p=s.d,s.p
 local g=adapter:ground(x,z)
 if not g or (y and math.abs(g.Y-y)>6) then return false end
 if not d.population.reserve(s.budget,id,p.speciesId,p.biomeId,region.id,true,now,10) then return false end
 if adapter:place(g) and d.population.commit(s.budget,id,now) then return true end
 d.population.release(s.budget,id);return false
end
function D.spawnOne(s:any,now:number,aiEnabled:boolean?):string?
 local d,p=s.d,s.p
 if s.closed or s.budget.total>=p.maximum then return nil end
 local species,adapter,model,id=create(s,aiEnabled)
 local ranked=table.clone(s.regions)
 table.sort(ranked,function(a:any,b:any)
  local ac=s.budget.chunks[p.biomeId.."/"..a.id] or 0;local bc=s.budget.chunks[p.biomeId.."/"..b.id] or 0
  if ac~=bc then return ac<bc end
  return a.id<b.id
 end)
 for _,region in ranked do
  if (s.budget.chunks[p.biomeId.."/"..region.id] or 0)>=s.budget.caps.perChunk then continue end
  for _=1,16 do
   s.attempts+=1
   local x=s.rng:NextNumber(region.minX+8,region.maxX-8);local z=s.rng:NextNumber(region.minZ+8,region.maxZ-8)
   if (not d.spawnAllowed or d.spawnAllowed(Vector3.new(x,0,z))) and place(s,adapter,id,region,x,z,now,nil) then
    return finish(s,species,adapter,model,id,"Natural",now)
   end
  end
 end
 adapter:destroy();return nil
end
function D.spawnDeveloper(s:any,plan:any,position:Vector3,now:number):({string},string?)
 local ids:{string}={}
 if s.closed or plan.speciesId~=s.p.speciesId or plan.count<1 or plan.count%1~=0 or plan.count>s.p.maximum-s.budget.total then return ids,"population limit" end
 for i=1,plan.count do
  local species,adapter,model,id=create(s,plan.aiEnabled)
  local done=false
  -- Exact requested center first; additional positions nearby, never an unrelated random chunk.
  for k=0,24 do
   local radius=if k==0 and i==1 then 0 else 3.5*math.ceil((k+1)/8)
   local angle=(k+i-1)*math.pi/4
   local x,z=position.X+radius*math.cos(angle),position.Z+radius*math.sin(angle)
   local region=s.d.biomes.regionAt(s.p.biomeId,x,z)
   if region and place(s,adapter,id,region,x,z,now,position.Y) then
    table.insert(ids,finish(s,species,adapter,model,id,"Developer",now));done=true;break
   end
  end
  if not done then
   adapter:destroy();for _,created in ids do D.remove(s,created,now) end
   return {},"no safe placement for entire request"
  end
 end
 return ids,nil
end
function D.tickSpawn(s:any,now:number):string?
 s.now=now
 if not s.d.spawn.next(s.clock,s.p,s.naturalCount,now) then return nil end
 local id=D.spawnOne(s,now,true)
 s.d.spawn.result(s.clock,s.p,s.naturalCount,now,id~=nil)
 return id
end
local intervals:{[string]:number}={Near=.1,Mid=.5,Far=2,Abstract=10}
function D.step(s:any,dt:number,now:number)
 s.now=now
 for id,r in pairs(s.agents) do
  local adapter=r.adapter
  if not adapter.alive or adapter.model.Parent~=s.parent then D.remove(s,id,now);continue end
  local distance=if s.d.distanceProvider then s.d.distanceProvider(adapter:position()) else 0
  local tier=if s.d.scheduler then s.d.scheduler.tier(distance,r.tier) else "Near"
  local previous=r.tier;r.tier=tier
  local moving=tier=="Near" or tier=="Mid"
  if previous~=tier then r.nextDecision=now;r.lastMotion=now;r.agent.adapter:cancel() end
  if r.foodKey and not s.d.food.owns(s.food,r.foodKey,id,now) then r.foodKey=nil;adapter:setFood(nil) end
  if r.profile=="PassivePrey" and moving and adapter.aiEnabled and r.agent.memory.state~="Peck" and now>=r.nextFood and r.agent.memory.hunger>.35 and not r.foodKey then
   r.nextFood=now+3
   local pos=adapter:position()
   for i=1,4 do
    local angle=s.rng:NextNumber(0,2*math.pi);local radius=s.rng:NextNumber(1,3)
    local g=adapter:ground(pos.X+math.cos(angle)*radius,pos.Z+math.sin(angle)*radius)
    if g and adapter:route(pos,g) then
     local key=s.d.food.key(g.X,g.Z)
     if s.d.food.claim(s.food,key,id,now) then
      r.foodKey=key;adapter:setFood(g)
      adapter.options.onPeck=function()
       if s.d.food.consume(s.food,key,id,s.now) then s.foodConsumed+=1;r.foodKey=nil;adapter:setFood(nil);return true end
       return false
      end
      break
     end
    end
   end
  end
  if now>=r.nextDecision then
   s.d.agent.decide(r.agent,math.max(dt,now-r.lastDecision));r.lastDecision=now;r.nextDecision=now+intervals[tier]
  end
  local intent=r.agent.intent
  if moving and previous~=tier and intent and adapter.aiEnabled and adapter.alive then adapter:animate(intent.animation,1) end
  if moving and intent and now-r.lastMotion>=(if tier=="Near" then .03 else .19) then
   s.d.agent.act(r.agent,math.min(.2,now-r.lastMotion));r.lastMotion=now
  elseif not moving then adapter:animate("",1) end
  if not moving or (intent and (intent.state=="Flee" or intent.state=="Recover" or intent.state=="Static")) then
   if r.foodKey then s.d.food.release(s.food,r.foodKey,id);r.foodKey=nil;adapter:setFood(nil) end
  elseif r.foodKey and not adapter.food then
   s.d.food.release(s.food,r.foodKey,id);r.foodKey=nil
  end
  if r.actor and s.d.combatWorld then s.d.combatWorld.update(s.d.combatState,id) end

 end
 if now-s.lastPrune>=10 then s.d.food.prune(s.food,now,64);s.lastPrune=now end
end
function D.destroy(s:any)
 s.closed=true
 local ids={};for id in pairs(s.agents) do table.insert(ids,id) end
 for _,id in ids do D.remove(s,id) end
end
return table.freeze(D)
