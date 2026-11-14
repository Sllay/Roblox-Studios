-- S08.1: deterministic 50% thinning, two visual variants per gameplay type,
-- one central Eggydrasil. Preview disposable; apply only the reviewed staging plan.
local W=workspace
local T=W.Terrain
local F=W:FindFirstChild("RSResourcesP45") and W.RSResourcesP45:FindFirstChild("Models")
assert(F and game.PlaceId==93428341652658 and game.GameId==10769712441,"Staging target")
local A=game:GetService("AssetService")
local CP=game:GetService("ContentProvider")
local function part(m)
 local p=nil;local n=0
 for _,o in m:GetDescendants() do
  assert(not o:IsA("LuaSourceContainer"),"Unexpected resource script")
  if o:IsA("BasePart") then n+=1;p=o end
 end
 assert(n==1 and p and p:IsA("MeshPart"),"Expected single MeshPart "..m.Name)
 return p
end
local function canon(x)
 if typeof(x)~="table" then return Http:JSONEncode(x) end
 local keys={};for k in x do table.insert(keys,k) end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
 local a={};for _,k in keys do table.insert(a,Http:JSONEncode(tostring(k))..":"..canon(x[k])) end
 return "{"..table.concat(a,",").."}"
end
local function fingerprint(full)
 local rows={};local egg=W:FindFirstChild("RSEggydrasilS08")
 for _,name in cfg.services do
  local root=game:GetService(name)
  for _,o in root:GetDescendants() do
   if full or (o~=F and not o:IsDescendantOf(F) and o~=egg and not (egg and o:IsDescendantOf(egg))) then
    table.insert(rows,hash(canon(record(root,o))))
   end
  end
 end
 table.sort(rows);return hash(table.concat(rows,";"))
end
local function q(x)return math.round(x*10000)/10000 end
local function qv(v)return {q(v.X),q(v.Y),q(v.Z)} end
local function qcf(cf)
 local a={cf:GetComponents()};for i,v in a do a[i]=q(v) end;return a
end
local assets={};for _,r in cfg.assets do assets[r.id]=r end
local function resourceDigest()
 local rows={}
 for _,m in F:GetChildren() do
  local p=part(m)
  local a={m.Name,m:GetAttribute("RSResourceType"),m:GetAttribute("RSResourceVariant"),m:GetAttribute("RSResourceAssetId"),p.MeshId,p.TextureID,qv(p.Size),qcf(p.CFrame)}
  table.insert(rows,Http:JSONEncode(a))
 end
 table.sort(rows);return hash(table.concat(rows,";"))
