-- S08.4: existing mesh/UV only; guarded staging material migration.
local W=workspace
local V=W.RSVegetationS06.Models
local E=W.RSEggydrasilS08
local A=game:GetService("AssetService")
local CP=game:GetService("ContentProvider")
local verify=cfg.mode=="verify"
assert(cfg.mode=="preview" or cfg.mode=="apply" or verify,"Mode")
assert(game.PlaceId==93428341652658 and game.GameId==10769712441 and game.PlaceVersion==(if verify then 23 else 22),"Staging version")
local names={Tree_01="Canopy_01",Tree_03="Canopy_03",Tree_08="Canopy_08",Tree_12="Canopy_12"}
local uri="rbxassetid://89626593244521"
local ref=E:FindFirstChild("Canopy_White",true)
assert(ref and ref:IsA("MeshPart"),"Eggy reference")
local function surface(p)
 local s=p:FindFirstChildWhichIsA("SurfaceAppearance")
 assert(s,"Missing surface "..p.Name)
 local n=0;for _,o in p:GetChildren() do if o:IsA("SurfaceAppearance") then n+=1 end end
 assert(n==1,"Single existing surface")
 return s
end
local function noMaps(s)
 for _,k in {"NormalMapContent","RoughnessMapContent","MetalnessMapContent","EmissiveMaskContent"} do
  assert(s[k].SourceType.Name=="None" or s[k].Uri==nil or s[k].Uri=="","Unexpected map "..k)
 end
end
local template=surface(ref)
assert(template.ColorMapContent.Uri==uri and template.AlphaMode==Enum.AlphaMode.Transparency,"Eggy surface")
noMaps(template)
local material=if ref.Material==Enum.Material.SmoothPlastic then Enum.Material.SmoothPlastic else Enum.Material.Plastic
local loaded=false;CP:PreloadAsync({uri},function(_,s)if s==Enum.AssetFetchStatus.Success then loaded=true end end)
assert(loaded,"Eggy texture preload")
local counts={tree=0,pine=0,bush=0};local targets={};local parts={};local models={};local species={}
for _,m in V:GetChildren() do
 local s=m:GetAttribute("RSSpecies") or ""
 if string.sub(s,1,5)=="Tree_" then
  assert(names[s] and m:IsA("Model") and m:GetAttribute("RSAssetId")=="79689531752352","Unknown tree "..s)
  local p=m:FindFirstChild(names[s])
  assert(p and p:IsA("MeshPart") and p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,"Canopy policy")
  local sa=surface(p)
  assert(m:GetAttribute("RSWindRigVersion")==nil or m:GetAttribute("RSWindRigVersion")==1,"Wind version")
  local id=m:GetAttribute("RSManagedId");assert(id==m.Name and not targets[id],"Identity")
  targets[id]={m=m,p=p,sa=sa,species=s};parts[p]=true;models[m]=true
  counts.tree+=1;species[s]=(species[s] or 0)+1
 elseif string.sub(s,1,5)=="Pine_" then counts.pine+=1
 elseif string.sub(s,1,5)=="Bush_" then counts.bush+=1 end
