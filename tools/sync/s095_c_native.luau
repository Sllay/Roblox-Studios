do
local result={noPlaceWrites=true,passed=false}
local template=game:GetService("AssetService"):LoadAssetAsync(76960331636475)
local folder=Instance.new("Folder");folder.Name="S095_C_Probe";folder.Parent=workspace
local d={registry=Registry,brain=Brain,kernel=Kernel,escape=Escape,adapter=Adapter,agent=Agent,population=Population,spawn=Spawn,biomes=Biomes,food=Food,scheduler=Scheduler,director=Director}
local s=Director.new(d,Spawn.chicken,template,folder,210080)
local ok,err=pcall(function()
 for i=1,15 do assert(Director.tickSpawn(s,i),"initial spawn "..i) end
 assert(Director.count(s)==15 and #folder:GetChildren()==15)
 result.initial=Director.count(s);result.chunks={}
 for k,v in pairs(s.budget.chunks) do result.chunks[k]=v end
 local seen=0;for _ in pairs(result.chunks) do seen+=1 end
 assert(seen==9,"not distributed across nine chunks")
 local ids={};for id,r in pairs(s.agents) do
  table.insert(ids,id)
  local p=r.adapter:position();assert(r.adapter:ground(p.X,p.Z),"invalid ground after spawn")
 end
 for i=1,3 do assert(Director.remove(s,ids[i])) end
 assert(Director.count(s)==12)
 assert(Director.tickSpawn(s,20)==nil and s.clock.due==320)
 assert(Director.tickSpawn(s,319.99)==nil)
 assert(Director.tickSpawn(s,320) and Director.count(s)==13 and s.clock.due==620)
 assert(Director.tickSpawn(s,619.99)==nil)
 assert(Director.tickSpawn(s,620) and Director.count(s)==14 and s.clock.due==920)
 assert(Director.tickSpawn(s,920) and Director.count(s)==15 and s.clock.due==nil)
 assert(Director.tickSpawn(s,1220)==nil)
 result.final=Director.count(s);result.children=#folder:GetChildren();result.attempts=s.attempts
 result.respawnTimes={320,620,920};result.clockMode="synthetic_monotonic_seconds"
 -- Central service uses the same director, no per-creature heartbeat; exercise stopped-session time manually.
 Director.destroy(s);assert(#folder:GetChildren()==0)
 local service=Service.new(d,template,folder,210081)
 for _=1,4 do Service.advance(service,.25) end
 result.serviceSpawned=Director.count(service.director)
 assert(result.serviceSpawned>=1 and result.serviceSpawned<=4)
 Service.stop(service)
 result.passed=true
end)
result.ok=ok;if not ok then result.error=tostring(err):sub(1,500) end
Director.destroy(s);folder:Destroy();template:Destroy()
return syncResult(result)
end
