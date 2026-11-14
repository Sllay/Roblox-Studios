--!strict
-- Server-authoritative Book and command transport. No client damage/discovery remote.
local S={}
function S.new(deps:any,fauna:any,book:any,events:any,flags:any):any
 return {deps=deps,fauna=fauna,book=book,events=events,flags=flags,limits={},connections={},folder=nil}
end
function S.isDeveloper(s:any,player:Player):boolean
 return s.deps.developer.authorized(player.UserId,game.CreatorId,game.CreatorType.Name,s.flags.DeveloperAllowlist)
end
function S.request(s:any,player:Player,op:any,value:any):any
 if player.Parent~=game:GetService("Players") or type(op)~="string" then return {ok=false,error="invalid request"} end
 local now=os.clock();local uid=player.UserId
 local row=s.limits[uid] or {snapshot=-math.huge,command=-math.huge};s.limits[uid]=row
 local developer=S.isDeveloper(s,player)
 if op=="snapshot" then
  if now-row.snapshot<.35 then return {ok=false,error="rate limited"} end
  row.snapshot=now
  if value~="Discovery" and value~="Alphabetical" then return {ok=false,error="invalid sort"} end
  local result=s.deps.persistence.snapshot(s.book,uid,value,developer);result.ok=true;result.developer=developer;return result
 elseif op=="command" then
  if not developer then return {ok=false,error="forbidden"} end
  if now-row.command<1 then return {ok=false,error="rate limited"} end;row.command=now
  if type(value)~="string" then return {ok=false,error="invalid command"} end
  local args=s.deps.developer.tokens(value);if not args then return {ok=false,error="invalid command"} end
  local director=s.fauna.director
  local exists=#args>=2 and s.deps.registry.get(args[2])~=nil
  local plan,err=s.deps.summon.parse(args,true,exists,director.p.maximum-director.budget.total)
  if not plan then return {ok=false,error=err} end
  local pos:Vector3
  if plan.here then
   local character=player.Character;local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
   if not root or not root:IsA("BasePart") then return {ok=false,error="no character"} end
   pos=root.Position+root.CFrame.LookVector*6
  else local p=plan.position;pos=Vector3.new(p[1],p[2],p[3]) end
  local ids,reason=s.deps.director.spawnDeveloper(director,plan,pos,s.fauna.clock)
  print("[CreatureCommand]",uid,plan.speciesId,plan.count,plan.aiEnabled,#ids,reason or "ok")
  return {ok=#ids==plan.count,count=#ids,error=reason}
 end
 return {ok=false,error="unknown operation"}
end
function S.attach(s:any,id:string,record:any)
 if record.origin~="Natural" then return end
 local prompt=Instance.new("ProximityPrompt");prompt.Name="BookDiscover";prompt.ActionText="Conhecer";prompt.ObjectText=assert(s.deps.registry.get(record.speciesId)).name;prompt.MaxActivationDistance=8;prompt.HoldDuration=.5;prompt.RequiresLineOfSight=true;prompt.Parent=record.adapter.mesh
 prompt.Triggered:Connect(function(player)
  if prompt.Enabled and record.adapter.alive then s.deps.gameplay.interact(s.events,player,id,os.clock(),os.time()) end
 end)
end
function S.start(s:any)
 local rs=game:GetService("ReplicatedStorage")
 assert(not rs:FindFirstChild("RSBookTransport"),"duplicate Book service")
 local folder=Instance.new("Folder");folder.Name="RSBookTransport"
 local remote=Instance.new("RemoteFunction");remote.Name="Request";remote.OnServerInvoke=function(player,op,value)return S.request(s,player,op,value) end;remote.Parent=folder;folder.Parent=rs;s.folder=folder
 table.insert(s.connections,game:GetService("Players").PlayerRemoving:Connect(function(p)s.limits[p.UserId]=nil;s.deps.gameplay.forgetActor(s.events,p.UserId)end))
end
function S.stop(s:any)
 for _,c in s.connections do c:Disconnect() end;table.clear(s.connections)
 if s.folder then s.folder:Destroy();s.folder=nil end
end
return table.freeze(S)
