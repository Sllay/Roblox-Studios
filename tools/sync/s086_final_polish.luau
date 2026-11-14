-- S08.6: translate the original Eggydrasil and darken common canopy tint only.
local W=workspace
local E=W.RSEggydrasilS08
local V=W.RSVegetationS06.Models
local verify=cfg.mode=="verify"
assert(cfg.mode=="preview" or cfg.mode=="apply" or verify,"Mode")
assert(game.PlaceId==93428341652658 and game.GameId==10769712441 and game.PlaceVersion==(if verify then 25 else 24),"Staging version")
assert(E:IsA("Model") and E:GetAttribute("RSManagedId")=="s08:Eggydrasil:central","Landmark identity")
local delta=8
local oldTint=Color3.fromRGB(93,107,28)
local newTint=Color3.fromRGB(76,96,24)
local names={Tree_01="Canopy_01",Tree_03="Canopy_03",Tree_08="Canopy_08",Tree_12="Canopy_12"}
local spawnRoot=W.RSCentralSpawns
local affected=spawnRoot:FindFirstChild("Valley_17");assert(affected and affected:IsA("SpawnLocation") and affected.Enabled and affected.Neutral,"Reviewed spawn")
local counts={tree=0,pine=0,bush=0};local surfaces={};local targets={}
for _,m in V:GetChildren() do
 local s=m:GetAttribute("RSSpecies") or ""
 if names[s] then
  assert(m:GetAttribute("RSAssetId")=="79689531752352","Tree identity")
  local p=m:FindFirstChild(names[s]);assert(p and p:IsA("MeshPart"),"Canopy")
  local a=p:FindFirstChildWhichIsA("SurfaceAppearance");assert(a and a.ColorMapContent.Uri=="rbxassetid://89626593244521" and a.RoughnessMapContent.Uri=="rbxassetid://91633090510389" and a.AlphaMode==Enum.AlphaMode.Transparency,"S085 contract")
  local id=m:GetAttribute("RSManagedId");assert(id==m.Name and not targets[id],"Tree identity")
  assert(m:GetAttribute("RSWindRigVersion")==1 and p:GetAttribute("RSWindRigRole")=="Canopy","Wind")
  targets[id]=a;surfaces[a]=true;counts.tree+=1
 elseif string.sub(s,1,5)=="Pine_" then counts.pine+=1
 elseif string.sub(s,1,5)=="Bush_" then counts.bush+=1 end
