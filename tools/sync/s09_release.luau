-- S09.5: install only reviewed creature modules, two client scripts, and inert template.
local verify=cfg.mode=="verify"
assert(cfg.mode=="preview" or cfg.mode=="apply" or verify)
assert(game.GameId==10769712441 and game.PlaceId==93428341652658 and game.PlaceVersion==(if verify then 26 else 25),"Target/version")
local S=game:GetService("ServerScriptService")
local SS=game:GetService("ServerStorage")
local SP=game:GetService("StarterPlayer")
local client=SP.StarterPlayerScripts
local function canon(x)
 if typeof(x)~="table" then return Http:JSONEncode(x) end
 local keys={};for k in x do table.insert(keys,k) end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in keys do table.insert(out,Http:JSONEncode(tostring(k))..":"..canon(x[k])) end
 return "{"..table.concat(out,",").."}"
end
-- Prior V25 publish observed an exact automatic default clone pair. Remove
-- ONLY that known extra pair in the detached session, after content equivalence.
local roots={};for _,o in SP:GetChildren() do if o.Name=="PlayerModule" and o:IsA("ModuleScript") then table.insert(roots,o) end end
local sounds=SP.StarterPlayerScripts:FindFirstChild("RbxCharacterSounds")
local binding=sounds and sounds:FindFirstChild("AtomicBinding")
local leaves={};if binding then for _,o in binding:GetChildren() do if o.Name=="AtomicBinding" and o:IsA("ModuleScript") then table.insert(leaves,o) end end end
local function rootHash(o)
 local rows={};local all=o:GetDescendants();table.insert(all,o)
 for _,x in all do local r=record(SP,x);r.path[1].ordinal=1;table.insert(rows,hash(canon(r))) end
 table.sort(rows);return hash(table.concat(rows,";"))
