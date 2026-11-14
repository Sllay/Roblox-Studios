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
 local rows={};local processed=0
 for _,name in cfg.services do
  local svc=game:GetService(name)
  for _,o in svc:GetDescendants() do
   local r=record(svc,o)
   if o==E then r.properties.pivot=nil end
   if o:IsDescendantOf(E) and o:IsA("BasePart") then r.properties.cframe=nil end
   if surfaces[o] then r.properties.color=nil end
   if o:IsA("MeshPart") then r.properties.doubleSided=o.DoubleSided;r.properties.meshSize=vec(o.MeshSize) end
   table.insert(rows,hash(canon(r)));processed+=1;if processed%250==0 then task.wait() end
  end
 end
 table.sort(rows);return hash(table.concat(rows,";"))
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
local fp=fingerprint();task.wait()
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
-- Check enabled spawn headroom against the translated landmark's actual collision.
local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances={E};ray.RespectCanCollide=true
local spawnChecked=0
for _,s in W.RSCentralSpawns:GetDescendants() do
 if s:IsA("SpawnLocation") and s.Enabled then
  spawnChecked+=1;local p=s.Position
  for _,d in {{0,0},{2,0},{-2,0},{0,2},{0,-2}} do
   assert(not W:Raycast(Vector3.new(p.X+d[1],p.Y+8,p.Z+d[2]),Vector3.new(0,-10,0),ray),"Spawn blocked "..s.Name)
  end
 end
end
assert(spawnChecked>0,"Spawn coverage")
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
assert(fingerprint()==fp,"Unrelated scene changed");task.wait()
assert(hash(canon({lightingState(),workspaceSettings()}))==env,"Environment changed")
local endTerrain=terrainState();for i,r in endTerrain do assert(r.digest==terrain[i].digest,"Terrain changed") end;task.wait()
local result={counts=counts,delta=delta,oldTint={93,107,28},newTint={76,96,24},tinted=n,before=before,after=after,terrain=endTerrain,fingerprint=fp,environment=env,spawnChecked=spawnChecked,geometryUnchanged=true,clientRenderVerified=false}
if cfg.mode=="apply" then
 assert(cfg.confirmStaging and game.PlaceVersion==24,"Save guard")
 game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false});result.saved=true
elseif verify then result.verified=true;result.noPlaceWrites=true
else result.noPlaceWrites=true;result.readyForStaging=true end
return syncResult(result)
