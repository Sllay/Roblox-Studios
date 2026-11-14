-- S08.2 reviewed, staging-only exact transaction. No new full tree asset.
local W=workspace
local T=W.Terrain
local F=W.RSResourcesP45.Models
local A=game:GetService("AssetService")
local CP=game:GetService("ContentProvider")
local tree=W:FindFirstChild("RSEggydrasilS08")
local reviewed=cfg.reviewed
local woodProof=cfg.wood
local isVerify=cfg.mode=="verify"
assert(game.GameId==10769712441 and game.PlaceId==93428341652658 and game.PlaceVersion==(if isVerify then 21 else 20),"Target/version")
assert(tree and tree:GetAttribute("RSManagedId")=="s08:Eggydrasil:central" and #F:GetChildren()==1000,"Baseline")
assert(cfg.mode=="preview" or cfg.mode=="apply" or isVerify,"Mode")
local root=W:FindFirstChild("RSFallenLogsS082")
assert((root~=nil)==isVerify,"Log root state")
local function q(n)return math.round(n*10000)/10000 end
local function v(p)return {q(p.X),q(p.Y),q(p.Z)} end
local function frame(cf)local a={cf:GetComponents()};for i,n in a do a[i]=q(n) end;return a end
local function cf(a)return CFrame.new(table.unpack(a)) end
local function vec3(a)return Vector3.new(table.unpack(a)) end
local function sameCF(a,b)
 local aa,bb={a:GetComponents()},{b:GetComponents()}
 for i,n in aa do if math.abs(n-bb[i])>.002 then return false end end
 return true
end
local function canon(x)
 if typeof(x)~="table" then return Http:JSONEncode(x) end
 local keys={};for k in x do table.insert(keys,k) end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in keys do table.insert(out,Http:JSONEncode(tostring(k))..":"..canon(x[k])) end
 return "{"..table.concat(out,",").."}"
end
local function fingerprint(skipResources)
 local rows={}
 for _,name in cfg.services do
  local svc=game:GetService(name)
  for _,o in svc:GetDescendants() do
   if o~=tree and not o:IsDescendantOf(tree) and o~=root and not (root and o:IsDescendantOf(root)) and (not skipResources or (o~=F and not o:IsDescendantOf(F))) then
    table.insert(rows,hash(canon(record(svc,o))))
   end
  end
 end
 table.sort(rows);return hash(table.concat(rows,";"))
end
local terrainBefore=terrainState()
local expectedTerrain={};for _,r in reviewed.terrain do expectedTerrain[r.id]=r.digest end
assert(#terrainBefore==49 and #reviewed.terrain==49,"Terrain coverage")
for _,r in terrainBefore do assert(r.digest==expectedTerrain[r.id],"Terrain drift "..r.id) end
local function census()
 local c={trees=0,pines=0,bushes=0,largeRocks=0,stone=0,stick=0,eggydrasil=0,logs=0}
 local ids={}
 for _,m in W:GetDescendants() do
  if m:IsA("Model") then
   local s=m:GetAttribute("RSSpecies") or ""
   local k=nil
   if string.sub(s,1,5)=="Pine_" then k="pines"
   elseif string.sub(s,1,5)=="Tree_" then k="trees"
   elseif string.sub(s,1,5)=="Bush_" then k="bushes"
   elseif s=="Mossy_Rock1_M_Mossy_Rock_0_Node" then k="largeRocks"
   elseif s=="Eggydrasil" then k="eggydrasil"
   elseif m.Parent==F then
    local type=m:GetAttribute("RSResourceType");assert(type=="Stone" or type=="Stick")
    k=if type=="Stone" then "stone" else "stick"
   elseif root and m.Parent==root then k="logs" end
   if k then
    local id=m:GetAttribute("RSManagedId") or m:GetFullName()
    assert(not ids[id],"Duplicate managed model "..id);ids[id]=true;c[k]+=1
   end
  end
 end
 return c
end
local function woodParts(m)
 local out={};local count=0
 for _,p in m:GetDescendants() do
  assert(not p:IsA("LuaSourceContainer"),"Unexpected tree script")
  if p:IsA("MeshPart") and string.sub(p.Name,1,7)=="Wood_V4" then assert(not out[p.Name]);out[p.Name]=p;count+=1 end
 end
 assert(count==3,"Three wood groups")
 return out
end
local function treeCheck()
 local parts=woodParts(tree);local total=0;local rows={}
 for _,p in tree:GetDescendants() do
  if p:IsA("MeshPart") then
   total+=1;assert(p.Anchored)
   if parts[p.Name] then
    local sa=p:FindFirstChildWhichIsA("SurfaceAppearance")
    assert(p.MeshId==woodProof.parts[p.Name].meshId and p.CanCollide and p.CanQuery and p.CollisionFidelity==Enum.CollisionFidelity.Default,"Wood geometry/collision "..p.Name)
    assert(sa and sa.ColorMapContent.Uri==woodProof.barkUri and sa.AlphaMode==Enum.AlphaMode.TintMask and p.TextureID=="","Wood tint mask "..p.Name)
    rows[p.Name]={meshId=p.MeshId,color=rgb(sa.Color),texture=sa.ColorMapContent.Uri,size=v(p.Size),pose=frame(p.CFrame)}
   else
    assert(p.Name=="Canopy_White" or p.Name=="Canopy_Gray","Unexpected mesh")
    local sa=p:FindFirstChildWhichIsA("SurfaceAppearance")
    local uri=if p.Name=="Canopy_White" then "rbxassetid://89626593244521" else "rbxassetid://109528136250293"
    local color=if p.Name=="Canopy_White" then Color3.fromRGB(255,80,140) else Color3.fromRGB(120,40,200)
    assert(sa and sa.ColorMapContent.Uri==uri and sa.AlphaMode==Enum.AlphaMode.Transparency and (Vector3.new(sa.Color.R,sa.Color.G,sa.Color.B)-Vector3.new(color.R,color.G,color.B)).Magnitude<.007 and not p.CanCollide and not p.CanQuery and p.DoubleSided,"Foliage unchanged")
   end
  end
 end
 assert(total==5,"Tree must still use five MeshParts")
 local bc,sz=tree:GetBoundingBox()
 assert(math.abs(sz.Y-120)<.02 and sameCF(tree:GetPivot(),cf(reviewed.tree.pivot)),"Tree pose")
 assert(math.abs(bc.Y-sz.Y/2-reviewed.tree.groundY+reviewed.tree.burial)<.02,"Root burial")
 return {height=sz.Y,center=v(bc.Position),pivot=frame(tree:GetPivot()),burial=reviewed.tree.burial,wood=rows,meshCount=total}
end
local function logPart(m)
 local p=nil;local n=0
 for _,o in m:GetDescendants() do
  assert(not o:IsA("LuaSourceContainer"))
  if o:IsA("BasePart") then n+=1;p=o end
 end
 assert(n==1 and p:IsA("MeshPart"),"Log single mesh")
 return p
end
local function logsCheck()
 assert(root and #root:GetChildren()==250)
 local ids={};local tiles={}
 for _,r in reviewed.logs.rows do
  assert(not ids[r.id]);ids[r.id]=true
  local m=root:FindFirstChild(r.id);assert(m and m:IsA("Model") and m:GetAttribute("RSManagedId")==r.id and m:GetAttribute("RSResourceType")=="Log" and m:GetAttribute("RSResourceChunk")==r.tile,"Log identity")
  local p=logPart(m)
  assert(p.MeshId==reviewed.logs.meshId and p.TextureID==reviewed.logs.textureId and p.Anchored and p.CanCollide and p.CanQuery and not p.CanTouch and p.CollisionGroup=="Default","Log geometry/policy")
  assert((p.Size-vec3(r.size)).Magnitude<.002 and sameCF(p.CFrame,cf(r.pose)),"Log transform "..r.id)
  assert(m.PrimaryPart==p and m:GetAttribute("RSBuriedDepth")==0,"Log pivot/burial")
  tiles[r.tile]=(tiles[r.tile] or 0)+1
 end
 return tiles
end
if isVerify then
 local t=treeCheck();local l=logsCheck();local c=census()
 local fp=fingerprint(false);assert(fp==cfg.expectedNonResource or fp==reviewed.nonResourceFingerprint,"Unrelated persisted changes")
 assert(c.stone==500 and c.stick==500 and c.logs==250 and c.eggydrasil==1,"Persisted counts")
 return syncResult({verified=true,noPlaceWrites=true,tree=t,logTiles=l,counts=c,terrain=terrainBefore,nonResourceFingerprint=fp,clientRenderVerified=false})
end
assert(reviewed.readyForStaging and reviewed.noPlaceWrites and reviewed.loadedVersion==20 and #reviewed.logs.rows==250 and #reviewed.tree.spawnBlocked==0,"Reviewed placement")
assert(fingerprint(false)==reviewed.nonResourceFingerprint,"Unrelated baseline drift")
-- Remove only the exact previously reviewed automatic controller clone pair.
-- Compare the prior S08.1 scope hash before and after; never delete arbitrary scripts.
assert(fingerprint(true)=="i7acG9clNtCQYEeA9CiLcbU1IlroF6FkTMoBAk6UW94=","S081 baseline scope")
local sp=game:GetService("StarterPlayer")
local roots={};for _,o in sp:GetChildren() do if o.Name=="PlayerModule" and o:IsA("ModuleScript") then table.insert(roots,o) end end
local sounds=sp.StarterPlayerScripts:FindFirstChild("RbxCharacterSounds")
local binding=sounds and sounds:FindFirstChild("AtomicBinding");assert(binding and binding:IsA("ModuleScript"))
local leaves={};for _,o in binding:GetChildren() do if o.Name=="AtomicBinding" and o:IsA("ModuleScript") then table.insert(leaves,o) end end
assert(#roots==19 and #leaves==18 and #roots[19]:GetDescendants()==161 and #leaves[18]:GetChildren()==0 and leaves[18].Source==binding.Source,"Controller clone guard")
roots[19].Parent=nil;leaves[18].Parent=nil
assert(fingerprint(true)=="nAaOGmC2n/YhKmrjelAHkrEcvTnmImLX+e5Cn3Kqces=","Controller correction exact")
local fp=fingerprint(false)
if cfg.mode=="apply" then assert(cfg.confirmStaging and fp==cfg.expectedNonResource,"Reviewed apply baseline") end
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
local oldParts=woodParts(tree)
local oldGeometry={}
for name,p in oldParts do
 assert(p.MeshId==woodProof.parts[name].oldMeshId and p.CanCollide and p.CanQuery,"Old wood identity")
 oldGeometry[name]={size=p.Size,relative=oldPivot:ToObjectSpace(p.CFrame)}
end
tree:ScaleTo(reviewed.tree.scale)
tree:PivotTo(cf(reviewed.tree.pivot))
local tcf,ts=tree:GetBoundingBox()
assert(math.abs(ts.Y-120)<.02 and math.abs(tree:GetScale()-oldScale*2)<.001,"Scale")
local h=ground(tcf.X,tcf.Z);assert(h and math.abs(h.Position.Y-reviewed.tree.groundY)<.01,"Ground")
local rayTree=RaycastParams.new();rayTree.FilterType=Enum.RaycastFilterType.Include;rayTree.FilterDescendantsInstances={tree};rayTree.RespectCanCollide=true
local rays={}
local c=tcf.Position;local ext=ts/2+Vector3.new(3,3,3)
for i=0,15 do for j=0,15 do
 local u=-.95+1.9*i/15;local w=-.95+1.9*j/15
 table.insert(rays,{o=c+Vector3.new(-ext.X,u*ext.Y,w*ext.Z),d=Vector3.new(ext.X*2,0,0)})
 table.insert(rays,{o=c+Vector3.new(u*ext.X,-ext.Y,w*ext.Z),d=Vector3.new(0,ext.Y*2,0)})
 table.insert(rays,{o=c+Vector3.new(u*ext.X,w*ext.Y,-ext.Z),d=Vector3.new(0,0,ext.Z*2)})
end end
local hits={};local hitCount=0
for i,r in rays do local h=W:Raycast(r.o,r.d,rayTree);hits[i]=if h then h.Distance else -1;if h then hitCount+=1 end end
assert(hitCount>50,"Collision probe insufficient")
local model=A:LoadAssetAsync(tonumber(woodProof.assetId));assert(model.Parent==nil and model:IsA("Model"))
local new=woodParts(model)
for name,p in oldParts do
 local src=new[name];local a=oldGeometry[name];local size=p.Size;local pose=p.CFrame
 assert(src and src.MeshId==woodProof.parts[name].meshId and (src.MeshSize-p.MeshSize).Magnitude<.02 and src.CollisionFidelity==p.CollisionFidelity,"Replacement parity")
 assert((size-a.size*2).Magnitude<.02 and (tree:GetPivot():ToObjectSpace(pose).Position-a.relative.Position*2).Magnitude<.02,"Original proportions")
 local sa=src:FindFirstChildWhichIsA("SurfaceAppearance");assert(sa and sa.AlphaMode==Enum.AlphaMode.TintMask and sa.ColorMapContent.Uri==woodProof.barkUri)
 p:ApplyMesh(src);p.Size=size;p.CFrame=pose;p.TextureID="";p.Color=Color3.new(1,1,1)
 local bark=sa:Clone();bark.Parent=p
 assert(p.CanCollide and p.CanQuery and p.CollisionFidelity==Enum.CollisionFidelity.Default,"Physical policy")
end
model:Destroy()
local maxCollisionDelta=0
for i,r in rays do
 local h=W:Raycast(r.o,r.d,rayTree)
 assert((h~=nil)==(hits[i]>=0),"Collision hit changed "..i)
 if h then maxCollisionDelta=math.max(maxCollisionDelta,math.abs(h.Distance-hits[i])) end
end
assert(maxCollisionDelta<.06,"Collision geometry changed "..maxCollisionDelta)
local loaded=false;CP:PreloadAsync({woodProof.barkUri},function(_,s)if s==Enum.AssetFetchStatus.Success then loaded=true end end);assert(loaded,"Bark preload")
local spawnChecked=0
for _,s in W:GetDescendants() do
 if s:IsA("SpawnLocation") and s.Enabled then
  local p=s.Position
  if math.abs(p.X-c.X)<ts.X/2+8 and math.abs(p.Z-c.Z)<ts.Z/2+8 then
   spawnChecked+=1
   for _,d in {{0,0},{2,0},{-2,0},{0,2},{0,-2}} do assert(not W:Raycast(Vector3.new(p.X+d[1],p.Y+8,p.Z+d[2]),Vector3.new(0,-10,0),rayTree),"Spawn blocked "..s.Name) end
  end
 end
end
local template=A:LoadAssetAsync(72836155682285);local p=logPart(template);assert(p.MeshId==reviewed.logs.meshId)
p.TextureID=reviewed.logs.textureId;p.Color=Color3.new(1,1,1)
local ok=false;CP:PreloadAsync({p.TextureID},function(_,s)if s==Enum.AssetFetchStatus.Success then ok=true end end);assert(ok,"Log texture preload")
root=Instance.new("Folder");root.Name="RSFallenLogsS082";root:SetAttribute("RSOwner","RSFallenLogsS082V1");root.Parent=W
local op=OverlapParams.new();op.FilterType=Enum.RaycastFilterType.Include;op.FilterDescendantsInstances={F,W.RSVegetationS06.Collisions,W.RSEnvironmentP4Detail.Models,root,tree,W.RSCentralSpawns};op.MaxParts=1
local maxGap=0
for _,r in reviewed.logs.rows do
 local f=cf(r.pose);local sz=vec3(r.size)
 local low,high=math.huge,-math.huge
 for _,o in {{0,0},{-.42,0},{.42,0},{0,-.42},{0,.42},{-.42,-.42},{-.42,.42},{.42,-.42},{.42,.42}} do
  local pt=f:PointToWorldSpace(Vector3.new(o[1]*sz.X,-sz.Y/2,o[2]*sz.Z))
  local hit=ground(pt.X,pt.Z);assert(hit,"Log ground "..r.id)
  local gap=pt.Y-hit.Position.Y;low=math.min(low,gap);high=math.max(high,gap)
 end
 assert(low>=.005 and high<=.22,"Log contact "..r.id)
 assert(#W:GetPartBoundsInBox(f,sz+Vector3.new(.5,.1,.5),op)==0,"Log overlap "..r.id)
 maxGap=math.max(maxGap,high)
 local m=template:Clone();m.Name=r.id;m:SetAttribute("RSManagedId",r.id);m:SetAttribute("RSResourceType","Log");m:SetAttribute("RSResourceVariant","v1");m:SetAttribute("RSResourceAssetId","72836155682285");m:SetAttribute("RSResourceState","decorative");m:SetAttribute("RSResourceChunk",r.tile);m:SetAttribute("RSBuriedDepth",0);m:SetAttribute("RSContactMethod","native_terrain_ray")
 local mesh=logPart(m);mesh.Size=sz;mesh.CFrame=f;m.PrimaryPart=mesh;mesh.Anchored=true;mesh.CanCollide=true;mesh.CanQuery=true;mesh.CanTouch=false;mesh.CollisionGroup="Default"
 local center=ground(f.X,f.Z);m:SetAttribute("RSExpectedGroundY",center.Position.Y);m:SetAttribute("RSSupportRadius",math.max(sz.X,sz.Z)/2)
 m.Parent=root
end
template:Destroy()
local t=treeCheck();local l=logsCheck();local c=census()
assert(c.stone==500 and c.stick==500 and c.logs==250 and c.eggydrasil==1,"Population")
local after=terrainState();assert(#after==49)
for _,r in after do assert(r.digest==expectedTerrain[r.id],"Terrain changed "..r.id) end
assert(fingerprint(false)==fp,"Unrelated scene changed")
local result={tree=t,logTiles=l,counts=c,terrain=after,nonResourceFingerprint=fp,collisionRays=#rays,collisionHits=hitCount,maxCollisionDelta=maxCollisionDelta,spawnChecked=spawnChecked,maxLogSupportGap=maxGap,readyForStaging=true,clientRenderVerified=false}
if cfg.mode=="apply" then
 assert(game.PlaceVersion==20 and cfg.confirmStaging,"Staging guard")
 A:SavePlaceAsync({SaveWithoutPublish=false});result.saved=true
else result.noPlaceWrites=true end
return syncResult(result)
