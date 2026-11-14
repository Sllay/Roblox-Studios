--!strict
-- Server-authoritative Book and command transport. No client damage/discovery remote.
local S={}
local Players=game:GetService("Players")
local RADIUS=500
local AIM_RANGE=12
local collisionSaved:{[Model]:{[BasePart]:boolean}}={}
local function protectedCharacter(c:Model):boolean
 return c:GetAttribute("RSDevGold")==true
end
local characterRoot:(Player)->BasePart?
local function mode(player:Player,name:string):any
 local c=player.Character;local root=characterRoot(player)
 if not c or not root then return {ok=false,error="no character"} end
 local old=c:GetAttribute("RSDevMode") or "normal"
 local nextMode=if old==name then "normal" else name
 c:SetAttribute("RSDevMode",nextMode)
 if nextMode~="ghost" then local saved=collisionSaved[c];if saved then for part,v in pairs(saved) do if part.Parent then part.CanCollide=v end end;collisionSaved[c]=nil end end
 return {ok=true,message="Modo: "..nextMode}
end
local function gold(player:Player):any
 local c=player.Character
 if not c then return {ok=false,error="no character"} end
 local enabled=not protectedCharacter(c);c:SetAttribute("RSDevGold",enabled)
 local h=c:FindFirstChildWhichIsA("Humanoid")
 if enabled and h then h.Health=h.MaxHealth end
 local shield=c:FindFirstChild("RSDevShield")
 if enabled and not shield then local f=Instance.new("ForceField");f.Name="RSDevShield";f.Visible=false;f.Parent=c
 elseif not enabled and shield then shield:Destroy() end
 return {ok=true,message=if enabled then "Gold ativo" else "Gold desativado"}
end
characterRoot=function(player:Player):BasePart?
 local c=player.Character;local h=if c then c:FindFirstChildWhichIsA("Humanoid") else nil
 local root=if c then c:FindFirstChild("HumanoidRootPart") else nil
 return if h and h.Health>0 and root and root:IsA("BasePart") then root else nil
end
local function aimedRecord(s:any,player:Player,direction:any):string?
 local root=characterRoot(player);local c=player.Character
 if not root or not c or typeof(direction)~="Vector3" or direction.Magnitude~=direction.Magnitude or math.abs(direction.Magnitude-1)>.05 then return nil end
 local head=c:FindFirstChild("Head");if not head or not head:IsA("BasePart") then return nil end
 local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude;ray.FilterDescendantsInstances={c};ray.IgnoreWater=false
 local hit=workspace:Raycast(head.Position,direction.Unit*AIM_RANGE,ray)
 if not hit then hit=workspace:Spherecast(head.Position,.35,direction.Unit*AIM_RANGE,ray) end
 if not hit then return nil end
 local m=hit.Instance:FindFirstAncestorOfClass("Model")
 while m do
  local id=m:GetAttribute("CreatureInstanceId");local r=if type(id)=="string" then s.fauna.director.agents[id] else nil
  if r and r.adapter.model==m and r.adapter.alive and (r.adapter.mesh.Position-root.Position).Magnitude<=AIM_RANGE then return id :: string end
  local parent=m.Parent;m=if parent then parent:FindFirstAncestorOfClass("Model") else nil
 end
 return nil
