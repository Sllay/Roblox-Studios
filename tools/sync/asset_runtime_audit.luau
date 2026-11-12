-- Audit only installed managed visuals. No pack scripts executed.
local CP=game:GetService("ContentProvider")
local roots={"RSSceneBuilder","RSWorldVegetation","RSEnvironmentP4","RSEnvironmentP4Detail","RSManagedAssets","RSResourcesP45"}
local deps={};local representatives={};local counts={};local issues={};local total=0
local function add(id,asset,role)
    if id=="" then return end
    assert(string.match(id,"^rbxassetid://%d+$"),"Unexpected content URI")
    local d=deps[id]
    if not d then d={uri=id,uses=0,assets={},roles={}};deps[id]=d end
    d.uses+=1;d.assets[asset]=true;d.roles[role]=true
end
for _,name in roots do
    local r=workspace:FindFirstChild(name);assert(r,"Managed root")
    local folder=if name=="RSManagedAssets" then r else r:FindFirstChild("Models")
    assert(folder,"Models")
    for _,m in folder:GetChildren() do
        if not m:IsA("Model") then continue end
        local asset=m:GetAttribute("RSAssetId")
        assert(typeof(asset)=="string","Asset provenance")
        total+=1;counts[asset]=(counts[asset] or 0)+1
        local meshes=0
        for _,o in m:GetDescendants() do
            if o:IsA("MeshPart") then
                meshes+=1
                add(o.MeshId,asset,"mesh")
                representatives[o.MeshId]=o
                add(o.TextureID,asset,"texture")
            elseif o:IsA("SurfaceAppearance") then
                for _,prop in {"ColorMapContent","NormalMapContent","RoughnessMapContent","MetalnessMapContent","EmissiveMaskContent"} do
                    local ok,v=pcall(function()return o[prop]end)
                    if ok and v.SourceType.Name=="Uri" then add(v.Uri,asset,prop)
                    elseif not ok then table.insert(issues,{id=m.Name,property=prop,reason="unreadable"}) end
                end
            elseif o:IsA("LuaSourceContainer") then error("Unexpected managed embedded code") end
        end
        assert(meshes>0,"Missing visual")
    end
end
local uris={}
for id in deps do table.insert(uris,id) end
table.sort(uris);assert(#uris<=128,"Dependency budget")
local out={}
for _,id in uris do
    local row=deps[id]
    local callback="not_called"
    local ok,err=pcall(function()
        CP:PreloadAsync({id},function(_,status) callback=status.Name end)
    end)
    local statusOK,status=pcall(function()return CP:GetAssetFetchStatus(id).Name end)
    row.uriPreload=if ok then callback else "error"
    row.uriFetch=if statusOK then status else "unavailable"
    row.preload=row.uriPreload;row.fetch=row.uriFetch
    if representatives[id] then
        local statuses={}
        local meshOK,meshErr=pcall(function()
            CP:PreloadAsync({representatives[id]},function(uri,status0) statuses[uri]=status0.Name end)
        end)
        row.instancePreload=if meshOK then statuses[id] or "not_called" else "error"
        row.preload=row.instancePreload
        row.fetch=if row.instancePreload=="Success" then "Success" else row.uriFetch
        if not meshOK then row.instanceError=tostring(meshErr):sub(1,160) end
    end
    if not ok then row.error=tostring(err):sub(1,160) end
    table.insert(out,row)
end
return syncResult({models=total,assetCounts=counts,dependencies=out,issues=issues,noPlaceWrites=true,clientRenderVerified=false})
