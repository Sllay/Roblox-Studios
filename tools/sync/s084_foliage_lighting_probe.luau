-- Read-only v23 surface parity check; not a rendering test.
assert(game.PlaceId==93428341652658 and game.GameId==10769712441 and game.PlaceVersion==23,"Staging v23")
local W=workspace
local function row(p)
 assert(p and p:IsA("MeshPart"))
 local s=p:FindFirstChildWhichIsA("SurfaceAppearance");assert(s)
 local r={material=p.Material.Name,materialVariant=p.MaterialVariant,reflectance=p.Reflectance,doubleSided=p.DoubleSided,castShadow=p.CastShadow,partColor=rgb(p.Color),tint=rgb(s.Color),alpha=s.AlphaMode.Name,transparency=p.Transparency,mesh=p.MeshId,texture=p.TextureID,resample=s.ResampleMode.Name,emissiveStrength=s.EmissiveStrength}
 for _,k in {"ColorMapContent","NormalMapContent","RoughnessMapContent","MetalnessMapContent","EmissiveMaskContent"} do local v=s[k];r[k]={source=v.SourceType.Name,uri=v.Uri or ""} end
 return r
end
local egg=W.RSEggydrasilS08
local refs={white=row(egg:FindFirstChild("Canopy_White",true)),gray=row(egg:FindFirstChild("Canopy_Gray",true))}
local names={Tree_01="Canopy_01",Tree_03="Canopy_03",Tree_08="Canopy_08",Tree_12="Canopy_12"}
local species={};local count=0
for _,m in W.RSVegetationS06.Models:GetChildren() do
 local k=m:GetAttribute("RSSpecies")
 if not names[k] then continue end
 count+=1
 local p=m:FindFirstChild(names[k]);local r=row(p)
 local a=species[k] or {count=0,variants={}};species[k]=a;a.count+=1
 local key=hash(Http:JSONEncode(r))
 if not a.variants[key] then a.variants[key]={count=0,properties=r} end
 a.variants[key].count+=1
end
assert(count==250)
return syncResult({egg=refs,trees=species,count=count,lighting=lightingState(),noPlaceWrites=true,clientRenderVerified=false})