end
local function kill(s:any,player:Player,selector:string?,direction:any):any
 local root=characterRoot(player);if not root then return {ok=false,error="no character"} end
 local director=s.fauna.director;local dm=s.deps.director;local ids={};local center=root.Position
 if not selector then local id=aimedRecord(s,player,direction);if not id then return {ok=false,error="no mob in crosshair"} end;table.insert(ids,id)
 elseif selector=="@e" or selector=="@a" or s.deps.registry.get(selector) then
  for id,r in pairs(director.agents) do
   if r.adapter.alive and (r.adapter.mesh.Position-center).Magnitude<=RADIUS and (selector=="@e" or selector=="@a" or r.speciesId==selector) then table.insert(ids,id) end
  end
  dm.cancelDeveloperNear(director,center,RADIUS,if selector=="@e" or selector=="@a" then nil else selector)
 else return {ok=false,error="usage: /kill [@e|@a|species ID]"} end
 local count=0
 for i,id in ids do
  if dm.remove(director,id,s.fauna.clock) then count+=1 end
  if i%64==0 then task.wait() end
 end
 if selector=="@a" then
  local world=director.d.combatState
  if world then
   for id,a in pairs(world.actors) do
    if a.alive and (a.getPosition()-center).Magnitude<=RADIUS and not director.agents[id] then
     local h=a.model:FindFirstChildWhichIsA("Humanoid")
     if h and h.Health>0 and not protectedCharacter(a.model) then h.Health=0;count+=1 elseif not h then a.applyDamage(1e9,"developer:"..tostring(player.UserId));count+=1 end
    end
   end
  end
  for _,p in Players:GetPlayers() do local c=p.Character;local h=if c then c:FindFirstChildWhichIsA("Humanoid") else nil;local pr=characterRoot(p);if h and pr and c and not protectedCharacter(c) and (pr.Position-center).Magnitude<=RADIUS then h.Health=0;count+=1 end end
  local seen:{[Model]:boolean}={}
  local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.MaxParts=0
  for _,part in workspace:GetPartBoundsInRadius(center,RADIUS,overlap) do
   local m=part:FindFirstAncestorOfClass("Model")
   if m and not seen[m] then
    seen[m]=true;local h=m:FindFirstChildWhichIsA("Humanoid")
    if h and h.Health>0 and not protectedCharacter(m) and (m:GetPivot().Position-center).Magnitude<=RADIUS then h.Health=0;count+=1 end
   end
  end
 end
 return {ok=true,count=count,message="Eliminados: "..tostring(count)}
end
function S.new(deps:any,fauna:any,book:any,events:any,flags:any):any
 return {deps=deps,fauna=fauna,book=book,events=events,flags=flags,limits={},connections={},folder=nil}
end
function S.isDeveloper(s:any,player:Player):boolean
 return s.deps.developer.authorized(player.UserId,game.CreatorId,game.CreatorType.Name,s.flags.DeveloperAllowlist)