end
local function population(legacyIds)
 local c={Stone={legacy=0,v1=0},Stick={legacy=0,v1=0}}
 local ids={};local tiles={}
 for _,m in F:GetChildren() do
  local k=m:GetAttribute("RSResourceType");local v=m:GetAttribute("RSResourceVariant")
  local id=m:GetAttribute("RSManagedId");local tile=m:GetAttribute("RSResourceChunk")
  assert(id==m.Name and not ids[id] and c[k] and c[k][v]~=nil and typeof(tile)=="string","Resource identity/variant")
  ids[id]=true;c[k][v]+=1
  local p=part(m);local spec=assets[if k=="Stick" then "Branch" else "Stone"]
  assert(p.Anchored and p.CanCollide and p.CanQuery and not p.CanTouch and p.CollisionGroup=="RSNaturalResource","Resource collision policy")
  assert(m:GetAttribute("RSBuriedDepth")==0 and m:GetAttribute("RSResourceState")=="decorative","Resource state")
  if v=="v1" then
   assert(p.MeshId=="rbxassetid://"..spec.meshId and p.TextureID=="rbxassetid://"..spec.atlasId and m:GetAttribute("RSResourceAssetId")==spec.assetId,"New variant binding")
  else
   assert(p.MeshId==legacyIds[k] and p.MeshId~="rbxassetid://"..spec.meshId,"Legacy binding")
  end
  if not tiles[tile] then tiles[tile]={Stone={legacy=0,v1=0},Stick={legacy=0,v1=0}} end
  tiles[tile][k][v]+=1
 end
 assert(#F:GetChildren()==1000 and c.Stone.legacy==250 and c.Stone.v1==250 and c.Stick.legacy==250 and c.Stick.v1==250,"Population balance")
 return c,tiles
end
local function treeProof(tree)
 assert(tree and tree:IsA("Model") and tree:GetAttribute("RSManagedId")=="s08:Eggydrasil:central","Tree identity")
 local count=0;local foliage={};local meshRows={}
 for _,o in tree:GetDescendants() do
  assert(not o:IsA("LuaSourceContainer"),"Unexpected tree script")
  if o:IsA("MeshPart") then
   count+=1;assert(o.Anchored,"Tree not anchored")
   table.insert(meshRows,Http:JSONEncode({o.Name,o.MeshId,qv(o.Size),qcf(o.CFrame)}))
  end
 end
 assert(count==5,"Tree mesh count")
 for _,name in {"Canopy_White","Canopy_Gray"} do
  local p=tree:FindFirstChild(name,true);local sa=p and p:FindFirstChildWhichIsA("SurfaceAppearance")
  local uri=if name=="Canopy_White" then "rbxassetid://89626593244521" else "rbxassetid://109528136250293"
  local color=if name=="Canopy_White" then Color3.fromRGB(255,80,140) else Color3.fromRGB(120,40,200)
  assert(sa and sa.ColorMapContent.Uri==uri and (Vector3.new(sa.Color.R,sa.Color.G,sa.Color.B)-Vector3.new(color.R,color.G,color.B)).Magnitude<.007 and sa.AlphaMode==Enum.AlphaMode.Transparency and p.DoubleSided and not p.CanCollide and not p.CanTouch and not p.CanQuery,"Foliage binding")
  foliage[name]={uri=uri,color=rgb(sa.Color)}
 end
 local cf,size=tree:GetBoundingBox()
 assert(math.abs(size.Y-60)<.02 and math.abs(cf.X)<128 and math.abs(cf.Z)<128,"Central tree size/site")
 table.sort(meshRows)
 return {center=qv(cf.Position),bounds=qv(size),pivot=qcf(tree:GetPivot()),foliage=foliage,meshCount=count,digest=hash(table.concat(meshRows,";"))}
end
local before=terrainState()
if cfg.mode=="verify" then
 assert(#before==49,"Terrain coverage")
 for _,r in before do assert(cfg.expectedTerrain[r.id]==r.digest,"Persisted terrain "..r.id) end
 local c,tiles=population(cfg.legacyMeshIds)
 local tree=treeProof(W:FindFirstChild("RSEggydrasilS08"))
 assert(resourceDigest()==cfg.expectedDigest,"Persisted resource digest")
 assert(tree.digest==cfg.expectedTreeDigest,"Persisted tree geometry")
 local fp=fingerprint(false)
 assert(fp==cfg.expectedNonResource or fp==cfg.originalNonResource,"Unexpected non-resource persistence")
 return syncResult({verified=true,noPlaceWrites=true,counts=c,tiles=tiles,resourcePlanDigest=resourceDigest(),tree=tree,terrain=before,nonResourceFingerprint=fp,controllerState=if fp==cfg.expectedNonResource then "corrected" else "unchanged",clientRenderVerified=false})
end
assert(cfg.mode=="preview" or cfg.mode=="apply","Mode")
assert(#F:GetChildren()==2000 and not W:FindFirstChild("RSEggydrasilS08"),"Expected v19 baseline")
local originalFp=fingerprint(false)
-- Normalize only the exact, previously reviewed S07 automatic controller clone delta.
-- The complete scene fingerprint must match the reviewed S07 migration afterward.
local sp=game:GetService("StarterPlayer")
local roots={}
for _,o in sp:GetChildren() do if o.Name=="PlayerModule" and o:IsA("ModuleScript") then table.insert(roots,o) end end
local sounds=sp.StarterPlayerScripts:FindFirstChild("RbxCharacterSounds")
local binding=sounds and sounds:FindFirstChild("AtomicBinding")
assert(binding and binding:IsA("ModuleScript"),"S07 controller guard")
local leaves={}
for _,o in binding:GetChildren() do if o.Name=="AtomicBinding" and o:IsA("ModuleScript") then table.insert(leaves,o) end end
if #roots==19 and #leaves==18 then
 local extra=roots[19];local leaf=leaves[18]
 assert(#extra:GetDescendants()==161 and #leaf:GetChildren()==0 and leaf.Source==binding.Source,"Unexpected S07 clone")
 extra.Parent=nil;leaf.Parent=nil
end
assert(fingerprint(true)=="ySxfudxWOEwaZ7JXZZHmsdSMh2jameRPnQS22M2pIT4=","S07 exact reviewed baseline")
local fp=fingerprint(false)
if cfg.mode=="apply" then
 assert(cfg.confirmStaging and fp==cfg.expectedNonResource and originalFp==cfg.originalNonResource,"Reviewed non-resource baseline")
 for _,r in before do assert(cfg.expectedTerrain[r.id]==r.digest,"Reviewed terrain baseline") end
end
local templates={}
for _,key in {"Stone","Branch","Eggydrasil"} do
 local r=assets[key];local m=A:LoadAssetAsync(tonumber(r.assetId))
 assert(m and m:IsA("Model") and m.Parent==nil,"Asset load "..key)
 if key~="Eggydrasil" then
  local p=part(m);assert(p.MeshId=="rbxassetid://"..r.meshId,"Mesh mismatch")
  p.TextureID="rbxassetid://"..r.atlasId;p.Color=Color3.new(1,1,1)
  local ok=false;CP:PreloadAsync({p.TextureID},function(_,status) if status==Enum.AssetFetchStatus.Success then ok=true end end)
  assert(ok,"Atlas preload")
 end
 templates[key]=m
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

-- Choose the closest safe position to the exact center of the nine chunks.
local tree=templates.Eggydrasil
local _,initial=tree:GetBoundingBox();tree:ScaleTo(tree:GetScale()*60/initial.Y)
local tc,ts=tree:GetBoundingBox();local tp=tree:GetPivot()
local offset=tc.Position-tp.Position
local obstacles={W.RSVegetationS06.Collisions}
local detail=W:FindFirstChild("RSEnvironmentP4Detail");if detail and detail:FindFirstChild("Models") then table.insert(obstacles,detail.Models) end
local fixed=OverlapParams.new();fixed.FilterType=Enum.RaycastFilterType.Include;fixed.FilterDescendantsInstances=obstacles;fixed.RespectCanCollide=true;fixed.MaxParts=1
local spawns={}
for _,o in W:GetDescendants() do if o:IsA("SpawnLocation") and o.Enabled then table.insert(spawns,o.Position) end end
local positions={}
for x=-96,96,4 do for z=-96,96,4 do table.insert(positions,{x=x,z=z,d=x*x+z*z}) end end
table.sort(positions,function(a,b)if a.d~=b.d then return a.d<b.d end;if a.x~=b.x then return a.x<b.x end;return a.z<b.z end)
local site=nil;local tries=0
for _,p in positions do
 tries+=1;local x,z=p.x,p.z;local h=ground(x,z)
 local far=true
 for _,v in spawns do if (Vector3.new(x,v.Y,z)-v).Magnitude<14 then far=false;break end end
 if h and h.Normal.Y>.94 and far then
  local clear=true;local radius=math.max(ts.X,ts.Z)*.3
  for _,a in {{0,0},{1,0},{-1,0},{0,1},{0,-1},{.7,.7},{-.7,.7},{.7,-.7},{-.7,-.7}} do
   local g=ground(x+a[1]*radius,z+a[2]*radius)
   if not g or math.abs(g.Position.Y-h.Position.Y)>3 then clear=false;break end
  end
  local center=Vector3.new(x,h.Position.Y+ts.Y/2,z)
  if clear and #W:GetPartBoundsInBox(CFrame.new(center),ts,fixed)==0 then
   tree:PivotTo(CFrame.new(center-offset)*tp.Rotation)
   site={x=x,z=z,groundY=h.Position.Y,distanceFromCenter=math.sqrt(p.d),height=ts.Y,tries=tries}
   break
  end
 end
end
assert(site,"No safe Eggydrasil site in the central chunk")
tree.Name="RSEggydrasilS08";tree:SetAttribute("RSManagedId","s08:Eggydrasil:central");tree:SetAttribute("RSAssetId",assets.Eggydrasil.assetId);tree:SetAttribute("RSSpecies","Eggydrasil")
for _,o in tree:GetDescendants() do
 if o:IsA("MeshPart") then
  o.Anchored=true;o.CanTouch=false
  if o.Name=="Canopy_White" or o.Name=="Canopy_Gray" then
   local sa=o:FindFirstChildWhichIsA("SurfaceAppearance");assert(sa,"Missing foliage surface")
   sa.Color=if o.Name=="Canopy_White" then Color3.fromRGB(255,80,140) else Color3.fromRGB(120,40,200)
   o.CanCollide=false;o.CanQuery=false;o.DoubleSided=true
  else o.CanCollide=true;o.CanQuery=true;o.CollisionGroup="Default" end
 end
end
local treeCf,treeSize=tree:GetBoundingBox()
local rp=OverlapParams.new();rp.FilterType=Enum.RaycastFilterType.Include;rp.FilterDescendantsInstances={F};rp.MaxParts=0
local blocked={}
for _,p in W:GetPartBoundsInBox(treeCf,treeSize+Vector3.new(6,4,6),rp) do
 local m=p:FindFirstAncestorOfClass("Model")
 if m and m.Parent==F then blocked[m]=true end
end
-- Preserve each tile's density proportion. Stable hash ordering avoids spatial bias.
local groups={Stone={},Stick={}};local originalCounts={Stone=0,Stick=0};local legacyIds={};local seen={}
for _,m in F:GetChildren() do
 local k=m:GetAttribute("RSResourceType");local id=m:GetAttribute("RSManagedId");local tile=m:GetAttribute("RSResourceChunk")
 assert(groups[k] and id==m.Name and not seen[id] and typeof(tile)=="string","Baseline identity")
 seen[id]=true;originalCounts[k]+=1
 local p=part(m);if not legacyIds[k] then legacyIds[k]=p.MeshId end;assert(legacyIds[k]==p.MeshId,"Baseline mesh variants")
 if not groups[k][tile] then groups[k][tile]={} end
 table.insert(groups[k][tile],m)
end
assert(originalCounts.Stone==1000 and originalCounts.Stick==1000,"Original population")
if cfg.mode=="apply" then assert(canon(legacyIds)==canon(cfg.legacyMeshIds),"Legacy mesh drift") end
local function support(frame,size,legacy)
 local axes={frame.RightVector,frame.UpVector,frame.ZVector};local dims={size.X,size.Y,size.Z}
 local upIdx=2
 if legacy then
  for i=1,3 do if math.abs(axes[i].Y)>math.abs(axes[upIdx].Y) then upIdx=i end end
 end
 local h={};for i=1,3 do if i~=upIdx then table.insert(h,i) end end
 local sign=if axes[upIdx].Y>=0 then 1 else -1
 local low,high=math.huge,-math.huge
 for _,a in {{0,0},{-.42,0},{.42,0},{0,-.42},{0,.42},{-.42,-.42},{.42,-.42},{-.42,.42},{.42,.42}} do
  local p=frame.Position-axes[upIdx]*dims[upIdx]*sign/2+axes[h[1]]*dims[h[1]]*a[1]+axes[h[2]]*dims[h[2]]*a[2]
  local hit=ground(p.X,p.Z);if not hit then return nil,nil end
  local gap=p.Y-hit.Position.Y;low=math.min(low,gap);high=math.max(high,gap)
 end
 return .01-low,high-low+.01
end
local function pose(m,k,variant)
 local p=part(m);local cf=p.CFrame;local size=p.Size
 local frame=cf;local newSize=size;local heading=cf.RightVector
 local src=nil
 if variant=="v1" then
  src=part(templates[if k=="Stick" then "Branch" else "Stone"])
  local factor=math.max(size.X,size.Z)/math.max(src.Size.X,src.Size.Z)
  if k=="Stick" then
   local length=math.max(size.X,size.Y,size.Z)
   heading=if length==size.Y then cf.UpVector elseif length==size.Z then cf.LookVector else cf.RightVector
   local center=ground(cf.X,cf.Z);if not center then return nil end
   local up=center.Normal.Unit
   local right=(heading-up*heading:Dot(up)).Unit
   frame=CFrame.fromMatrix(cf.Position,right,up,right:Cross(up))
   factor=length/src.Size.X
  end
  newSize=src.Size*factor
 end
 local legacy=variant=="legacy"
 local lift,gap=support(frame,newSize,legacy)
 local multiplier=1
 if not lift then return nil end
 if gap>.22 or math.abs(lift)>2 then
  for _,scale in {.95,.90,.85,.80,.75,.70} do
   local l,g=support(frame,newSize*scale,legacy)
   if l and g<=.22 and math.abs(l)<=2 then lift=l;gap=g;multiplier=scale;break end
  end
 end
 if not legacy and k=="Stick" and (gap>.22 or math.abs(lift)>2) then
  local horizontal=Vector3.new(heading.X,0,heading.Z).Unit;local back=horizontal:Cross(Vector3.yAxis)
  for _,scale in {1,.95,.90,.85,.80,.75,.70} do
   local test=newSize*scale;local a=horizontal*test.X*.42;local b=back*test.Z*.42;local pos=cf.Position
   local l,r=ground(pos.X-a.X,pos.Z-a.Z),ground(pos.X+a.X,pos.Z+a.Z)
   local f,t=ground(pos.X-b.X,pos.Z-b.Z),ground(pos.X+b.X,pos.Z+b.Z)
   if l and r and f and t then
    local right=(horizontal+Vector3.yAxis*((r.Position.Y-l.Position.Y)/(2*a.Magnitude))).Unit
    local transverse=(back+Vector3.yAxis*((t.Position.Y-f.Position.Y)/(2*b.Magnitude))).Unit
    local up=transverse:Cross(right).Unit
    if up.Y>=math.cos(math.rad(35)) and math.abs(right:Dot(heading))>=.95 then
     local candidate=CFrame.fromMatrix(pos,right,up,right:Cross(up))
     local ll,gg=support(candidate,test,false)
     if ll and gg<=.22 and math.abs(ll)<=2 then frame=candidate;lift=ll;gap=gg;multiplier=scale;break end
    end
   end
  end
 end
 if gap>.22 or math.abs(lift)>2 then return nil end
 return {frame=frame+Vector3.yAxis*lift,size=newSize*multiplier,src=src,lift=lift,gap=gap,multiplier=multiplier}
end
local selected={};local maxGap,maxShift=0,0;local adjusted=0;local rejected=0
local selectionReport={}
for _,k in {"Stone","Stick"} do
 local tiles={};for tile in groups[k] do table.insert(tiles,tile) end;table.sort(tiles)
 local quota={};local total=0
 for _,tile in tiles do quota[tile]=math.floor(#groups[k][tile]/2);total+=quota[tile] end
 for _,tile in tiles do if total<500 and #groups[k][tile]%2==1 then quota[tile]+=1;total+=1 end end
 assert(total==500,"Tile quota")
 local n=0
 for _,tile in tiles do
  local list=groups[k][tile];local ordered={}
  for _,m in list do if not blocked[m] then table.insert(ordered,{m=m,key=hash(m.Name..":s081")}) end end
  table.sort(ordered,function(a,b)if a.key~=b.key then return a.key<b.key end;return a.m.Name<b.m.Name end)
  local got=0;local tileCount={legacy=0,v1=0}
  for _,v in ordered do
   if got>=quota[tile] then break end
   local m=v.m;local variant=if n%2==0 then "legacy" else "v1"
   local result=pose(m,k,variant)
   if not result then rejected+=1;continue end
   selected[m]={variant=variant,k=k,pose=result};n+=1;got+=1;tileCount[variant]+=1
   maxGap=math.max(maxGap,result.gap);maxShift=math.max(maxShift,math.abs(result.lift))
   if result.multiplier<1 then adjusted+=1 end
  end
  assert(got==quota[tile],"Insufficient supported sites "..k..":"..tile.." "..got.."/"..quota[tile])
  table.insert(selectionReport,{type=k,tile=tile,before=#list,after=got,legacy=tileCount.legacy,v1=tileCount.v1})
 end
 assert(n==500,"Selection count")
end
local removed=0
for _,m in F:GetChildren() do
 local row=selected[m]
 if not row then m.Parent=nil;removed+=1
 else
  local p=part(m);local a=row.pose
  if a.src then p:ApplyMesh(a.src);p.Color=Color3.new(1,1,1);p.TextureID=a.src.TextureID end
  p.Size=a.size;p.CFrame=a.frame
  p.Anchored=true;p.CanCollide=true;p.CanQuery=true;p.CanTouch=false;p.CollisionGroup="RSNaturalResource"
  m:SetAttribute("RSResourceVariant",row.variant)
  local asset=if row.variant=="v1" then assets[if row.k=="Stick" then "Branch" else "Stone"].assetId else (if row.k=="Stick" then "9204066145" else "80215326989711")
  m:SetAttribute("RSResourceAssetId",asset)
  m:SetAttribute("RSBuriedDepth",0);m:SetAttribute("RSContactMethod","native_terrain_ray")
  local h=ground(p.Position.X,p.Position.Z);assert(h,"Resource ground");m:SetAttribute("RSExpectedGroundY",h.Position.Y)
  m:SetAttribute("RSSupportRadius",math.max(p.Size.X,p.Size.Y,p.Size.Z)*.5)
 end
end
assert(removed==1000,"Thinning count")
local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Include;overlap.FilterDescendantsInstances={F,W.RSVegetationS06.Collisions};overlap.MaxParts=0
for m in selected do
 local p=part(m)
 for _,o in W:GetPartBoundsInBox(p.CFrame,p.Size,overlap) do assert(o==p,"Resource overlap "..m.Name.." "..o.Name) end
end
assert(#W:GetPartBoundsInBox(treeCf,treeSize,rp)==0,"Resource overlaps central tree")
tree.Parent=W
local treeInfo=treeProof(tree)
local c,tiles=population(legacyIds)
local digest=resourceDigest()
local after=terrainState();assert(#before==49 and #after==49,"Terrain coverage")
for i,r in after do assert(r.digest==before[i].digest,"Terrain modified "..r.id) end
assert(fingerprint(false)==fp,"Unrelated scene changed")
local result={counts=c,tiles=tiles,selection=selectionReport,removed=removed,legacyMeshIds=legacyIds,resourcePlanDigest=digest,tree=treeInfo,treeSite=site,maxSupportGap=maxGap,maxVerticalShift=maxShift,scaleAdjusted=adjusted,rejectedCandidates=rejected,terrain=after,nonResourceFingerprint=fp,originalNonResource=originalFp,clientRenderVerified=false,readyForStaging=true}
if cfg.mode=="apply" then
 assert(digest==cfg.expectedDigest and treeInfo.digest==cfg.expectedTreeDigest,"Reviewed plan differs")
 assert(q(site.x)==q(cfg.expectedSite.x) and q(site.z)==q(cfg.expectedSite.z),"Reviewed central site differs")
 A:SavePlaceAsync({SaveWithoutPublish=false})
 result.saved=true
else result.noPlaceWrites=true end
return syncResult(result)
