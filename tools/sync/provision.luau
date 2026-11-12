-- Official Roblox API, no session cookie, no arbitrary asset creation.
local Http=game:GetService("HttpService")
local cfg=Http:JSONDecode(__RS_CONFIG__)
assert(tostring(game.GameId)==cfg.universeId and tostring(game.PlaceId)==cfg.placeId,"Identity mismatch")
local A=game:GetService("AssetService")
local function output(d)
    d.universeId=tostring(game.GameId);d.placeId=tostring(game.PlaceId)
    d.creatorId=tostring(game.CreatorId);d.creatorType=game.CreatorType.Name
    return Http:JSONEncode(d)
end
if cfg.mode=="identity" then
    return output({name=game.Name,verified=true,version=game.PlaceVersion})
end
local function listPlaces()
    local pages=A:GetGamePlacesAsync()
    local result={}
    for _=1,100 do
        for _,p in pages:GetCurrentPage() do
            table.insert(result,{id=tostring(p.PlaceId),name=p.Name})
        end
        if pages.IsFinished then return result end
        pages:AdvanceToNextPageAsync()
    end
    error("Place pagination budget")
end
local places=listPlaces()
local templateFound=false
for _,p in places do
    if p.id==cfg.placeId then templateFound=true end
    if cfg.name then assert(p.name~=cfg.name,"Place name already exists; inspect, do not retry") end
end
assert(templateFound,"Template not listed in experience")
if cfg.mode=="inventory" or cfg.mode=="clone-preview" then
    return output({verified=true,places=places,templateFound=true,cloneEligible=cfg.templateEligible==true})
end
assert(cfg.mode=="clone" and cfg.confirm and cfg.templateEligible and game.PlaceVersion==cfg.expectedVersion,"Creation not authorized")
local id=A:CreatePlaceAsync(cfg.name,game.PlaceId,cfg.description)
assert(typeof(id)=="number" and id>0 and id~=game.PlaceId,"Invalid new Place ID")
return output({created=true,newPlaceId=tostring(id),name=cfg.name})
