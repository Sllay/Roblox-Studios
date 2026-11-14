-- Detached material comparison. No scene mutation, no SavePlaceAsync.
assert(game.PlaceId==93428341652658 and game.GameId==10769712441 and game.PlaceVersion==22,"Staging v22")
local W=workspace
local V=W.RSVegetationS06.Models
local E=W.RSEggydrasilS08
local CP=game:GetService("ContentProvider")
local names={Tree_01="Canopy_01",Tree_03="Canopy_03",Tree_08="Canopy_08",Tree_12="Canopy_12"}
local uris={white="rbxassetid://89626593244521",gray="rbxassetid://109528136250293"}
local function rgb(c)return {c.R,c.G,c.B} end
local function surface(p)
 local s=p:FindFirstChildWhichIsA("SurfaceAppearance")
 assert(s,"Missing surface "..p.Name)
 return s
end
local function describe(p)
 local s=surface(p)
 return {mesh=p.MeshId,material=p.Material.Name,variant=p.MaterialVariant,texture=p.TextureID,doubleSided=p.DoubleSided,castShadow=p.CastShadow,reflectance=p.Reflectance,color=rgb(s.Color),alpha=s.AlphaMode.Name,colorMap=s.ColorMap,normal=s.NormalMap,roughness=s.RoughnessMap,metalness=s.MetalnessMap}
end
local refs={}
for k,uri in uris do
 local p=E:FindFirstChild(if k=="white" then "Canopy_White" else "Canopy_Gray",true)
 assert(p and p:IsA("MeshPart"),"Eggy reference")
 local s=surface(p)
 assert(s.ColorMapContent.Uri==uri and s.AlphaMode==Enum.AlphaMode.Transparency,"Eggy surface")
 refs[k]=p
end
local fetched={}
for k,uri in uris do
 local ok=false
 CP:PreloadAsync({uri},function(_,status)if status==Enum.AssetFetchStatus.Success then ok=true end end)
 assert(ok,"Texture preload "..k);fetched[k]=true
end
local counts={tree=0,pine=0,bush=0};local species={};local examples={}
for _,m in V:GetChildren() do
 local s=m:GetAttribute("RSSpecies") or ""
 if string.sub(s,1,5)=="Tree_" then
  assert(names[s] and m:IsA("Model"),"Unknown tree "..s)
  local p=m:FindFirstChild(names[s])
  assert(p and p:IsA("MeshPart") and p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,"Canopy policy")
  assert(m:GetAttribute("RSAssetId")=="79689531752352","Tree source")
  local row=species[s] or {count=0,variants={}}
  row.count+=1;species[s]=row;counts.tree+=1
  local signature=p.MeshId..":"..p.Material.Name..":"..surface(p).ColorMap
  if not row.variants[signature] then
   row.variants[signature]=describe(p)
   table.insert(examples,{model=m,part=p,species=s})
  end
 elseif string.sub(s,1,5)=="Pine_" then counts.pine+=1
 elseif string.sub(s,1,5)=="Bush_" then counts.bush+=1 end
end
assert(counts.tree==250 and counts.pine==16 and counts.bush==200,"Population")
local results={}
for _,r in examples do
 for k,ref in refs do
  local m=r.model:Clone();local p=m:FindFirstChild(r.part.Name)
  local old=surface(p);local tint=old.Color
  local mesh,size,pose=p.MeshId,p.Size,p.CFrame
  local children=#p:GetDescendants()
  old:Destroy()
  local s=surface(ref):Clone()
  s.Color=tint
  assert(s.NormalMap=="" and s.RoughnessMap=="" and s.MetalnessMap=="","Unexpected Eggy extra PBR maps")
  s.Parent=p
  p.TextureID="";p.Material=Enum.Material.Plastic;p.MaterialVariant="";p.Reflectance=0
  p.Color=Color3.new(1,1,1);p.DoubleSided=ref.DoubleSided;p.CastShadow=ref.CastShadow
  -- Explicit existing wind contract, without editing the wind controller.
  assert(m:GetAttribute("RSWindRigVersion")==nil or m:GetAttribute("RSWindRigVersion")==1,"Wind rig version")
  m:SetAttribute("RSWindRigVersion",1);p:SetAttribute("RSWindRigRole","Canopy")
  assert(p.MeshId==mesh and p.Size==size and p.CFrame==pose and #p:GetDescendants()==children,"Geometry or hierarchy changed")
  assert(s.ColorMapContent.Uri==uris[k] and s.AlphaMode==Enum.AlphaMode.Transparency and p.MaterialVariant=="" and p.Reflectance==0,"Material contract")
  assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,"Physics changed")
  table.insert(results,{species=r.species,variant=k,before=describe(r.part),after=describe(p),windRole=p:GetAttribute("RSWindRigRole"),geometryUnchanged=true})
  m:Destroy()
 end
end
return syncResult({counts=counts,species=species,eggydrasil={white=describe(refs.white),gray=describe(refs.gray)},preloaded=fetched,samples=results,noPlaceWrites=true,clientRenderVerified=false,uvVisualVerified=false,readyForPublication=false})
