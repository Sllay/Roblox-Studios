-- S08.2: existing landmark scale/contact and deterministic fallen-log placement.
local W=workspace
local T=W.Terrain
local A=game:GetService("AssetService")
local CP=game:GetService("ContentProvider")
local F=W.RSResourcesP45.Models
local V=W.RSVegetationS06.Models
local tree=W:FindFirstChild("RSEggydrasilS08")
assert(game.PlaceId==93428341652658 and game.GameId==10769712441 and game.PlaceVersion==20,"Staging v20 only")
assert(tree and #F:GetChildren()==1000 and not W:FindFirstChild("RSFallenLogsS082"),"Baseline")
local function q(n)return math.round(n*10000)/10000 end
local function v(p)return {q(p.X),q(p.Y),q(p.Z)} end
local function frame(cf)local a={cf:GetComponents()};for i,n in a do a[i]=q(n) end;return a end
local function canon(x)
 if typeof(x)~="table" then return Http:JSONEncode(x) end
 local keys={};for k in x do table.insert(keys,k) end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in keys do table.insert(out,Http:JSONEncode(tostring(k))..":"..canon(x[k])) end
 return "{"..table.concat(out,",").."}"
end
local function fingerprint()
 local rows={}
 for _,name in cfg.services do
  local svc=game:GetService(name)
  local logs=W:FindFirstChild("RSFallenLogsS082")
  for _,o in svc:GetDescendants() do
   if o~=tree and not o:IsDescendantOf(tree) and o~=logs and not (logs and o:IsDescendantOf(logs)) then table.insert(rows,hash(canon(record(svc,o)))) end
  end
 end
 table.sort(rows);return hash(table.concat(rows,";"))
end
local counts={trees=0,pines=0,bushes=0,largeRocks=0,stone=0,stick=0,eggydrasil=0,unknown=0}
local species={};local tiles={}
local function tile(x,z)return "chunk-"..math.floor((x+128)/256).."-"..math.floor((z+128)/256) end
local function countModel(m,kind)
 counts[kind]+=1
 local p=m:GetPivot().Position;local k=tile(p.X,p.Z)
 tiles[k]=tiles[k] or {};tiles[k][kind]=(tiles[k][kind] or 0)+1
end
for _,m in V:GetChildren() do
 assert(m:IsA("Model"))
 local s=m:GetAttribute("RSSpecies") or "";species[s]=(species[s] or 0)+1
 local k=if string.sub(s,1,5)=="Pine_" then "pines" elseif string.sub(s,1,5)=="Tree_" then "trees" elseif string.sub(s,1,5)=="Bush_" then "bushes" else "unknown"
 countModel(m,k)
end
for _,m in W.RSEnvironmentP4Detail.Models:GetChildren() do
 if m:IsA("Model") and m:GetAttribute("RSSpecies")=="Mossy_Rock1_M_Mossy_Rock_0_Node" then countModel(m,"largeRocks") end
end
for _,m in F:GetChildren() do
 local k=m:GetAttribute("RSResourceType")
 assert(k=="Stone" or k=="Stick")
 countModel(m,if k=="Stone" then "stone" else "stick")
end
countModel(tree,"eggydrasil")
assert(counts.unknown==0 and counts.stone==500 and counts.stick==500)
local before=terrainState();local fp=fingerprint()
local wood={}
for _,p in tree:GetDescendants() do
 if p:IsA("MeshPart") and string.sub(p.Name,1,7)=="Wood_V4" then
  table.insert(wood,{name=p.Name,meshId=p.MeshId,texture=p.TextureID,size=v(p.Size),pose=frame(p.CFrame),canCollide=p.CanCollide,collisionFidelity=p.CollisionFidelity.Name})
 end
end
assert(#wood==3)
local audit={counts=counts,species=species,tiles=tiles,wood=wood,noPlaceWrites=true,clientRenderVerified=false}
if cfg.mode=="audit" then return syncResult(audit) end
assert(cfg.mode=="preview","Read-only preview only")
local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances={T};ray.IgnoreWater=false;ray.RespectCanCollide=true
local function ground(x,z)
 local h=W:Raycast(Vector3.new(x,512,z),Vector3.new(0,-1024,0),ray)
 if h and (h.Material==Enum.Material.Grass or h.Material==Enum.Material.Ground) then return h end
end
-- Historical Open Cloud sessions load voxels without a usable terrain collision mesh.
-- Rehydrate exact channels in playable regions only, following the proven S06/S07 method.
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local function write(region,d) T:WriteVoxelChannels(region,4,{SolidMaterial=d.SolidMaterial,SolidOccupancy=d.SolidOccupancy,LiquidOccupancy=d.LiquidOccupancy}) end
local rehydrated=0
for _,r in cfg.regions do
 if r.playable then
  local b=r.bounds
  for x=b[1],b[4]-64,64 do
   for z=b[3],b[6]-64,64 do
    local region=Region3.new(Vector3.new(x,b[2],z),Vector3.new(x+64,b[5],z+64))
    local original=T:ReadVoxelChannels(region,4,channels)
    local empty=T:ReadVoxelChannels(region,4,channels)
    for i=1,16 do for j=1,(b[5]-b[2])/4 do for k=1,16 do
     empty.SolidMaterial[i][j][k]=Enum.Material.Air;empty.SolidOccupancy[i][j][k]=0;empty.LiquidOccupancy[i][j][k]=0
    end end end
    write(region,empty);write(region,original);rehydrated+=1
   end
  end
 end
end
task.wait(1)


local oldPivot=tree:GetPivot();local oldScale=tree:GetScale()
local oldCf,oldSize=tree:GetBoundingBox()
assert(math.abs(oldSize.Y-60)<.01)
local x,z=oldCf.X,oldCf.Z
local h=ground(x,z);assert(h,"Tree ground")
local originalParts={}
for _,p in tree:GetDescendants() do
 if p:IsA("MeshPart") then originalParts[p.Name]={id=p.MeshId,collide=p.CanCollide,query=p.CanQuery,size=p.Size,relative=oldPivot:ToObjectSpace(p.CFrame)} end
end
tree:ScaleTo(oldScale*2)
local cf,sz=tree:GetBoundingBox();local depth=.35
local delta=Vector3.new(x,h.Position.Y+sz.Y/2-depth,z)-cf.Position
tree:PivotTo(tree:GetPivot()+delta)
cf,sz=tree:GetBoundingBox()
assert(math.abs(sz.Y-120)<.02 and math.abs(cf.Y-sz.Y/2-h.Position.Y+depth)<.01,"Scale/contact")
for _,p in tree:GetDescendants() do
 if p:IsA("MeshPart") then
  local a=originalParts[p.Name];assert(a and p.MeshId==a.id and p.CanCollide==a.collide and p.CanQuery==a.query and (p.Size-a.size*2).Magnitude<.01,"Geometry/collision changed")
  local relative=tree:GetPivot():ToObjectSpace(p.CFrame)
  assert((relative.Position-a.relative.Position*2).Magnitude<.02,"Proportion drift")
 end
end
-- Detect actual wood collision at the player spawn envelope, not the entire canopy bounding box.
local tr=RaycastParams.new();tr.FilterType=Enum.RaycastFilterType.Include;tr.FilterDescendantsInstances={tree};tr.RespectCanCollide=true
local spawnBlocked={};local spawnChecked=0
for _,s in W:GetDescendants() do
 if s:IsA("SpawnLocation") and s.Enabled then
  local p=s.Position
  if math.abs(p.X-x)<sz.X/2+8 and math.abs(p.Z-z)<sz.Z/2+8 then
   spawnChecked+=1
   for _,d in {{0,0},{2,0},{-2,0},{0,2},{0,-2}} do
    local o=Vector3.new(p.X+d[1],p.Y+8,p.Z+d[2])
    local hit=W:Raycast(o,Vector3.new(0,-10,0),tr)
    if hit then table.insert(spawnBlocked,s.Name);break end
   end
  end
 end
end
-- Logs use the approved single-mesh asset, not a new model.
local m=A:LoadAssetAsync(72836155682285)
local p=m:FindFirstChildWhichIsA("MeshPart",true);assert(p and p.MeshId=="rbxassetid://84426557612247")
local n=0;for _,o in m:GetDescendants() do if o:IsA("BasePart") then n+=1 end;assert(not o:IsA("LuaSourceContainer")) end;assert(n==1)
p.TextureID="rbxassetid://129687460952107";p.Color=Color3.new(1,1,1)
local loaded=false;CP:PreloadAsync({p.TextureID},function(_,status)if status==Enum.AssetFetchStatus.Success then loaded=true end end);assert(loaded,"Log atlas")
local root=Instance.new("Folder");root.Name="RSFallenLogsS082";root:SetAttribute("RSOwner","RSFallenLogsS082V1");root.Parent=W
local obstacles={F,W.RSVegetationS06.Collisions,W.RSEnvironmentP4Detail.Models,root,tree,W.RSCentralSpawns}
local op=OverlapParams.new();op.FilterType=Enum.RaycastFilterType.Include;op.FilterDescendantsInstances=obstacles;op.MaxParts=1
local rows={};local rejected=0;local maxGap=0
local regions={};for _,r in cfg.regions do if r.playable then table.insert(regions,r) end end;table.sort(regions,function(a,b)return a.id<b.id end);assert(#regions==9)
local rng=Random.new(820250)
for i,r in regions do
 local quota=if i<=7 then 28 else 27
 local b=r.bounds;local placed=0;local sites={}
 for xx=b[1]+8,b[4]-8,8 do for zz=b[3]+8,b[6]-8,8 do table.insert(sites,{xx,zz}) end end
 for j=#sites,2,-1 do local k=rng:NextInteger(1,j);sites[j],sites[k]=sites[k],sites[j] end
 for _,a in sites do
  if placed>=quota then break end
  local xx=a[1]+rng:NextNumber(-2,2);local zz=a[2]+rng:NextNumber(-2,2)
  local g=ground(xx,zz)
  if not g or g.Normal.Y<.94 or (Vector2.new(xx-x,zz-z)).Magnitude<24 then rejected+=1;continue end
  local yaw=rng:NextNumber(0,math.pi*2);local direction=Vector3.new(math.cos(yaw),0,math.sin(yaw))
  local up=g.Normal.Unit;local right=(direction-up*direction:Dot(up)).Unit
  local scale=rng:NextNumber(1.25,1.75)
  local size=p.Size*scale
  local f=CFrame.fromMatrix(Vector3.new(xx,g.Position.Y,zz),right,up,right:Cross(up))
  local low,high=math.huge,-math.huge
  for _,o in {{0,0},{-.42,0},{.42,0},{0,-.42},{0,.42},{-.42,-.42},{.42,-.42},{-.42,.42},{.42,.42}} do
   local pt=f:PointToWorldSpace(Vector3.new(o[1]*size.X,-size.Y/2,o[2]*size.Z))
   local hit=ground(pt.X,pt.Z)
   if not hit then low=math.huge;break end
   local gap=pt.Y-hit.Position.Y;low=math.min(low,gap);high=math.max(high,gap)
  end
  if low==math.huge or high-low+.01>.22 then rejected+=1;continue end
  f=f+Vector3.yAxis*(.01-low)
  if #W:GetPartBoundsInBox(f,size+Vector3.new(.5,.1,.5),op)>0 then rejected+=1;continue end
  placed+=1
  local id="s082:Log:"..r.id..":"..string.format("%03d",placed)
  local model=m:Clone();model.Name=id;model:SetAttribute("RSManagedId",id);model:SetAttribute("RSResourceType","Log");model:SetAttribute("RSResourceVariant","v1");model:SetAttribute("RSResourceState","decorative");model:SetAttribute("RSResourceChunk",r.id);model:SetAttribute("RSBuriedDepth",0)
  local mesh=model:FindFirstChildWhichIsA("MeshPart",true)
  mesh.Size=size;mesh.CFrame=f;mesh.Anchored=true;mesh.CanCollide=true;mesh.CanQuery=true;mesh.CanTouch=false;mesh.CollisionGroup="Default"
  model.Parent=root
  table.insert(rows,{id=id,tile=r.id,size=v(size),pose=frame(f),gap=q(high-low+.01)})
  maxGap=math.max(maxGap,high-low+.01)
 end
 assert(placed==quota,"Log quota "..r.id.." "..placed)
end
assert(#rows==250 and #root:GetChildren()==250)
local after=terrainState();assert(#after==49 and #before==49)
for i,r in after do assert(r.digest==before[i].digest,"Terrain changed") end
assert(fingerprint()==fp,"Unrelated scene changed")
return syncResult({audit=audit,tree={height=sz.Y,scale=tree:GetScale(),oldScale=oldScale,groundY=h.Position.Y,burial=depth,center=v(cf.Position),pivot=frame(tree:GetPivot()),spawnChecked=spawnChecked,spawnBlocked=spawnBlocked,geometryPreserved=true},logs={count=#rows,rows=rows,maxSupportGap=maxGap,rejected=rejected,meshId=p.MeshId,textureId=p.TextureID},terrain=after,nonResourceFingerprint=fp,readyForStaging=#spawnBlocked==0,noPlaceWrites=true,clientRenderVerified=false})
