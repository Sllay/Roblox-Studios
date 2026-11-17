-- S09.10 Rabbit V34: staging-only animation/runtime patch on VERIFIED V33.
-- No asset/model/terrain replacement. Preview is detached and does not save.
local mode=cfg.mode
assert(mode=="preview" or mode=="apply" or mode=="verify","mode")
local verify=mode=="verify"
local beforeVersion=if verify then 34 else 33
assert(game.GameId==10769712441 and game.PlaceId==93428341652658 and game.PlaceVersion==beforeVersion,"Staging target/version drift")
local S=game:GetService("ServerScriptService")
local SS=game:GetService("ServerStorage")
local SP=game:GetService("StarterPlayer")
local A=game:GetService("AssetService")
local root=assert(S:FindFirstChild("CreatureFramework"),"Missing V33 CreatureFramework")
local assets=assert(SS:FindFirstChild("RSCreatureAssets"),"Missing V33 creature assets")
local chicken=assert(assets:FindFirstChild("ChickenV2"),"ChickenV2 preserved")
assert(chicken:IsA("Model") and chicken:GetAttribute("RSAssetId")=="76960331636475","Chicken V33 identity")
local expectedOld=cfg.oldHashes
local originalModuleCount=0
for _,module in root:GetChildren() do if module:IsA("ModuleScript") then originalModuleCount+=1 end end
assert(originalModuleCount==34,"CreatureFramework module count changed unexpectedly")
local function rowInstance(row,allowMissing)
 local parent=if row.scope=="Module" then root elseif row.scope=="Server" then S else SP.StarterPlayerScripts
 local o=parent:FindFirstChild(row.name)
 if not o and allowMissing then return nil,parent end
 assert(o and o.ClassName==row.class and o:GetAttribute("RSSceneSyncId")==row.id,"Script identity "..row.name)
 return o,parent
end
for _,row in cfg.sources do
 local old=expectedOld[row.id]
 if old or verify then
  local o=rowInstance(row,false)
  assert(hash(o.Source)==(if verify then row.hash else old),"Source hash drift "..row.name)
 else
  assert(row.scope=="Module" and row.class=="ModuleScript","Only new framework modules permitted")
  local o=rowInstance(row,true)
  assert(o==nil,"Unexpected preexisting script "..row.name)
 end
