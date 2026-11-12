import os,json
from deploy import load_all,resolve
from scene_sync import task,write,ROOT
g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
source="""do
local T=workspace.Terrain
local P=game:GetService("PhysicsService")
local props={}
for _,k in {"CanCollide","CanQuery","CanTouch","CollisionGroup","Anchored"} do
 local ok,v=pcall(function() return T[k] end);props[k]=if ok then tostring(v) else tostring(v)
end
local groups=P:GetRegisteredCollisionGroups()
local matrix={}
for _,a in groups do for _,b in groups do table.insert(matrix,{a.name,b.name,P:CollisionGroupsAreCollidable(a.name,b.name)}) end end
local rays={}
for _,s in workspace.RSCentralSpawns:GetChildren() do
 if s:IsA("SpawnLocation") and #rays<4 then
 local p=s.Position
 local a=RaycastParams.new();a.FilterType=Enum.RaycastFilterType.Include;a.FilterDescendantsInstances={T}
 local b=RaycastParams.new();b.FilterType=Enum.RaycastFilterType.Include;b.FilterDescendantsInstances={T};b.BruteForceAllSlow=true
 local function hit(params)
 local ok,h=pcall(function() return workspace:Raycast(p+Vector3.new(0,80,0),Vector3.new(0,-200,0),params) end)
 return if ok and h then {name=h.Instance.Name,y=h.Position.Y} elseif ok then "nil" else tostring(h)
 end
 table.insert(rays,{name=s.Name,position=vec(p),normal=hit(a),brute=hit(b)})
 end
end
local result={universeId=tostring(game.GameId),placeId=tostring(game.PlaceId),terrain=props,groups=groups,matrix=matrix,rays=rays}
return Http:JSONEncode(result)
end"""
r=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],source)
write(ROOT/"dist/physics-probe/result.json",r)
print("PHYSICS_PROBE",json.dumps(r),flush=True)
