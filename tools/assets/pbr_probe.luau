--!strict
-- Read-only: no parenting, no saving. Inspect the exact selected model.
local Http=game:GetService("HttpService")
local Assets=game:GetService("AssetService")
local cfg=Http:JSONDecode(__RS_CONFIG__)
assert(tostring(game.GameId)==cfg.universeId and tostring(game.PlaceId)==cfg.placeId)
local root=Assets:LoadAssetAsync(tonumber(cfg.assetId))
local cursor: Instance=root
for _,s in cfg.selector do
    local child=cursor:GetChildren()[s.index]
    assert(child and child.Name==s.name and child.ClassName==s.class,"Selector changed")
    cursor=child
end
assert(cursor:IsA("Model"))
local model=cursor:Clone()
assert(model and model.Parent==nil and #model:GetDescendants()==#cursor:GetDescendants())
local maps={}
for _,obj in model:GetDescendants() do
    if obj:IsA("SurfaceAppearance") then
        local fields={}
        for _,name in {"ColorMapContent","NormalMapContent","MetalnessMapContent","RoughnessMapContent","EmissiveMaskContent","TexturePackContent"} do
            local ok,value=pcall(function() return (obj::any)[name] end)
            if ok and typeof(value)=="Content" then
                fields[name]={source=value.SourceType.Name,uri=value.Uri}
            else
                fields[name]={error=tostring(value)}
            end
        end
        table.insert(maps,{name=obj.Name,parent=obj.Parent.Name,fields=fields})
    end
end
local serial=game:GetService("SerializationService")
local encoding=game:GetService("EncodingService")
local blob=serial:SerializeInstancesAsync({model})
local hash=buffer.tostring(encoding:Base64Encode(encoding:ComputeBufferHash(blob,Enum.HashAlgorithm.Sha256)))
local mesh={}
for _,obj in model:GetDescendants() do
    if obj:IsA("MeshPart") then
        table.insert(mesh,{name=obj.Name,mesh=obj.MeshId,texture=obj.TextureID,material=obj.Material.Name,variant=obj.MaterialVariant})
    end
end
local grounds={}
for _,obj in workspace:GetDescendants() do
    if obj:IsA("BasePart") then
        table.insert(grounds,{name=obj.Name,class=obj.ClassName,position={obj.Position.X,obj.Position.Y,obj.Position.Z},size={obj.Size.X,obj.Size.Y,obj.Size.Z}})
    end
end
model:Destroy()
root:Destroy()
return Http:JSONEncode({universeId=tostring(game.GameId),placeId=tostring(game.PlaceId),maps=maps,mesh=mesh,ground=grounds,serializedBytes=buffer.len(blob),digest=hash,serializedBase64=buffer.tostring(encoding:Base64Encode(blob))})
