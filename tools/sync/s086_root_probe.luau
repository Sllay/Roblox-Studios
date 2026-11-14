-- Read-only, actual owned landmark geometry and terrain profile.
assert(game.GameId==10769712441 and game.PlaceId==93428341652658 and game.PlaceVersion==24,"Staging v24")
local tree=workspace.RSEggydrasilS08
assert(tree:IsA("Model") and tree:GetAttribute("RSManagedId")=="s08:Eggydrasil:central","Landmark")
local A=game:GetService("AssetService")
local T=workspace.Terrain
local pivot=tree:GetPivot()
local bc,sz=tree:GetBoundingBox();assert(math.abs(sz.Y-120)<.02,"Height")
local center=pivot.Position
local x0,z0=math.floor((center.X-64)/4)*4,math.floor((center.Z-64)/4)*4
local y0,y1=-16,80
local region=Region3.new(Vector3.new(x0,y0,z0),Vector3.new(x0+128,y1,z0+128))
local d=T:ReadVoxelChannels(region,4,{"SolidOccupancy","SolidMaterial","LiquidOccupancy"})
local function ground(x,z)
 local i,k=math.floor((x-x0)/4)+1,math.floor((z-z0)/4)+1
 if i<1 or i>32 or k<1 or k>32 then return nil end
 for j=(y1-y0)/4,1,-1 do
  local occ=d.SolidOccupancy[i][j][k]
  if occ>.01 then
   return y0+(j-1)*4+4*occ,d.SolidMaterial[i][j][k].Name
  end
 end
end
local parts={};local bins={};local meshCount=0
local function q(n)return math.round(n*1000)/1000 end
for _,p in tree:GetDescendants() do
 if not p:IsA("MeshPart") then continue end
 meshCount+=1
 local r={name=p.Name,mesh=p.MeshId,size=vec(p.Size),pose={p.CFrame:GetComponents()},collision=p.CanCollide};parts[p.Name]=r
 if not string.match(p.Name,"^Wood_V4") then continue end
 local ok,e=pcall(function()return A:CreateEditableMeshAsync(p.MeshContent,{FixedSize=true})end)
 if not ok or not e then r.error=tostring(e);continue end
 local ids=e:GetVertices();local min=Vector3.new(math.huge,math.huge,math.huge);local max=-min
 for _,id in ids do local v=e:GetPosition(id);min=Vector3.new(math.min(min.X,v.X),math.min(min.Y,v.Y),math.min(min.Z,v.Z));max=Vector3.new(math.max(max.X,v.X),math.max(max.Y,v.Y),math.max(max.Z,v.Z)) end
 local span=max-min;local mid=(max+min)/2
 r.vertices=#ids;r.meshSpan=vec(span);r.meshSize=vec(p.MeshSize)
 assert((span-p.MeshSize).Magnitude<.1,"Mesh size mismatch")
 local low=math.huge;local count=0
 for _,id in ids do
  local v=e:GetPosition(id)-mid
  local world=p.CFrame:PointToWorldSpace(Vector3.new(v.X*p.Size.X/span.X,v.Y*p.Size.Y/span.Y,v.Z*p.Size.Z/span.Z))
  low=math.min(low,world.Y)
  if world.Y<bc.Y-sz.Y/2+32 then
   local i,k=math.floor((world.X-x0)/4),math.floor((world.Z-z0)/4)
   local key=i..":"..k
   if not bins[key] or world.Y<bins[key].y then
    local h,m=ground(world.X,world.Z)
    if h then bins[key]={x=q(world.X),z=q(world.Z),y=q(world.Y),ground=q(h),material=m,gap=q(world.Y-h),radius=q((Vector3.new(world.X,0,world.Z)-Vector3.new(center.X,0,center.Z)).Magnitude)} end
   end
   count+=1
  end
 end
 r.minWorldY=q(low);r.lowerVertices=count;e:Destroy();task.wait()
end
assert(meshCount==5,"Five meshes")
local samples={};for _,r in bins do table.insert(samples,r) end
table.sort(samples,function(a,b)return a.gap<b.gap end)
local candidates={}
for _,delta in {0,4,8,12,16,20,24} do
 local near,buried,exposed,rootNear,rootBuried,rootExposed=0,0,0,0,0,0
 for _,r in samples do
  local g=r.gap-delta
  if math.abs(g)<=2 then near+=1 elseif g<0 then buried+=1 else exposed+=1 end
  if r.radius>=12 then
   if math.abs(g)<=2 then rootNear+=1 elseif g<0 then rootBuried+=1 else rootExposed+=1 end
  end
 end
 table.insert(candidates,{delta=delta,near=near,buried=buried,exposed=exposed,rootNear=rootNear,rootBuried=rootBuried,rootExposed=rootExposed})
end
local h,m=ground(center.X,center.Z)
return syncResult({noPlaceWrites=true,clientRenderVerified=false,pivot={pivot:GetComponents()},bounds=vec(sz),centerGround=h,centerMaterial=m,boundsBottom=bc.Y-sz.Y/2,parts=parts,samples=samples,candidates=candidates,terrainMethod="4-stud solid occupancy approximate; not exact ray surface"})