end
function S.request(s:any,player:Player,op:any,value:any):any
 if player.Parent~=game:GetService("Players") or type(op)~="string" then return {ok=false,error="invalid request"} end
 local now=os.clock();local uid=player.UserId
 local row=s.limits[uid] or {snapshot=-math.huge,command=-math.huge,discover=-math.huge};s.limits[uid]=row
 local developer=S.isDeveloper(s,player)
 if op=="snapshot" then
  if now-row.snapshot<.35 then return {ok=false,error="rate limited"} end
  row.snapshot=now
  if value~="Discovery" and value~="Alphabetical" then return {ok=false,error="invalid sort"} end
  local result=s.deps.persistence.snapshot(s.book,uid,value,developer);result.ok=true;result.developer=developer;return result
 elseif op=="discover" then
  if now-(row.discover or -math.huge)<.5 then return {ok=false,error="rate limited"} end;row.discover=now
  if type(value)~="table" or type(value.id)~="string" then return {ok=false,error="invalid target"} end
  local id=aimedRecord(s,player,value.direction)
  if not id or id~=value.id then return {ok=false,error="invalid aim"} end
  return {ok=s.deps.gameplay.interact(s.events,player,id,now,os.time())}
 elseif op=="command" then
  if not developer then return {ok=false,error="forbidden"} end
  if now-row.command<1 then return {ok=false,error="rate limited"} end;row.command=now
  local direction=nil
  if type(value)=="table" then direction=value.direction;value=value.text end
  if type(value)~="string" or #value>160 then return {ok=false,error="invalid command"} end
  local words={};for word in string.gmatch(value,"%S+") do table.insert(words,word) end
  if #words==1 and (words[1]=="/fly" or words[1]=="/ghost") then return mode(player,string.sub(words[1],2))
  elseif #words==1 and words[1]=="/gold" then return gold(player)
  elseif words[1]=="/kill" then
   if #words>2 then return {ok=false,error="usage: /kill [@e|@a|species ID]"} end
   return kill(s,player,words[2],direction)
  elseif words[1]=="/summon" and words[2]=="status" and #words==2 then
   local j=s.deps.director.developerStatus(s.fauna.director,uid)
   if not j then return {ok=false,error="no summon job"} end
   return {ok=true,count=j.created,message=string.format("Criados: %d/%d %s",j.created,j.count,j.done and (j.reason or "concluído") or "em andamento")}
  end
  local args=s.deps.developer.tokens(value);if not args then return {ok=false,error="invalid command"} end
  local director=s.fauna.director
  local exists=#args>=2 and s.deps.registry.get(args[2])~=nil
  local plan,err=s.deps.summon.parse(args,true,exists,math.huge)
  if not plan then return {ok=false,error=err} end
  local pos:Vector3
  if plan.here then
   local character=player.Character;local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
   if not root or not root:IsA("BasePart") then return {ok=false,error="no character"} end
   pos=root.Position+root.CFrame.LookVector*6
  else local p=plan.position;pos=Vector3.new(p[1],p[2],p[3]) end
  if plan.count>20 then
   if not s.deps.director.queueDeveloper(director,plan,pos,uid) then return {ok=false,error="summon job already running; /summon status"} end
   return {ok=true,count=0,message="Solicitação de "..tostring(plan.count).." aceita. /summon status"}
  end
  local ids,reason=s.deps.director.spawnDeveloper(director,plan,pos,s.fauna.clock)
  print("[CreatureCommand]",uid,plan.speciesId,plan.count,plan.aiEnabled,#ids,reason or "ok")
  return {ok=#ids==plan.count,count=#ids,error=reason}
 end
 return {ok=false,error="unknown operation"}
end
function S.attach(_s:any,_id:string,_record:any)
 -- Discovery uses verified first-person aim; no world-space prompts.
end
function S.start(s:any)
 local rs=game:GetService("ReplicatedStorage")
 assert(not rs:FindFirstChild("RSBookTransport"),"duplicate Book service")
 local folder=Instance.new("Folder");folder.Name="RSBookTransport"
 local remote=Instance.new("RemoteFunction");remote.Name="Request";remote.OnServerInvoke=function(player,op,value)return S.request(s,player,op,value) end;remote.Parent=folder;folder.Parent=rs;s.folder=folder
 table.insert(s.connections,game:GetService("RunService").Heartbeat:Connect(function()
  for c in pairs(collisionSaved) do if not c.Parent then collisionSaved[c]=nil end end
  for _,p in Players:GetPlayers() do
   local c=p.Character;local root=characterRoot(p)
   if c and c:GetAttribute("RSDevMode")=="ghost" then
    local saved=collisionSaved[c] or {};collisionSaved[c]=saved
    for _,part in c:GetDescendants() do if part:IsA("BasePart") then if saved[part]==nil then saved[part]=part.CanCollide end;part.CanCollide=false end end
   end
   if c and root and protectedCharacter(c) then
    local h=c:FindFirstChildWhichIsA("Humanoid")
    if h then h.Health=h.MaxHealth end
    if root.Position.Y<workspace.FallenPartsDestroyHeight+40 then
     local spawn=workspace:FindFirstChildWhichIsA("SpawnLocation",true)
     c:PivotTo(if spawn then spawn.CFrame+Vector3.new(0,8,0) else CFrame.new(0,120,0));root.AssemblyLinearVelocity=Vector3.zero
    end
   end
  end
 end))
 table.insert(s.connections,game:GetService("Players").PlayerRemoving:Connect(function(p)s.limits[p.UserId]=nil;s.deps.gameplay.forgetActor(s.events,p.UserId)end))
end
function S.stop(s:any)
 for _,c in s.connections do c:Disconnect() end;table.clear(s.connections)
 if s.folder then s.folder:Destroy();s.folder=nil end
end
return table.freeze(S)
