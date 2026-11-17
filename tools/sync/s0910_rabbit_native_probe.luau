do
local AssetService=game:GetService("AssetService")
local ContentProvider=game:GetService("ContentProvider")
assert(game.GameId==10769712441 and game.PlaceId==93428341652658,"staging-only identity")
local assetId=assert(tonumber(cfg.assetId),"numeric asset id")
local wrap=AssetService:LoadAssetAsync(assetId)
assert(wrap:IsA("Model") and wrap.Parent==nil,"detached import")
local parts,bones,names,skinMeshes,scriptCount={},{},{},{},0
local children={}
local textureURIs={}
local classes={}
for _,o in wrap:GetDescendants() do
 classes[o.ClassName]=(classes[o.ClassName] or 0)+1
 if o:IsA("LuaSourceContainer") then scriptCount+=1 end
 if o:IsA("MeshPart") then
  table.insert(parts,o)
  table.insert(skinMeshes,{name=o.Name,meshId=o.MeshId,textureId=o.TextureID,size={o.Size.X,o.Size.Y,o.Size.Z}})
  if o.TextureID~="" then table.insert(textureURIs,o.TextureID) end
 end
 if o:IsA("Bone") then bones[o.Name]=o;table.insert(names,o.Name) end
 if o:IsA("SurfaceAppearance") and o.ColorMap~="" then table.insert(textureURIs,o.ColorMap) end
end
table.sort(names)
local boneRows={}
for _,name in names do
 local b=bones[name]
 table.insert(boneRows,{name=name,parent=b.Parent.Name,parentClass=b.Parent.ClassName,localFrame={b.CFrame:GetComponents()}})
end
local expected={"Root","Pelvis","Chest","Head","Ear_L","Ear_R","Shoulder_L","Shoulder_R","Forearm_L","Forearm_R","FrontPaw_L","FrontPaw_R","Hip_L","Hip_R","Shin_L","Shin_R","HindPaw_L","HindPaw_R","Tail"}
local expectedNames=true
for _,name in expected do if not bones[name] then expectedNames=false end end
local unique=0;for _ in pairs(bones) do unique+=1 end
local whiskers=0;for _,p in parts do if string.match(p.Name,"^Whisker_[LR]_[123]$") then whiskers+=1 end end
local poseRoundtrip=false
if expectedNames then
 poseRoundtrip=true
 for _,name in {"Head","Ear_L","Ear_R","Shoulder_L","Shoulder_R","Hip_L","Hip_R","Tail"} do
  local b=bones[name];local initial=b.Transform;local posed=initial*CFrame.Angles(math.rad(11),0,0)
  b.Transform=posed
  local result={b.Transform:GetComponents()};local target={posed:GetComponents()}
  for i=1,12 do if math.abs(result[i]-target[i])>1e-5 then poseRoundtrip=false end end
  b.Transform=initial
 end
end
local meshOK=0
for _,p in parts do
 local loaded=false
 local ok=pcall(function()
  ContentProvider:PreloadAsync({p},function(_,status)
   if status==Enum.AssetFetchStatus.Success then loaded=true end
  end)
 end)
 if ok and loaded then meshOK+=1 end
end
local textureOK=0;local inspected={}
for _,uri in textureURIs do
 local loaded=false
 local ok=pcall(function()
  ContentProvider:PreloadAsync({uri},function(_,status)
   if status==Enum.AssetFetchStatus.Success then loaded=true end
  end)
 end)
 if ok and loaded then textureOK+=1 end
 table.insert(inspected,{uri=uri,loaded=ok and loaded})
end
local _,bbox=wrap:GetBoundingBox()
local report={assetId=tostring(assetId),noPlaceWrites=true,models=1,meshCount=#parts,whiskers=whiskers,bones=unique,
 expectedBones=expectedNames,boneNames=names,boneRows=boneRows,poseRoundtrip=poseRoundtrip,scripts=scriptCount,
 meshLoaded=meshOK,textureLoaded=textureOK,textureURIs=inspected,meshRows=skinMeshes,classes=classes,
 boundingSize={bbox.X,bbox.Y,bbox.Z},boneCountExpected=19}
wrap:Destroy()
return syncResult(report)
end