end
assert(counts.tree==250 and counts.pine==16 and counts.bush==200,"Population")
assert(#W.RSResourcesP45.Models:GetChildren()==1000 and #W.RSFallenLogsS082:GetChildren()==250,"Resources")
local sp=game:GetService("StarterPlayer")
local roots={};for _,o in sp:GetChildren() do if o.Name=="PlayerModule" and o:IsA("ModuleScript") then table.insert(roots,o) end end
local sounds=sp.StarterPlayerScripts:FindFirstChild("RbxCharacterSounds")
local binding=sounds and sounds:FindFirstChild("AtomicBinding");local leaves={}
if binding then for _,o in binding:GetChildren() do if o.Name=="AtomicBinding" and o:IsA("ModuleScript") then table.insert(leaves,o) end end end
if #roots==19 and #leaves==18 then
 assert(#roots[19]:GetDescendants()==161 and #leaves[18]:GetChildren()==0 and leaves[18].Source==binding.Source,"Controller clone guard")
 roots[19].Parent=nil;leaves[18].Parent=nil
else assert(#roots==18 and #leaves==17,"Controller baseline") end
local function canon(x)
 if typeof(x)~="table" then return Http:JSONEncode(x) end
 local keys={};for k in x do table.insert(keys,k) end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in keys do table.insert(out,Http:JSONEncode(tostring(k))..":"..canon(x[k])) end
 return "{"..table.concat(out,",").."}"
end
local function sameFrame(a,b)
 for i,v in a do if math.abs(v-b[i])>.002 then return false end end;return true
end
local function fingerprint()
 local rows={};local records={};local processed=0
 for _,name in cfg.services do
  local svc=game:GetService(name)
  for _,o in svc:GetDescendants() do
   local r=record(svc,o)
   if o==E then r.properties.pivot=nil end
   if o:IsDescendantOf(E) and o:IsA("BasePart") then r.properties.cframe=nil end
   if surfaces[o] then r.properties.color=nil end
   if o==affected then r.properties.cframe=nil end
   if o:IsA("MeshPart") then r.properties.doubleSided=o.DoubleSided;r.properties.meshSize=vec(o.MeshSize) end
   local digest=hash(canon(r));table.insert(rows,digest);records[o]={digest=digest,row=r};processed+=1;if processed%250==0 then task.wait() end
  end
 end
 table.sort(rows);return hash(table.concat(rows,";")),records
end
local function landmark()
 local pivot=E:GetPivot();local bc,sz=E:GetBoundingBox();assert(math.abs(sz.Y-120)<.02,"Height")
 local r={pivot={pivot:GetComponents()},bounds=vec(sz),bottom=bc.Y-sz.Y/2,scale=E:GetScale(),parts={}}
 local n=0
 for _,p in E:GetDescendants() do
  if p:IsA("BasePart") then
   assert(p:IsA("MeshPart") and not r.parts[p.Name] and p.Anchored,"Landmark mesh")
   r.parts[p.Name]={pose={p.CFrame:GetComponents()},relative={pivot:ToObjectSpace(p.CFrame):GetComponents()},mesh=p.MeshId,size=vec(p.Size),collision=p.CanCollide}
   n+=1
  end
 end
 assert(n==5,"Landmark parts")
 return r
end
local function translated(old,new)
 assert(math.abs(old.scale-new.scale)<.0001 and sameFrame(old.bounds,new.bounds),"Scale/bounds changed")
 local wanted=table.clone(old.pivot);wanted[2]-=delta;assert(sameFrame(new.pivot,wanted),"Pivot translation")
 for name,a in old.parts do
  local b=new.parts[name];local expected=table.clone(a.pose);expected[2]-=delta
  assert(b and a.mesh==b.mesh and a.collision==b.collision and sameFrame(a.size,b.size) and sameFrame(a.relative,b.relative) and sameFrame(expected,b.pose),"Part translation "..name)
 end
end
local function sameLandmark(a,b)
 assert(sameFrame(a.pivot,b.pivot) and sameFrame(a.bounds,b.bounds) and math.abs(a.scale-b.scale)<.0001,"Landmark drift")
 for n,p in a.parts do local q=b.parts[n];assert(q and p.mesh==q.mesh and sameFrame(p.pose,q.pose) and sameFrame(p.size,q.size),"Landmark part drift "..n) end
end
local terrain=terrainState();assert(#terrain==49,"Terrain regions");task.wait()
local fp,originalRecords=fingerprint();task.wait()
local env=hash(canon({lightingState(),workspaceSettings()}))
if cfg.mode~="preview" then
 assert(fp==cfg.expectedFingerprint and env==cfg.expectedEnvironment,"Baseline drift")
 for _,r in terrain do assert(cfg.expectedTerrain[r.id]==r.digest,"Terrain drift") end
end
local before=landmark()
if not verify then
 assert(sameFrame(before.pivot,{16,86.41560363769531,-36,1,0,0,0,1,0,0,0,1}),"Known v24 pose")
 if cfg.mode=="apply" then sameLandmark(before,cfg.expectedBefore) end
 E:PivotTo(E:GetPivot()-Vector3.new(0,delta,0))
end
local after=landmark()
if not verify then translated(before,after) end
if cfg.mode~="preview" then sameLandmark(after,cfg.expectedAfter) end
-- One reviewed spawn is obstructed at all visually useful depths. Relocate only
-- this marker using the same radius, support, spacing and obstruction gates.
local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances={E};ray.RespectCanCollide=true
local oldSpawn={affected.CFrame:GetComponents()}
local function treeClear(p)
 for _,d in {{0,0},{2,0},{-2,0},{0,2},{0,-2}} do
  if W:Raycast(Vector3.new(p.X+d[1],p.Y+8,p.Z+d[2]),Vector3.new(0,-10,0),ray) then return false end
 end
 return true
end
local terrainRay=RaycastParams.new();terrainRay.FilterType=Enum.RaycastFilterType.Include;terrainRay.FilterDescendantsInstances={W.Terrain};terrainRay.IgnoreWater=false;terrainRay.RespectCanCollide=true
local vox=W.Terrain:ReadVoxelChannels(Region3.new(Vector3.new(-116,-32,-116),Vector3.new(116,112,116)),4,{"SolidMaterial","SolidOccupancy","LiquidOccupancy"})
local columns={}
local function column(i,k)
 if i<1 or i>58 or k<1 or k>58 then return nil end
 local key=i..":"..k
 if columns[key]~=nil then return columns[key] or nil end
 local height=nil;local wet=false;local gap=false;local valid=true;local mat=nil
 for j=1,36 do
  local s=vox.SolidOccupancy[i][j][k]
  if vox.LiquidOccupancy[i][j][k]>.02 then wet=true end
  if s>.02 then
   if gap then valid=false end
   height=-32+(j-1+s)*4;mat=vox.SolidMaterial[i][j][k]
  else gap=true end
 end
 if not height or wet or not valid or (mat~=Enum.Material.Grass and mat~=Enum.Material.Ground) then columns[key]=false;return nil end
 columns[key]=height;return height
end
local function ground(x,z)
 local h=W:Raycast(Vector3.new(x,112,z),Vector3.new(0,-144,0),terrainRay)
 if h then
  if (h.Material~=Enum.Material.Grass and h.Material~=Enum.Material.Ground) or h.Normal.Y<.88 then return nil end
  return h.Position.Y,"native_ray"
 end
 local gx,gz=(x+116)/4-.5,(z+116)/4-.5
 local i,k=math.floor(gx),math.floor(gz);local tx,tz=gx-i,gz-k;i+=1;k+=1
 local a,b,c,d=column(i,k),column(i+1,k),column(i,k+1),column(i+1,k+1)
 if not (a and b and c and d) then return nil end
 return (a+(b-a)*tx)*(1-tz)+(c+(d-c)*tx)*tz,"voxel_estimate"
end
local op=OverlapParams.new();op.FilterType=Enum.RaycastFilterType.Exclude;op.FilterDescendantsInstances={W.Terrain,spawnRoot};op.RespectCanCollide=true;op.MaxParts=1
local function safe(x,z)
 if x*x+z*z>108*108 then return nil end
 local h,method=ground(x,z);if not h then return nil end
 for _,d in {{3,0},{-3,0},{0,3},{0,-3},{3,3},{-3,3},{3,-3},{-3,-3}} do
  local y=ground(x+d[1],z+d[2]);if not y or math.abs(y-h)>2.5 then return nil end
 end
 local p=Vector3.new(x,h+2,z)
 for _,s in spawnRoot:GetChildren() do
  if s~=affected and s:IsA("SpawnLocation") and s.Enabled then
   if (Vector2.new(x,z)-Vector2.new(s.Position.X,s.Position.Z)).Magnitude<10 then return nil end
  end
 end
 if #W:GetPartBoundsInBox(CFrame.new(x,h+3.5,z),Vector3.new(4,6,4),op)>0 or not treeClear(p) then return nil end
 return p,method
end
local chosen,method
if not verify then
 assert(sameFrame(oldSpawn,{24,26.375205993652344,-24,1,0,0,0,1,0,0,0,1}),"Spawn baseline")
 assert(not treeClear(affected.Position),"Reviewed obstruction absent")
 local candidates={}
 for x=-104,104,4 do for z=-104,104,4 do
  local dd=(x-24)^2+(z+24)^2
  if dd<=100^2 and x*x+z*z<=108^2 then table.insert(candidates,{x=x,z=z,d=dd}) end
 end end
 table.sort(candidates,function(a,b)if a.d~=b.d then return a.d<b.d end;if a.x~=b.x then return a.x<b.x end;return a.z<b.z end)
 local tested=0
 for _,c in candidates do
  chosen,method=safe(c.x,c.z);if chosen then break end
  tested+=1;if tested%50==0 then task.wait() end
 end
 assert(chosen,"No safe replacement spawn")
 affected.CFrame=CFrame.new(chosen)*affected.CFrame.Rotation
else
 chosen,method=safe(affected.Position.X,affected.Position.Z)
 assert(chosen and (chosen-affected.Position).Magnitude<.02,"Persisted spawn support")
end
local newSpawn={affected.CFrame:GetComponents()}
if cfg.mode~="preview" then
 assert(sameFrame(newSpawn,cfg.expectedSpawn),"Reviewed spawn drift")
end
local spawnChecked=0
for _,s in spawnRoot:GetDescendants() do
 if s:IsA("SpawnLocation") and s.Enabled then
  spawnChecked+=1;assert(treeClear(s.Position),"Spawn blocked "..s.Name)
 end
end
assert(spawnChecked==53,"Spawn coverage")
print("S086_CHECKPOINT_1: landmark translation verified")
local function sameColor(a,b)
 return math.abs(a.R-b.R)<.001 and math.abs(a.G-b.G)<.001 and math.abs(a.B-b.B)<.001
end
local n=0
for id,s in targets do
 if not verify then assert(sameColor(s.Color,oldTint),"Unexpected old tint "..id);s.Color=newTint end
 assert(sameColor(s.Color,newTint),"Tint "..id)
 n+=1;if n%25==0 then task.wait() end
end
assert(n==250,"Tint count")
print("S086_CHECKPOINT_2: 250 common canopies tint verified")
local finalFP,finalRecords=fingerprint()
if finalFP~=fp then
 local differences={}
 for o,a in originalRecords do
  local b=finalRecords[o]
  if not b or a.digest~=b.digest then
   local keys={}
   if b then for k,v in a.row.properties do if canon(v)~=canon(b.row.properties[k]) then table.insert(keys,k) end end end
   table.insert(differences,{path=o:GetFullName(),class=o.ClassName,properties=keys,before=a.row,after=b and b.row or nil})
   if #differences>=4 then break end
  end
 end
 assert(false,"Unrelated scene changed "..Http:JSONEncode(differences):sub(1,4500))
end
task.wait()
assert(hash(canon({lightingState(),workspaceSettings()}))==env,"Environment changed")
local endTerrain=terrainState();for i,r in endTerrain do assert(r.digest==terrain[i].digest,"Terrain changed") end;task.wait()
local result={counts=counts,delta=delta,oldTint={93,107,28},newTint={76,96,24},tinted=n,before=before,after=after,terrain=endTerrain,fingerprint=fp,environment=env,spawnChecked=spawnChecked,spawn={name=affected.Name,before=oldSpawn,after=newSpawn,method=method},geometryUnchanged=true,clientRenderVerified=false}
if cfg.mode=="apply" then
 assert(cfg.confirmStaging and game.PlaceVersion==24,"Save guard")
 game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false});result.saved=true
elseif verify then result.verified=true;result.noPlaceWrites=true
else result.noPlaceWrites=true;result.readyForStaging=true end
return syncResult(result)
