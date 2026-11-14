do
local result={noPlaceWrites=true,passed=false}
local model=game:GetService("AssetService"):LoadAssetAsync(76960331636475)
local adapter=nil
local ok,err=pcall(function()
 model.Parent=workspace
 local species=Registry.get("210080")
 local options={contains=function(x,z)return x>=-384 and x<384 and z>=-384 and z<384 end,materials={[Enum.Material.Grass]=true,[Enum.Material.Ground]=true},random=function()return .5 end}
 adapter=Adapter.new(workspace,model,species,Escape,options)
 local start=nil
 for z=-96,96,8 do
  for x=-96,96,8 do
   local g=adapter:ground(x,z)
   if g and adapter:route(g,g+Vector3.new(0,0,6)) and adapter:route(g,g+Vector3.new(6,0,0)) then start=g;break end
  end
  if start then break end
 end
 assert(start,"No native safe grass fixture")
 assert(adapter:place(start))
 result.start={start.X,start.Y,start.Z}
 local a=Agent.new(Brain,Kernel,adapter)
 local slow={position=start+Vector3.new(0,1.3,6),velocity=Vector3.new(0,0,-.1),predator=false}
 adapter:setThreat(slow)
 local s=Agent.step(a,.1);result.slow=s.intent.state
 assert(s.intent.state=="Idle")
 local fast={position=slow.position,velocity=Vector3.new(0,0,-6),predator=false}
 adapter:setThreat(fast)
 s=Agent.step(a,.1);result.fast=s.intent.state
 assert(s.intent.state=="Flee" and s.visits==1)
 local before=adapter:position()
 for _=1,15 do Agent.step(a,.1) end
 local after=adapter:position()
 result.moved=(after-before).Magnitude;result.escapeGain=(after-fast.position).Magnitude-(before-fast.position).Magnitude
 assert(result.moved>.5 and result.escapeGain>.4)
 result.groundError=math.abs(after.Y-adapter:ground(after.X,after.Z).Y)
 assert(result.groundError<.05)
 adapter:setThreat(nil)
 for _=1,35 do s=Agent.step(a,.1) end
 result.recovered=s.intent.state
 assert(s.intent.state~="Flee" and s.intent.state~="Recover")
 adapter:damage();s=Agent.step(a,.1);result.hit=s.intent.state;assert(s.intent.state=="Flee")
 adapter.aiEnabled=false;local old=adapter:position()
 for _=1,5 do s=Agent.step(a,.1) end
 result.static=s.intent.state;assert(s.intent.state=="Static" and (adapter:position()-old).Magnitude<.001)
 result.queries=adapter.queries;result.routePlans=adapter.routePlans
 result.meshSize={adapter.mesh.Size.X,adapter.mesh.Size.Y,adapter.mesh.Size.Z}
 result.passed=true
end)
result.ok=ok;if not ok then result.error=tostring(err):sub(1,500) end
if adapter then adapter:destroy() else model:Destroy() end
return syncResult(result)
end
