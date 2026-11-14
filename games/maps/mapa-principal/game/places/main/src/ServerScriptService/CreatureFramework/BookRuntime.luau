--!strict
-- Explicit runtime wiring; no Player lifecycle hooks or persistent writes before start().
local R={}
function R.new(deps:any):any
 local book=deps.persistence.new(deps.core,deps.registry,deps.store.new("BlackIslands_Book_v1",nil))
 return {deps=deps,book=book,connections={},running=false,closed=false}
end
function R.start(s:any)
 assert(not s.running and not s.closed,"Book service already started")
 s.running=true
 local players=game:GetService("Players")
 local function join(player:Player)
  local p=s.deps.persistence.session(s.book,player.UserId);p.leaving=false
 end
 local function leave(player:Player)
  local p=s.deps.persistence.session(s.book,player.UserId);p.leaving=true
  -- The bounded worker retries until clean; do not discard dirty data on leave.
 end
 table.insert(s.connections,players.PlayerAdded:Connect(join))
 table.insert(s.connections,players.PlayerRemoving:Connect(leave))
 for _,p in players:GetPlayers() do join(p) end
 task.spawn(function()
  while s.running do s.deps.persistence.tick(s.book,os.clock(),2);task.wait(1) end
 end)
 game:BindToClose(function()
  s.running=false
  local deadline=os.clock()+25
  while os.clock()<deadline do
   local pending=false
   for _,p in pairs(s.book.sessions) do if p.dirty then pending=true;break end end
   if not pending then break end
   s.deps.persistence.tick(s.book,os.clock(),4)
   task.wait(.25)
  end
 end)
end
function R.stop(s:any)
 if s.closed then return end
 s.running=false;s.closed=true
 for _,c in s.connections do c:Disconnect() end
 table.clear(s.connections)
end
function R.validateInteraction(actor:Player,record:any):boolean
 if actor.Parent~=game:GetService("Players") then return false end
 local character=actor.Character;if not character then return false end
 local root=character:FindFirstChild("HumanoidRootPart");local humanoid=character:FindFirstChildWhichIsA("Humanoid")
 if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health<=0 then return false end
 local mesh=record.adapter.mesh
 local delta=mesh.Position-root.Position
 if delta.Magnitude>8 then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={character,record.adapter.model};params.IgnoreWater=false
 return workspace:Raycast(root.Position,delta,params)==nil
end
return table.freeze(R)