end
if #roots==19 and #leaves==18 then
 assert(#roots[19]:GetDescendants()==161 and rootHash(roots[19])==rootHash(roots[18]),"Default controller clone not identical")
 local a,b=record(SP,leaves[18]),record(SP,leaves[17]);a.path[#a.path].ordinal=1;b.path[#b.path].ordinal=1
 assert(#leaves[18]:GetChildren()==0 and leaves[18].Source==binding.Source and canon(a)==canon(b),"Default binding clone not identical")
 roots[19].Parent=nil;leaves[18].Parent=nil
elseif #roots~=18 or #leaves~=17 then error("Default controller baseline drift") end
local names={CreatureFramework=true,CreatureBootstrap=true,BookView=true,RSBook=true,RSCreatureAssets=true}
local function existing()
 return {S:FindFirstChild("CreatureFramework"),S:FindFirstChild("CreatureBootstrap"),client:FindFirstChild("BookView"),client:FindFirstChild("RSBook"),SS:FindFirstChild("RSCreatureAssets")}
end
local function absent()
 assert(not S:FindFirstChild("CreatureFramework") and not S:FindFirstChild("CreatureBootstrap") and not client:FindFirstChild("BookView") and not client:FindFirstChild("RSBook") and not SS:FindFirstChild("RSCreatureAssets"),"Creature namespace collision")
 assert(not workspace:FindFirstChild("RSCreatures") and not game:GetService("ReplicatedStorage"):FindFirstChild("RSBookTransport"),"Runtime state already persisted")
end
local function fingerprint()
 local rows={};local n=0
 for _,svcName in cfg.services do
  local svc=game:GetService(svcName)
  for _,o in svc:GetDescendants() do
   local r=record(svc,o);local p=r.path;local skip=false
   if svcName=="ServerScriptService" and (p[1].name=="CreatureFramework" or p[1].name=="CreatureBootstrap") then skip=true end
   if svcName=="ServerStorage" and p[1].name=="RSCreatureAssets" then skip=true end
   if svcName=="StarterPlayer" and p[1].name=="StarterPlayerScripts" then
    if #p>=2 and (p[2].name=="BookView" or p[2].name=="RSBook") then skip=true
    elseif #p==1 then
     if client:FindFirstChild("BookView") then r.childCount-=1 end
     if client:FindFirstChild("RSBook") then r.childCount-=1 end
    end
   end
   if not skip then table.insert(rows,hash(canon(r))) end
   n+=1;if n%250==0 then task.wait() end
  end
 end
 table.sort(rows);return hash(table.concat(rows,";"))
end
local function environment()
 return hash(canon({lightingState(),workspaceSettings()}))
end
local beforeTerrain=terrainState();assert(#beforeTerrain==49)
for _,r in beforeTerrain do assert(cfg.expectedTerrain[r.id]==r.digest,"Terrain baseline "..r.id) end
local beforeFP=fingerprint();local env=environment()
if cfg.mode~="preview" then assert(beforeFP==cfg.expectedFingerprint and env==cfg.expectedEnvironment,"Unrelated baseline drift") end
local function census()
 local c={tree=0,pine=0,bush=0}
 for _,m in workspace.RSVegetationS06.Models:GetChildren() do
  local sp=m:GetAttribute("RSSpecies") or ""
  if string.sub(sp,1,5)=="Tree_" then c.tree+=1 elseif string.sub(sp,1,5)=="Pine_" then c.pine+=1 elseif string.sub(sp,1,5)=="Bush_" then c.bush+=1 end
 end
 assert(c.tree==250 and c.pine==16 and c.bush==200 and #workspace.RSResourcesP45.Models:GetChildren()==1000 and #workspace.RSFallenLogsS082:GetChildren()==250,"Environment census")
 local E=workspace.RSEggydrasilS08;assert(E:GetAttribute("RSManagedId")=="s08:Eggydrasil:central" and math.abs(E:GetPivot().Y-78.4156036)<.01,"Eggydrasil v25")
 return c
end
local counts=census()
local folder,assets,template
local function checkTemplate(m)
 assert(m:IsA("Model") and m:GetAttribute("RSAssetId")=="76960331636475","Model identity")
 local mesh=m:FindFirstChildWhichIsA("MeshPart",true)
 assert(mesh and mesh.MeshId=="rbxassetid://136030103048719","Mesh identity")
 local sa=mesh:FindFirstChildWhichIsA("SurfaceAppearance")
 local tex=if sa then sa.ColorMap else mesh.TextureID
 assert(tex=="rbxassetid://72736310828855","Texture identity "..tostring(tex))
 local bones={};local meshCount=0
 for _,o in m:GetDescendants() do
  assert(not o:IsA("LuaSourceContainer"),"Unexpected asset script")
  if o:IsA("MeshPart") then meshCount+=1 elseif o:IsA("Bone") then bones[o.Name]=true end
 end
 local n=0;for _ in bones do n+=1 end
 assert(meshCount==1 and n==14 and m:FindFirstChildWhichIsA("AnimationController",true),"Rig contract")
 for _,name in {"Root","Body","Neck","Head","Jaw","Wing_L","Wing_R","Tail","Hip_L","Shin_L","Foot_L","Hip_R","Shin_R","Foot_R"} do assert(bones[name],"Missing bone "..name) end
 return n
end
if not verify then
 absent()
 folder=Instance.new("Folder");folder.Name="CreatureFramework";folder:SetAttribute("RSOwner","S095");folder.Parent=S
 assets=Instance.new("Folder");assets.Name="RSCreatureAssets";assets:SetAttribute("RSOwner","S095");assets.Parent=SS
 template=game:GetService("AssetService"):LoadAssetAsync(76960331636475)
 assert(template and template.Parent==nil)
 template.Name="ChickenV2";template:SetAttribute("RSAssetId","76960331636475");checkTemplate(template);template.Parent=assets
 for _,r in cfg.sources do
  local parent=if r.scope=="Module" then folder elseif r.scope=="Server" then S else client
  assert(not parent:FindFirstChild(r.name),"Script collision")
  local o=Instance.new(r.class);o.Name=r.name;o.Source=r.source
  if o:IsA("BaseScript") then o.Enabled=false end
  o:SetAttribute("RSSceneSyncId",r.id);o.Parent=parent
  assert(hash(o.Source)==r.hash,"Source hash")
 end
 -- Enable only after the dependencies and inert template are present.
 S.CreatureBootstrap.Enabled=true;client.RSBook.Enabled=true
else
 folder=S:FindFirstChild("CreatureFramework");assets=SS:FindFirstChild("RSCreatureAssets")
 assert(folder and assets and folder:GetAttribute("RSOwner")=="S095" and assets:GetAttribute("RSOwner")=="S095")
 template=assets:FindFirstChild("ChickenV2");assert(template)
end
assert(#folder:GetChildren()==30 and #assets:GetChildren()==1,"Installed scope count")
local hashes={};for _,r in cfg.sources do
 local parent=if r.scope=="Module" then folder elseif r.scope=="Server" then S else client
 local o=parent:FindFirstChild(r.name)
 assert(o and o.ClassName==r.class and o:GetAttribute("RSSceneSyncId")==r.id and hash(o.Source)==r.hash,"Installed source "..r.name)
 if o:IsA("BaseScript") then assert(o.Enabled,"Script disabled") end
 hashes[r.id]=r.hash
end
local bones=checkTemplate(template)
local function get(n)return require(folder:FindFirstChild(n)) end
local flags=get("FeatureFlags");assert(flags.Enabled,"Staging flag not enabled")
local registry=get("CreatureRegistry");local species=assert(registry.get("210080"))
local spawn=get("SpawnPolicy");assert(spawn.chicken.maximum==15 and spawn.chicken.respawnSeconds==300 and spawn.chicken.allowedMaterials.Grass)
assert(#get("BiomeRegions").regions("emerald_valley")==9 and registry.bookRow("210080",true).id=="210080")
assert(not workspace:FindFirstChild("RSCreatures") and not game:GetService("ReplicatedStorage"):FindFirstChild("RSBookTransport"),"Runtime objects not part of saved scene")
assert(fingerprint()==beforeFP and environment()==env,"Unexpected scene changes")
local endTerrain=terrainState();assert(#endTerrain==49)
for _,r in endTerrain do assert(cfg.expectedTerrain[r.id]==r.digest,"Terrain changed") end
local result={noPlaceWrites=cfg.mode~="apply",fingerprint=beforeFP,environment=env,terrainRegions=#endTerrain,counts=counts,installedScripts=#cfg.sources,sourceHashes=hashes,bones=bones,enabled=true,maximum=15,respawnSeconds=300,biomes=9,template=true,clientRenderVerified=false,defaultClonePairNormalized=true}
if cfg.mode=="apply" then
 assert(cfg.confirmStaging and game.PlaceVersion==25,"Explicit save guard")
 game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false});result.saved=true
elseif verify then result.verified=true
else result.readyForStaging=true end
return syncResult(result)
