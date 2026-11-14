-- S08 isolated integration preview. No save; temporary exact voxel rehydration only.
local W=workspace
local T=W.Terrain
local F=W:FindFirstChild("RSResourcesP45") and W.RSResourcesP45:FindFirstChild("Models")
assert(F and #F:GetChildren()==2000,"Expected live S07 population")
local A=game:GetService("AssetService")
local CP=game:GetService("ContentProvider")
local function part(m)
 local p=nil;local n=0
 for _,o in m:GetDescendants() do
  assert(not o:IsA("LuaSourceContainer"),"Unexpected script "..m.Name)
  if o:IsA("BasePart") then n+=1;p=o end
 end
 assert(n==1 and p and p:IsA("MeshPart"),"Expected one MeshPart in "..m.Name.." parts="..n.." descendants="..#m:GetDescendants())
 return p
end
local function fingerprint()
 local rows={}
 for _,name in cfg.services do
  local root=game:GetService(name)
  for _,o in root:GetDescendants() do
   if not o:IsDescendantOf(F) then
    local r=record(root,o)
    local function canon(x)
     if typeof(x)~="table" then return Http:JSONEncode(x) end
     local keys={};for k in x do table.insert(keys,k) end
     table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
     local a={};for _,k in keys do table.insert(a,Http:JSONEncode(tostring(k))..":"..canon(x[k])) end
     return "{"..table.concat(a,",").."}"
    end
    table.insert(rows,hash(canon(r)))
   end
  end
 end
 table.sort(rows);return hash(table.concat(rows,";"))
end
local before=terrainState();local fp=fingerprint()
local templates={};local loaded={}
for _,r in cfg.assets do
 local m=A:LoadAssetAsync(tonumber(r.assetId));assert(m:IsA("Model") and m.Parent==nil)
 if r.id=="Eggydrasil" then
  local count=0
  for _,o in m:GetDescendants() do
   assert(not o:IsA("LuaSourceContainer"),"Unexpected script")
   if o:IsA("MeshPart") then count+=1 end
  end
  assert(count==5)
 else
  local p=part(m);assert(p.MeshId=="rbxassetid://"..r.meshId,"Mesh mismatch")
  p.TextureID="rbxassetid://"..r.atlasId;p.Color=Color3.new(1,1,1)
  local ok=false;CP:PreloadAsync({p.TextureID},function(_,s) if s==Enum.AssetFetchStatus.Success then ok=true end end)
  assert(ok,"Atlas preload")
 end
 templates[r.id]=m;loaded[r.id]=true
end
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
local counts={Stone=0,Branch=0};local seen={};local saved={};local failures={};local failCount=0
local function fail(id,why)
 failCount+=1;if #failures<50 then table.insert(failures,{id=id,reason=why}) end
end
local maxShift=0;local maxGap=0
local resources=F:GetChildren();table.sort(resources,function(a,b)return a.Name<b.Name end)
for _,m in resources do
 local id=m:GetAttribute("RSManagedId");assert(id==m.Name and not seen[id],"Resource identity");seen[id]=true
 local kind=m:GetAttribute("RSResourceType");kind=if kind=="Stick" then "Branch" else kind
 assert(counts[kind]~=nil,"Unexpected resource type");counts[kind]+=1
 local p=part(m);local original=p:Clone();local cf=p.CFrame;local size=p.Size
 local oldPivot=m:GetPivot()
 local src=part(templates[kind])
 -- Legacy stick was authored upright then rotated Z90. The new branch is authored horizontal along X.
 -- Preserve the world-space long-axis heading, not an incompatible local-axis rotation.
 local frame=cf
 local heading=cf.RightVector
 local factor=math.max(size.X,size.Z)/math.max(src.Size.X,src.Size.Z)
 if kind=="Branch" then
  local length=math.max(size.X,size.Y,size.Z)
  heading=if length==size.Y then cf.UpVector elseif length==size.Z then cf.LookVector else cf.RightVector
  local center=ground(cf.X,cf.Z)
  if center then
   local up=center.Normal.Unit
   local right=(heading-up*heading:Dot(up)).Unit
   frame=CFrame.fromMatrix(cf.Position,right,up,right:Cross(up))
  end
  factor=length/src.Size.X
 end
 local newSize=src.Size*factor
 p:ApplyMesh(src);p.Size=newSize;p.CFrame=frame;p.Color=Color3.new(1,1,1);p.TextureID=src.TextureID
 assert(p.MeshId==src.MeshId and p.TextureID==src.TextureID and p.Anchored==original.Anchored and p.CanCollide==original.CanCollide and p.CollisionGroup==original.CollisionGroup,"Replacement contract")
 local low,high=math.huge,-math.huge
 for _,a in {{0,0},{-.42,0},{.42,0},{0,-.42},{0,.42},{-.42,-.42},{.42,-.42},{-.42,.42},{.42,.42}} do
  local q=frame:PointToWorldSpace(Vector3.new(a[1]*newSize.X,-newSize.Y/2,a[2]*newSize.Z))
  local h=ground(q.X,q.Z)
  if not h then low=math.huge;break end
  local gap=q.Y-h.Position.Y;low=math.min(low,gap);high=math.max(high,gap)
 end
 if low==math.huge then fail(id,"terrain-ray-miss")
 else
  local lift=.01-low;local gap=high-low+.01
  p.CFrame=frame+Vector3.yAxis*lift
  maxShift=math.max(maxShift,math.abs(lift));maxGap=math.max(maxGap,gap)
  if gap>.22 or math.abs(lift)>2 then fail(id,"support-gap-or-height") end
 end
 assert(p.CFrame.X==cf.X and p.CFrame.Z==cf.Z and math.abs(p.CFrame.RightVector:Dot(heading))>.95,"XZ/heading changed")
 table.insert(saved,{model=m,p=p,original=original,pivot=oldPivot,cf=cf,size=size})
end
assert(counts.Stone==1000 and counts.Branch==1000)
local op=OverlapParams.new();op.FilterType=Enum.RaycastFilterType.Include;op.FilterDescendantsInstances={F,W.RSVegetationS06.Collisions};op.MaxParts=0
for _,s in saved do
 for _,o in W:GetPartBoundsInBox(s.p.CFrame,s.p.Size,op) do
  if o~=s.p then fail(s.model.Name,"overlap:"..o.Name);break end
 end
end
-- Tree site proposal only; never displace existing resources or vegetation.
local tree=templates.Eggydrasil;local _,initial=tree:GetBoundingBox()
local height=60;tree:ScaleTo(tree:GetScale()*height/initial.Y)
local tc,ts=tree:GetBoundingBox()
local treePivot=tree:GetPivot()
local offset=tc.Position-treePivot.Position
local site=nil;local tried=0
local spawns={};for _,o in W:GetDescendants() do if o:IsA("SpawnLocation") then table.insert(spawns,o.Position) end end
local wood=tree:FindFirstChild("Wood_V4",true);assert(wood and wood:IsA("MeshPart"))
local siteParams=OverlapParams.new();siteParams.FilterType=Enum.RaycastFilterType.Include;siteParams.FilterDescendantsInstances={F,W.RSVegetationS06.Collisions};siteParams.MaxParts=1
for _,region in cfg.regions do
 if site then break end
 if not region.playable then continue end
 local b=region.bounds
 for x=b[1]+24,b[4]-24,16 do
  if site then break end
  for z=b[3]+24,b[6]-24,16 do
   tried+=1
   local h=ground(x,z)
   local far=true;for _,p in spawns do if (Vector3.new(x,p.Y,z)-p).Magnitude<80 then far=false;break end end
   if h and h.Normal.Y>.94 and far then
    local clear=true;local radius=math.max(ts.X,ts.Z)*.5
    for _,a in {{0,0},{.3,0},{-.3,0},{0,.3},{0,-.3}} do
     local q=ground(x+a[1]*radius,z+a[2]*radius)
     if not q or math.abs(q.Position.Y-h.Position.Y)>3 then clear=false;break end
    end
    if clear then
     local center=Vector3.new(x,h.Position.Y+ts.Y/2,z)
     if #W:GetPartBoundsInBox(CFrame.new(center),ts,siteParams)==0 then
      tree:PivotTo(CFrame.new(center-offset)*treePivot.Rotation)
      tree.Name="EggydrasilS08Preview";tree.Parent=W
      site={position={x,h.Position.Y,z},height=ts.Y,bounds=vec(ts),scale=tree:GetScale(),pivot={tree:GetPivot():GetComponents()}}
      break
     end
    end
   end
  end
 end
end
local tint={}
for _,name in {"Canopy_White","Canopy_Gray"} do
 local p=tree:FindFirstChild(name,true);local sa=p and p:FindFirstChildWhichIsA("SurfaceAppearance")
 assert(sa and sa.AlphaMode==Enum.AlphaMode.Transparency and p.DoubleSided and not p.CanCollide,"Foliage contract")
 local color=if name=="Canopy_White" then Color3.fromRGB(255,80,140) else Color3.fromRGB(120,40,200)
 sa.Color=color;assert(sa.Color==color);tint[name]={uri=sa.ColorMapContent.Uri,color=rgb(sa.Color)}
end
tree.Parent=nil
-- Restore exact original objects/properties; no write to published Place.
for _,s in saved do
 s.p:ApplyMesh(s.original);s.p.Size=s.size;s.p.CFrame=s.cf;s.p.Color=s.original.Color;s.p.TextureID=s.original.TextureID
 assert(s.p.MeshId==s.original.MeshId and s.p.Size==s.original.Size and s.p.CFrame==s.cf,"Inverse mesh")
 s.original:Destroy()
end
for _,m in templates do m:Destroy() end
local after=terrainState();assert(#before==49 and #after==49,"Terrain coverage")
for i,r in after do assert(r.digest==before[i].digest,"Terrain changed") end
assert(fingerprint()==fp,"Non-resource scene changed")
return syncResult({noPlaceWrites=true,terrainRehydratedBlocks=rehydrated,counts=counts,loadedAssets=loaded,resourceFailures=failCount,failures=failures,maxVerticalShift=maxShift,maxSupportGap=maxGap,terrain=after,nonResourceFingerprint=fp,treeSite=site,treeSitesTried=tried,tint=tint,clientRenderVerified=false,readyForVisualReview=failCount==0 and site~=nil})