end
local function terrain()
 local rows=terrainState()
 assert(#rows==49,"Expected 49 stored terrain regions")
 local map={}
 for _,r in rows do map[r.id]=r.digest end
 return map
end
local startTerrain=terrain()
if cfg.expectedTerrain then
 for id,digest in pairs(cfg.expectedTerrain) do assert(startTerrain[id]==digest,"Unexpected terrain change "..tostring(id)) end
end
local template=assert(assets:FindFirstChild("RabbitV3"),"Rabbit template missing in V33")
assert(template:IsA("Model"),"Rabbit V33 template type")
assert(template:GetAttribute("RSAssetId")==tostring(cfg.modelAssetId) and template:GetAttribute("RSOwner")=="S0910","Rabbit template identity")
local function checkModel(model)
 local meshes,bones,whiskers,parts,scripts=0,0,0,0,0
 local names={}
 for _,o in model:GetDescendants() do
  if o:IsA("MeshPart") then
   meshes+=1
   if string.match(o.Name,"^Whisker_[LR]_[123]$") then whiskers+=1 end
  end
  if o:IsA("Bone") then bones+=1;names[o.Name]=true end
  if o:IsA("BasePart") then parts+=1 end
  if o:IsA("LuaSourceContainer") then scripts+=1 end
 end
 assert(meshes==9 and bones==19 and whiskers==6 and parts>=10 and scripts==0,"Rabbit native mesh/bone/whisker contract")
 assert(model:FindFirstChild("RootPart",true) and model:FindFirstChild("Rabbit_Torso",true),"Native rig and torso")
 assert(model:FindFirstChildWhichIsA("AnimationController",true),"Native animation controller")
 for _,name in {"Root","Pelvis","Chest","Head","Ear_L","Ear_R","Shoulder_L","Shoulder_R","Hip_L","Hip_R","Tail"} do assert(names[name],"Missing bone "..name) end
 return {meshCount=meshes,bones=bones,whiskers=whiskers,baseParts=parts,scripts=scripts}
end
local geometry=checkModel(template)
local newHashes={}
for _,row in cfg.sources do newHashes[row.id]=row.hash end
if not verify then
 for _,row in cfg.sources do
  local o,parent=rowInstance(row,true)
  if not o then
   assert(not expectedOld[row.id] and row.scope=="Module","Unreviewed new script")
   o=Instance.new(row.class);o.Name=row.name;o:SetAttribute("RSSceneSyncId",row.id);o.Parent=parent
  end
  if o:IsA("BaseScript") then o.Enabled=false end
  o.Source=row.source
  if o:IsA("BaseScript") then o.Enabled=true end
  assert(hash(o.Source)==row.hash,"Script readback "..row.name)
 end
 assert(#root:GetChildren()==34,"Expected 34 CreatureFramework modules after incremental update")
end
-- Preview uses isolated modules with NEW code; V33 saved modules remain untouched.
local function get(name) return require(assert(root:FindFirstChild(name),name)) end
local function changed(name)
 if mode~="preview" then return get(name) end
 for _,row in cfg.sources do
  if row.name==name then
   local tmp=Instance.new("ModuleScript");tmp.Name="V34Preview_"..name;tmp.Source=row.source;tmp.Parent=S
   local module=require(tmp);tmp:Destroy()
   return module
  end
 end
 error("V34 changed module missing: "..name)
end
local species=assert(changed("CreatureRegistry").get("210081"))
for _,clip in {"Idle","Walk","Run","ScratchEar"} do
 assert(species.animations[clip]==cfg.animationIds[clip],"V34 animation binding "..clip)
end
assert(species.modelAssetId==tostring(cfg.modelAssetId) and species.profile=="PassivePrey","Rabbit identity / brain")
local rabbitSpawn=get("SpawnPolicy").rabbit
assert(rabbitSpawn.speciesId=="210081" and rabbitSpawn.maximum==8 and rabbitSpawn.initial==4 and rabbitSpawn.perChunk==2,"Rabbit population")
local ecology=get("WildlifeProfiles").rabbit
assert(ecology.groupKind=="Solo" and ecology.groupMax==1 and not ecology.territorial,"Rabbit solitary behavior")
assert(get("FeatureFlags").RabbitEnabled,"Rabbit staging feature flag")
assert(#get("BiomeRegions").regions("emerald_valley")==9,"Rabbit biomes")
local movementOK=false
local aiOK=false
if not verify then
 -- No test objects persist. Probe animation binding, all-part root motion, native terrain.
 local parent=Instance.new("Folder");parent.Name="RabbitNativeProbe";parent.Parent=workspace
 local clone=template:Clone();clone.Parent=parent
 local adapter=changed("RobloxMobAdapter").new(workspace,clone,species,get("EscapePlanner"),{
  contains=function(x,z)return get("BiomeRegions").regionAt("emerald_valley",x,z)~=nil end,
  materials={[Enum.Material.Grass]=true},
  random=function()return .35 end
 })
 assert(#adapter.visualParts==9 and #adapter.rigParts>=10,"Multi-mesh movement binder")
 local placed=nil
 for _,region in get("BiomeRegions").regions("emerald_valley") do
  for x=region.minX+8,region.maxX-8,12 do
   for z=region.minZ+8,region.maxZ-8,12 do
    local ground=adapter:ground(x,z)
    if ground then placed=ground;break end
   end
   if placed then break end
  end
  if placed then break end
 end
 assert(placed and adapter:place(placed),"Rabbit terrain spawn probe")
 local relative={}
 for _,part in adapter.rigParts do relative[part]=adapter.mesh.CFrame:ToObjectSpace(part.CFrame) end
 adapter:relocate(adapter.mesh.CFrame*CFrame.new(.14,0,.2))
 local maxError=0
 for part,old in pairs(relative) do
  local a={old:GetComponents()};local b={adapter.mesh.CFrame:ToObjectSpace(part.CFrame):GetComponents()}
  for i=1,12 do maxError=math.max(maxError,math.abs(a[i]-b[i])) end
 end
 movementOK=maxError<.002 and adapter.hitbox.CFrame==adapter.mesh.CFrame
 -- The passive decisions are reused from Chicken (no second AI implementation).
 local brain=changed("MobBrain");local memory=brain.new()
 local baseSense={dt=.1,alive=true,aiEnabled=true,hit=false,threatVisible=true,threatDistance=6,approachSpeed=2,approachThreshold=9.6,predator=false,jumping=false,
  actionComplete=false,foodConsumed=false,foodAvailable=false,atFood=false,pathBlocked=false,escapeAvailable=true,stuck=false,random=.5}
 local calm=brain.step(memory,baseSense,get("AIKernel").canInterrupt)
 baseSense.jumping=true
 local fleeing=brain.step(memory,baseSense,get("AIKernel").canInterrupt)
 aiOK=calm.state=="Idle" and fleeing.state=="Flee"
 -- Rabbit can finish grooming if safe but danger interrupts the same tick.
 local m=brain.new()
 local idleSense={dt=2,alive=true,aiEnabled=true,hit=false,threatVisible=false,
  threatDistance=100,approachSpeed=0,approachThreshold=9.6,predator=false,jumping=false,
  actionComplete=false,foodConsumed=false,foodAvailable=false,atFood=false,
  pathBlocked=false,escapeAvailable=true,stuck=false,random=.5,
  routineFood=false,routineFlap=false,idleSeconds=3.25,exploreSeconds=9.5,cosmeticActionPlaying=true}
 local hold=brain.step(m,idleSense,get("AIKernel").canInterrupt)
 idleSense.predator=true;idleSense.threatVisible=true;idleSense.threatDistance=2
 local danger=brain.step(m,idleSense,get("AIKernel").canInterrupt)
 aiOK=aiOK and hold.state=="Idle" and danger.state=="Flee"
 for _,clip in {"Idle","Walk","Run","ScratchEar"} do
  adapter:animate(clip,1)
  assert(adapter.tracks[clip]~=nil,"V34 native clip not usable: "..clip)
 end
 adapter:enter({state="Idle",animation="Idle"})
 adapter.scratchAt=adapter.clock-.01
 adapter:execute({state="Idle",action="Stop",animation="Idle"},.05)
 assert(adapter.lastClip=="ScratchEar" and adapter.scratchUntil~=nil,"Ear scratch failed")
 adapter:enter({state="Flee",animation="Run"})
 assert(adapter.lastClip=="Run" and adapter.scratchUntil==nil,"Scratch not interrupted by danger")
 adapter:destroy();parent:Destroy()
 assert(movementOK and aiOK,"Rabbit adapter movement/brain smoke")
end
-- Preserve terrain and unrelated existing creature assets.
local endTerrain=terrain()
for id,d in pairs(startTerrain) do assert(endTerrain[id]==d,"Terrain drift "..tostring(id)) end
assert(assets:FindFirstChild("ChickenV2")==chicken and root:GetChildren()~=nil,"Chicken / CreatureFramework preserved")
local result={
 noPlaceWrites=mode~="apply",sourceHashes=newHashes,terrainDigests=startTerrain,terrainRegions=49,
 geometry=geometry,rabbitModelId=tostring(cfg.modelAssetId),speciesId="210081",
 rabbitInitial=4,rabbitMaximum=8,rabbitHasSoloAI=true,animationIds=cfg.animationIds,
 movementProbe=movementOK,brainProbe=aiOK,
 runtimeClientFPSVerified=false,previewOnly=mode=="preview"
}
if mode=="apply" then
 assert(cfg.confirmStaging==true and game.PlaceVersion==33,"Staging save required version33")
 A:SavePlaceAsync({SaveWithoutPublish=false})
 result.saved=true
elseif verify then
 result.verified=true
else
 result.readyForStaging=true
end
return syncResult(result)
