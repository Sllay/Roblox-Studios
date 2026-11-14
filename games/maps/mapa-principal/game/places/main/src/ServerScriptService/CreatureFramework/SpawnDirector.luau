--!strict
-- Server-only natural spawn controller. Dependencies are injected to keep tests identical to runtime.
local D={}
function D.new(deps:any,policy:any,template:Model,parent:Instance,seed:number):any
 local regions=deps.biomes.regions(policy.biomeId);assert(#regions>0)
 local caps={global=policy.maximum,active=policy.maximum,perChunk=3,perBiome={[policy.biomeId]=policy.maximum},perSpecies={[policy.speciesId]=policy.maximum}}
 return {d=deps,p=policy,template=template,parent=parent,regions=regions,budget=deps.population.new(caps),clock=deps.spawn.new(),agents={},rng=Random.new(seed),cursor=1,food=deps.food.new(256),now=0,lastPrune=0,attempts=0}
end
function D.count(s:any):number return s.budget.total end
function D.remove(s:any,id:string):boolean
 local r=s.agents[id];if not r then return false end
 if r.foodKey then s.d.food.release(s.food,r.foodKey,id) end
 s.d.agent.destroy(r.agent);s.agents[id]=nil
 return s.d.population.release(s.budget,id)
end
function D.spawnOne(s:any,now:number,aiEnabled:boolean?):string?
 local d,p=s.d,s.p
 if s.budget.total>=p.maximum then return nil end
 local species=assert(d.registry.get(p.speciesId))
 local model=s.template:Clone()
 local materials:{[Enum.Material]:boolean}={}
 for _,material in Enum.Material:GetEnumItems() do if p.allowedMaterials[material.Name] then materials[material]=true end end
 local options={contains=function(x:number,z:number)return d.biomes.regionAt(p.biomeId,x,z)~=nil end,materials=materials,random=function()return s.rng:NextNumber() end,threatProvider=d.threatProvider}
 local adapter=d.adapter.new(workspace,model,species,d.escape,options)
 adapter.aiEnabled=aiEnabled~=false
 local id=game:GetService("HttpService"):GenerateGUID(false)
 local success=false
 local ranked=table.clone(s.regions)
 table.sort(ranked,function(a:any,b:any)
  local ac=s.budget.chunks[p.biomeId.."/"..a.id] or 0;local bc=s.budget.chunks[p.biomeId.."/"..b.id] or 0
  if ac~=bc then return ac<bc end
  return a.id<b.id
 end)
 -- Bounded 16 samples per region, favor underpopulated regions but never force invalid ground.
 for _,region in ranked do
  if (s.budget.chunks[p.biomeId.."/"..region.id] or 0)>=s.budget.caps.perChunk then continue end
  for _=1,16 do
   s.attempts+=1
   local x=s.rng:NextNumber(region.minX+8,region.maxX-8);local z=s.rng:NextNumber(region.minZ+8,region.maxZ-8)
   if adapter:ground(x,z) and (not d.spawnAllowed or d.spawnAllowed(Vector3.new(x,0,z))) then
    if d.population.reserve(s.budget,id,p.speciesId,p.biomeId,region.id,true,now,10) then
     if adapter:place(Vector3.new(x,0,z)) and d.population.commit(s.budget,id,now) then success=true;break end
     d.population.release(s.budget,id)
    end
   end
  end
  if success then break end
 end
 if not success then adapter:destroy();return nil end
 adapter.options.canMove=function(g:Vector3)
  local region=d.biomes.regionAt(p.biomeId,g.X,g.Z)
  return region~=nil and d.population.move(s.budget,id,p.biomeId,region.id)
 end
 model.Name="Creature_"..id
 model:SetAttribute("CreatureInstanceId",id)
 model:SetAttribute("CreatureOrigin","Natural")
 model:SetAttribute("CreatureHealth",species.base.health)
 model.Parent=s.parent
 local a=d.agent.new(d.brain,d.kernel,adapter)
 s.agents[id]={agent=a,adapter=adapter,foodKey=nil,nextFood=0}
 return id
end
function D.tickSpawn(s:any,now:number):string?
 s.now=now
 if not s.d.spawn.next(s.clock,s.p,s.budget.total,now) then return nil end
 local id=D.spawnOne(s,now,true)
 s.d.spawn.result(s.clock,s.p,s.budget.total,now,id~=nil)
 return id
end
function D.step(s:any,dt:number,now:number)
 s.now=now
 for id,r in pairs(s.agents) do
  local adapter=r.adapter
  if not adapter.alive then D.remove(s,id);continue end
  if r.foodKey and not s.d.food.owns(s.food,r.foodKey,id,now) then r.foodKey=nil;adapter:setFood(nil) end
  if adapter.aiEnabled and now>=r.nextFood and r.agent.memory.hunger>.35 and not r.foodKey then
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
       if s.d.food.consume(s.food,key,id,s.now) then r.foodKey=nil;adapter:setFood(nil);return true end
       return false
      end
      break
     end
    end
   end
  end
  local result=s.d.agent.step(r.agent,dt)
  if result.intent.state=="Flee" or result.intent.state=="Recover" or result.intent.state=="Static" then
   if r.foodKey then s.d.food.release(s.food,r.foodKey,id);r.foodKey=nil;adapter:setFood(nil) end
  elseif r.foodKey and not adapter.food then
   s.d.food.release(s.food,r.foodKey,id);r.foodKey=nil
  end

 end
 if now-s.lastPrune>=10 then s.d.food.prune(s.food,now,64);s.lastPrune=now end
end
function D.destroy(s:any)
 local ids={};for id in pairs(s.agents) do table.insert(ids,id) end
 for _,id in ids do D.remove(s,id) end
end
return table.freeze(D)