end
assert(counts.tree==250 and counts.pine==16 and counts.bush==200,"Population")
assert(#W.RSResourcesP45.Models:GetChildren()==1000 and #W.RSFallenLogsS082:GetChildren()==250,"Resources")
-- Known save pipeline duplicates: normalize only the exact reviewed pair, in memory.
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
local function attrs(o,skip)
 local a={};for k,v in o:GetAttributes() do if k~=skip then table.insert(a,{k,typeof(v),tostring(v)}) end end
 table.sort(a,function(x,y)return x[1]<y[1] end);return hash(Http:JSONEncode(a))
end
local function fingerprint()
 local rows={}
 for _,name in cfg.services do
  local svc=game:GetService(name)
  for _,o in svc:GetDescendants() do
   if o:IsA("SurfaceAppearance") and parts[o.Parent] then continue end
   local r=record(svc,o)
   if parts[o] then
    for _,k in {"material","materialVariant","reflectance","color","textureId"} do r.properties[k]=nil end
    r.attributesHash=attrs(o,"RSWindRigRole")
    r.properties.doubleSided=o.DoubleSided;r.properties.meshSize=vec(o.MeshSize)
   elseif models[o] then r.attributesHash=attrs(o,"RSWindRigVersion") end
   table.insert(rows,hash(canon(r)))
  end
 end
 table.sort(rows)
 return hash(table.concat(rows,";"))
end
local before=terrainState();assert(#before==49,"Terrain coverage")
local fp=fingerprint()
local env=hash(canon({lightingState(),workspaceSettings()}))
if cfg.mode~="preview" then
 assert(fp==cfg.expectedFingerprint and env==cfg.expectedEnvironment,"Scene baseline drift")
 for _,r in before do assert(cfg.expectedTerrain[r.id]==r.digest,"Terrain drift") end
end
local function row(r)
 local p=r.p;local s=surface(p)
 return {mesh=p.MeshId,material=p.Material.Name,materialVariant=p.MaterialVariant,texture=p.TextureID,reflectance=p.Reflectance,tint=rgb(s.Color),colorMap=s.ColorMapContent.Uri,alpha=s.AlphaMode.Name,windRole=p:GetAttribute("RSWindRigRole") or "",windVersion=r.m:GetAttribute("RSWindRigVersion") or 0,doubleSided=p.DoubleSided,castShadow=p.CastShadow}
end
local baseline={};local resultRows={};local samples={}
for id,r in targets do
 if not verify then
  baseline[id]=row(r)
  if cfg.mode=="apply" then assert(hash(canon(baseline[id]))==cfg.expectedBefore[id],"Canopy baseline "..id) end
  local old=r.sa;local tint=old.Color;local name=old.Name
  local s=template:Clone();s.Name=name;s.Color=tint
  old:Destroy();s.Parent=r.p
  local p=r.p
  p.TextureID="";p.Material=material;p.MaterialVariant="";p.Reflectance=0;p.Color=Color3.new(1,1,1)
  -- Existing wind recognizer accepts this explicit role; preserve all geometry and bones.
  r.m:SetAttribute("RSWindRigVersion",1);p:SetAttribute("RSWindRigRole","Canopy")
 end
 local p=r.p;local s=surface(p)
 assert(s.ColorMapContent.Uri==uri and s.AlphaMode==Enum.AlphaMode.Transparency and p.Material==material and p.MaterialVariant=="" and p.TextureID=="" and p.Reflectance==0,"Material result "..id)
 noMaps(s)
 assert(r.m:GetAttribute("RSWindRigVersion")==1 and p:GetAttribute("RSWindRigRole")=="Canopy","Wind role")
 local actual=row(r)
 if not samples[r.species] then samples[r.species]=actual end
 resultRows[id]=hash(canon(actual))
 if cfg.mode~="preview" then assert(resultRows[id]==cfg.expectedAfter[id],"Reviewed appearance "..id) end
 if not verify then baseline[id]=hash(canon(baseline[id])) end
end
assert(fingerprint()==fp,"Unrelated geometry or scene changed")
assert(hash(canon({lightingState(),workspaceSettings()}))==env,"Lighting or environment changed")
local after=terrainState();for i,r in after do assert(r.digest==before[i].digest,"Terrain changed") end
local result={counts=counts,species=species,changed=250,texture=uri,material=material.Name,meshPartsAdded=0,geometryUnchanged=true,fingerprint=fp,environment=env,terrain=after,before=baseline,after=resultRows,samples=samples,clientRenderVerified=false,uvVisualVerified=false}
if cfg.mode=="apply" then
 assert(cfg.confirmStaging and game.PlaceVersion==22,"Publish guard")
 A:SavePlaceAsync({SaveWithoutPublish=false});result.saved=true
elseif verify then result.verified=true;result.noPlaceWrites=true
else result.noPlaceWrites=true;result.readyForStaging=true end
return syncResult(result)
