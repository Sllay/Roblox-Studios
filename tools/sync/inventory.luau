-- Read-only inventory of explicitly scoped services. Script text and arbitrary
-- attribute values are never exported to GitHub.
local Http=game:GetService("HttpService")
local Encoding=game:GetService("EncodingService")
local cfg=Http:JSONDecode(__RS_CONFIG__)
assert(tostring(game.GameId)==cfg.universeId and tostring(game.PlaceId)==cfg.placeId,"Target mismatch")
local function hash(value)
    return buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(buffer.fromstring(value),Enum.HashAlgorithm.Sha256)))
end
local function vec(v) return {v.X,v.Y,v.Z} end
local function rgb(v) return {v.R,v.G,v.B} end
local function pathFor(root,obj)
    local segments={}
    local ambiguous=false
    while obj~=root do
        local parent=obj.Parent
        assert(parent,"Invalid ancestry")
        local index,total=0,0
        for _,c in parent:GetChildren() do
            if c.Name==obj.Name and c.ClassName==obj.ClassName then
                total+=1
                if c==obj then index=total end
            end
        end
        if total>1 then ambiguous=true end
        table.insert(segments,1,{name=obj.Name,class=obj.ClassName,ordinal=index})
        obj=parent
    end
    return segments,ambiguous
end
local function locate(service,path)
    local cursor=game:GetService(service)
    for _,s in path do
        local matches={}
        for _,c in cursor:GetChildren() do if c.Name==s.name and c.ClassName==s.class then table.insert(matches,c) end end
        assert(#matches==1 and s.ordinal==1,"Ambiguous or changed selector")
        cursor=matches[1]
    end
    return cursor
end
local function record(root,obj)
    local path,ambiguous=pathFor(root,obj)
    local id=obj:GetAttribute("RSSceneSyncId") or obj:GetAttribute("RSManagedId")
    local attrs={}
    for k,v in obj:GetAttributes() do table.insert(attrs,{k,typeof(v),tostring(v)}) end
    table.sort(attrs,function(a,b) return a[1]<b[1] end)
    local tags=game:GetService("CollectionService"):GetTags(obj);table.sort(tags)
    local r={service=root.ClassName,path=path,class=obj.ClassName,name=obj.Name,ambiguous=ambiguous,
        managedId=if typeof(id)=="string" then id else "",childCount=#obj:GetChildren(),attributesHash=hash(Http:JSONEncode(attrs)),tagsHash=hash(Http:JSONEncode(tags)),properties={},coverage="structure"}
    local p=r.properties
    if obj:IsA("BasePart") and not obj:IsA("Terrain") then
        r.coverage="basepart"
        p.cframe={obj.CFrame:GetComponents()};p.size=vec(obj.Size);p.color=rgb(obj.Color);p.material=obj.Material.Name
        p.anchored=obj.Anchored;p.canCollide=obj.CanCollide;p.canTouch=obj.CanTouch;p.canQuery=obj.CanQuery;p.transparency=obj.Transparency
        p.reflectance=obj.Reflectance;p.castShadow=obj.CastShadow;p.materialVariant=obj.MaterialVariant
        p.collisionGroup=obj.CollisionGroup;p.massless=obj.Massless
        if obj:IsA("Part") then p.shape=obj.Shape.Name end
        if obj:IsA("SpawnLocation") then p.enabled=obj.Enabled;p.neutral=obj.Neutral;p.duration=obj.Duration;p.allowTeamChangeOnTouch=obj.AllowTeamChangeOnTouch end
        if obj:IsA("MeshPart") then p.meshId=obj.MeshId;p.textureId=obj.TextureID;p.renderFidelity=obj.RenderFidelity.Name;p.collisionFidelity=obj.CollisionFidelity.Name end
    elseif obj:IsA("Model") then
        r.coverage="model";p.pivot={obj:GetPivot():GetComponents()};p.scale=obj:GetScale()
    elseif obj:IsA("LuaSourceContainer") then
        r.coverage="script_hash"
        local ok,src=pcall(function() return obj.Source end)
        if ok then p.sourceHash=hash(src);p.sourceBytes=#src else r.coverage="script_unreadable" end
        if obj:IsA("BaseScript") then p.enabled=obj.Enabled;p.runContext=obj.RunContext.Name end
    elseif obj:IsA("SurfaceAppearance") then
        r.coverage="surface_appearance_authoring"
        p.color=rgb(obj.Color);p.alphaMode=obj.AlphaMode.Name;p.emissiveStrength=obj.EmissiveStrength
        for _,k in {"ColorMapContent","NormalMapContent","RoughnessMapContent","MetalnessMapContent","EmissiveMaskContent"} do
            local ok,v=pcall(function() return obj[k] end)
            if ok then p[k]={source=v.SourceType.Name,uri=v.Uri or ""} else r.coverage="surface_appearance_partial" end
        end
    end
    return r
end
local function terrainState()
    local out={}
    local T=workspace.Terrain
    for _,region in cfg.regions do
        local b=region.bounds
        local nx,ny,nz=(b[4]-b[1])/4,(b[5]-b[2])/4,(b[6]-b[3])/4
        local d=T:ReadVoxelChannels(Region3.new(Vector3.new(b[1],b[2],b[3]),Vector3.new(b[4],b[5],b[6])),4,{"SolidMaterial","SolidOccupancy","LiquidOccupancy"})
        local blob=buffer.create(nx*ny*nz*6)
        local offset,solid,water=0,0,0
        for x=1,nx do for y=1,ny do for z=1,nz do
            local s,w=d.SolidOccupancy[x][y][z],d.LiquidOccupancy[x][y][z]
            buffer.writeu16(blob,offset,math.round(s*65535));buffer.writeu16(blob,offset+2,math.round(w*65535));buffer.writeu16(blob,offset+4,d.SolidMaterial[x][y][z].Value);offset+=6
            if s>0 then solid+=1 end;if w>0 then water+=1 end
        end end end
        table.insert(out,{id=region.id,bounds=b,digest=buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(blob,Enum.HashAlgorithm.Sha256))),solidVoxels=solid,waterVoxels=water})
    end
    return out
end
local function lightingState()
    local l=game:GetService("Lighting")
    return {brightness=l.Brightness,clockTime=l.ClockTime,exposure=l.ExposureCompensation,ambient=rgb(l.Ambient),outdoorAmbient=rgb(l.OutdoorAmbient),diffuse=l.EnvironmentDiffuseScale,specular=l.EnvironmentSpecularScale,style=l.LightingStyle.Name,globalShadows=l.GlobalShadows}
end
local function inventory()
    local rows={}
    local total=0
    for _,name in cfg.services do
        local root=game:GetService(name)
        local all=root:GetDescendants()
        total+=#all
        assert(total<=cfg.maxObjects,"Inventory limit exceeded; no partial baseline")
        for _,obj in all do table.insert(rows,record(root,obj)) end
    end
    return {schemaVersion=1,universeId=tostring(game.GameId),placeId=tostring(game.PlaceId),objects=rows,terrain=terrainState(),lighting=lightingState(),total=total,services=cfg.services}
end
-- __RS_SYNC_DISPATCH__
return Http:JSONEncode(inventory())
