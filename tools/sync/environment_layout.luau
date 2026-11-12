-- Read-only preview, or explicit staging apply of an exact reviewed layout.
-- __RS_ASSET_HELPERS__
-- __RS_SURFACE_FIELDS__
local W=workspace
local T=W.Terrain
local plan=cfg.plan
assert(cfg.environment=="staging" and game.PlaceVersion==cfg.expectedVersion,"Stale environment plan")
local rootName=plan.rootName or "RSEnvironmentP4"
assert(rootName=="RSEnvironmentP4" or rootName=="RSEnvironmentP4Detail","Managed root not allowed")
local owner=rootName.."V1"
local idPrefix=if rootName=="RSEnvironmentP4Detail" then "p4-detail" else "p4"
local persistedRoot=W:FindFirstChild(rootName)
assert((cfg.mode=="verify" and persistedRoot) or (cfg.mode~="verify" and not persistedRoot),"Environment identity changed")
local tiles={}
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
for _,region in cfg.regions do
    local expected=cfg.terrainExpected[region.id]
    if not expected then continue end
    local b=region.bounds
    local nx,ny,nz=(b[4]-b[1])/4,(b[5]-b[2])/4,(b[6]-b[3])/4
    local d=T:ReadVoxelChannels(Region3.new(Vector3.new(b[1],b[2],b[3]),Vector3.new(b[4],b[5],b[6])),4,channels)
    local bytes=buffer.create(nx*ny*nz*6)
    local at=0;local grid={}
    for x=1,nx do
        grid[x]={}
        for z=1,nz do grid[x][z]={h=b[2],grass=false,wet=false} end
        for y=1,ny do for z=1,nz do
            local s,w=d.SolidOccupancy[x][y][z],d.LiquidOccupancy[x][y][z]
            local m=d.SolidMaterial[x][y][z]
            buffer.writeu16(bytes,at,math.round(s*65535));buffer.writeu16(bytes,at+2,math.round(w*65535))
            buffer.writeu16(bytes,at+4,m.Value);at+=6
            local c=grid[x][z]
            if w>0.02 then c.wet=true end
            if s>0.02 then c.h=b[2]+(y-1+s)*4;c.grass=m==Enum.Material.Grass end
        end end
    end
    local digest=buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(bytes,Enum.HashAlgorithm.Sha256)))
    assert(digest==expected,"Terrain changed: "..region.id)
    table.insert(tiles,{id=region.id,b=b,nx=nx,nz=nz,grid=grid})
end
table.sort(tiles,function(a,b) return a.id<b.id end)
assert(#tiles==#plan.placement.regionIds,"Missing terrain tiles")
local height=Surface.height
local dry=Surface.dry
local occupied={}
local function modelRadius(m)
    local bb,size=m:GetBoundingBox()
    local p=m:GetPivot().Position
    local offset=Vector3.new(bb.Position.X-p.X,0,bb.Position.Z-p.Z).Magnitude
    return offset+math.sqrt(size.X^2+size.Z^2)/2
end
for _,existingName in {"RSSceneBuilder","RSWorldVegetation","RSManagedAssets","RSEnvironmentP4","RSEnvironmentP4Detail"} do
    if existingName==rootName then continue end
    local root=W:FindFirstChild(existingName)
    local models=root and (if existingName=="RSManagedAssets" then root else root:FindFirstChild("Models"))
    if models then for _,m in models:GetChildren() do
        if m:IsA("Model") then
            local p=m:GetPivot().Position
            table.insert(occupied,{x=p.X,z=p.Z,r=modelRadius(m)})
        end
    end end
end
local existingCount=#occupied
for _,obj in W:GetDescendants() do
    if obj:IsA("SpawnLocation") then
        table.insert(occupied,{x=obj.Position.X,z=obj.Position.Z,r=8})
    end
end
local function spaced(x,z,r)
    for _,o in occupied do
        if (x-o.x)^2+(z-o.z)^2<(r+o.r+2)^2 then return false end
    end
    return true
end
local sources,packRoots={},{}
for _,spec in plan.assets do
    local root=packRoots[spec.assetId]
    if not root then
        root=Assets:LoadAssetAsync(tonumber(spec.assetId))
        assert(root:IsA("Model") and root.Parent==nil,"Detached pack required")
        packRoots[spec.assetId]=root
    end
    local cursor=root
    for _,seg in spec.selector do
        local nextObj=cursor:GetChildren()[seg.index]
        assert(nextObj and nextObj.Name==seg.name and nextObj.ClassName==seg.class,"Source selector changed")
        cursor=nextObj
    end
    assert(cursor:IsA("Model"),"Source model required")
    local model=cursor:Clone()
    assert(model and model.Parent==nil and #model:GetDescendants()==#cursor:GetDescendants(),"Incomplete clone")
    local a=audit(model)
    local _,digest=serialize(model)
    assert(digest==spec.sourceDigest,"Source digest changed: "..spec.name)
    local fetched=fetchDependencies(model,a)
    local sourceScale=model:GetScale()
    if rootName=="RSEnvironmentP4Detail" then
        -- Imported DCC pivots may be tens of studs away from the mesh.
        -- Recenter the model pivot without moving its components, then audit
        -- the canonical relative geometry; never alter mesh or PBR properties.
        local bb=model:GetBoundingBox()
        model.PrimaryPart=nil
        model.WorldPivot=CFrame.new(bb.Position)
        a=audit(model)
    end
    model:PivotTo(CFrame.new())
    local bb,size=model:GetBoundingBox()
    sources[spec.name]={model=model,digest=digest,radius=modelRadius(model),bottom=bb.Position.Y-size.Y/2,height=size.Y,sourceScale=sourceScale,audit=a,dependencyFetch=fetched}
end
for _,root in packRoots do root:Destroy() end
local rows,stats={},{}
local rng=Random.new(plan.seed)
for _,spec in plan.assets do
    local n=0
    local rejected={mask=0,spacing=0,slope=0}
    local source=sources[spec.name]
    local p=spec.profile
    for _=1,2500 do
        if n>=spec.count then break end
        local tile=tiles[rng:NextInteger(1,#tiles)]
        local b=tile.b
        local x,z=rng:NextNumber(b[1]+20,b[4]-20),rng:NextNumber(b[3]+20,b[6]-20)
        x,z=math.round(x*10)/10,math.round(z*10)/10
        local scale=math.round(rng:NextNumber(p.scale[1],p.scale[2])*1000)/1000
        local yaw=rng:NextInteger(0,359)
        local radius=source.radius*scale
        local clearance=math.max(3,radius*0.6)
        if x*x+z*z<45^2 or not dry(tile,x,z,clearance) then rejected.mask+=1;continue end
        if not spaced(x,z,radius) then rejected.spacing+=1;continue end
        local support=p.support*scale
        local h,slope,relief=Surface.support(tile,x,z,support)
        if not h or not slope or not relief or slope>15 or relief>1.5 then rejected.slope+=1;continue end
        local burial=p.burial*scale
        assert(burial<source.height*scale*0.45,"Invalid contact profile")
        n+=1
        local row={id=string.format("%s-%s-%02d",idPrefix,string.lower(spec.name):gsub("[^a-z0-9]","-"),n),
            name=spec.name,assetId=spec.assetId,sourceDigest=spec.sourceDigest,position={x,h-source.bottom*scale-burial,z},
            groundY=h,yaw=yaw,scale=scale,radius=radius,buriedDepth=burial,supportRadius=support,slope=slope,tile=tile.id}
        table.insert(rows,row);table.insert(occupied,{x=x,z=z,r=radius})
    end
    stats[spec.name]={placed=n,requested=spec.count,rejected=rejected}
end
assert(#rows>0 and #rows<=plan.maxNewModels,"Layout budget")
local function output(r)
    r.universeId=tostring(game.GameId);r.placeId=tostring(game.PlaceId)
    return Http:JSONEncode(r)
end
if cfg.mode=="preview" then
    for _,s in sources do s.model:Destroy() end
    return output({preview=true,rows=rows,stats=stats,existingCount=existingCount,noPlaceWrites=true})
end
local function same(a,b,tolerance)
    tolerance=tolerance or 0.0001
    if typeof(a)~=typeof(b) then return false end
    if typeof(a)=="number" then return math.abs(a-b)<tolerance end
    if typeof(a)~="table" then return a==b end
    for k,v in a do if not same(v,b[k],tolerance) then return false end end
    for k in b do if a[k]==nil then return false end end
    return true
end
assert(same(rows,cfg.layoutRows) and #rows==plan.maxNewModels,"Layout changed or incomplete")
local specs={}
for _,s in plan.assets do specs[s.name]=s end
local function checkVisual(m,row)
    local source=sources[row.name]
    assert(math.abs(m:GetScale()-source.sourceScale*row.scale)<0.001,"Model scale mismatch")
    local actual=audit(m)
    local expected=table.clone(source.audit)
    actual.bounds=nil;expected.bounds=nil
    for _,r in actual.rows do
        if r.class=="MeshPart" then
            for i=1,3 do r.relative[i]/=row.scale;r.size[i]/=row.scale end
        end
    end
    assert(same(actual,expected,0.035),"Geometry/PBR audit mismatch: "..row.id)
    for _,obj in m:GetDescendants() do
        if obj:IsA("BasePart") then
            assert(obj.Anchored and not obj.CanCollide and not obj.CanTouch and not obj.CanQuery,"Visual physics changed")
        end
    end
end
if cfg.mode=="verify" then
    local root=persistedRoot
    assert(root:IsA("Folder") and root:GetAttribute("RSOwner")==owner and root:GetAttribute("RSPlanDigest")==cfg.planDigest,"Root provenance")
    local models=root:FindFirstChild("Models");local colliders=root:FindFirstChild("Collisions")
    local runtime=root:FindFirstChild("RuntimeGroundCheck")
    assert(models and colliders and #models:GetChildren()==#rows and runtime and runtime:IsA("Script") and runtime.Source==cfg.runtimeSource,"Persisted structure")
    local samples={};local colliderCount=0
    for _,row in rows do
        local m=models:FindFirstChild(row.id)
        assert(m and m:IsA("Model") and m:GetAttribute("RSManagedId")==row.id and m:GetAttribute("RSModelDigest")==row.sourceDigest and m:GetAttribute("RSAssetId")==row.assetId,"Model provenance")
        local cf=CFrame.new(table.unpack(row.position))*CFrame.Angles(0,math.rad(row.yaw),0)
        assert(same({m:GetPivot():GetComponents()},{cf:GetComponents()},0.035),"Persisted pivot")
        checkVisual(m,row)
        local c=specs[row.name].profile.collider
        if c then
            colliderCount+=1
            local part=colliders:FindFirstChild(row.id)
            local h,r=c.height*row.scale,c.radius*row.scale
            local expected=CFrame.new(row.position[1],row.groundY+h/2,row.position[3])*CFrame.Angles(0,0,math.pi/2)
            assert(part and part:IsA("Part") and part.Shape==Enum.PartType.Cylinder and part.Anchored and part.CanCollide and not part.CanTouch and part.CanQuery and part.Transparency==1 and not part.CastShadow,"Collider physics")
            assert(same(vector(part.Size),{h,2*r,2*r},0.035) and same({part.CFrame:GetComponents()},{expected:GetComponents()},0.035),"Collider transform")
        end
        if not samples[row.name] then
            local blob,digest=serialize(m)
            samples[row.name]={persistedDigest=digest,serializedBase64=buffer.tostring(Encoding:Base64Encode(blob)),audit=audit(m),dependencyFetch=sources[row.name].dependencyFetch}
        end
    end
    assert(#colliders:GetChildren()==colliderCount,"Collider count")
    for _,source in sources do source.model:Destroy() end
    return output({verified=true,models=#rows,colliders=colliderCount,samples=samples})
end
assert(cfg.mode=="apply" and cfg.confirmStaging==true,"Explicit staging confirmation required")
local root=Instance.new("Folder");root.Name=rootName;root:SetAttribute("RSOwner",owner)
root:SetAttribute("RSPlanDigest",cfg.planDigest)
local models=Instance.new("Folder");models.Name="Models";models.Parent=root
local collisions=Instance.new("Folder");collisions.Name="Collisions";collisions.Parent=root
local tags=game:GetService("CollectionService")
for _,row in rows do
    local spec=specs[row.name]
    local m=sources[row.name].model:Clone()
    for _,obj in {m,table.unpack(m:GetDescendants())} do
        for k in obj:GetAttributes() do obj:SetAttribute(k,nil) end
        for _,tag in tags:GetTags(obj) do tags:RemoveTag(obj,tag) end
        if obj:IsA("BasePart") then obj.Anchored=true;obj.CanCollide=false;obj.CanTouch=false;obj.CanQuery=false end
    end
    m:ScaleTo(sources[row.name].sourceScale*row.scale)
    m:PivotTo(CFrame.new(table.unpack(row.position))*CFrame.Angles(0,math.rad(row.yaw),0))
    checkVisual(m,row)
    m.Name=row.id;m:SetAttribute("RSManagedId",row.id);m:SetAttribute("RSAssetId",row.assetId)
    m:SetAttribute("RSModelDigest",row.sourceDigest);m:SetAttribute("RSSpecies",row.name)
    m:SetAttribute("RSExpectedGroundY",row.groundY);m:SetAttribute("RSBuriedDepth",row.buriedDepth)
    m:SetAttribute("RSSupportRadius",row.supportRadius);m.Parent=models
    local c=spec.profile.collider
    if c then
        local part=Instance.new("Part");part.Name=row.id;part.Shape=Enum.PartType.Cylinder
        local h,r=c.height*row.scale,c.radius*row.scale
        part.Size=Vector3.new(h,2*r,2*r)
        part.CFrame=CFrame.new(row.position[1],row.groundY+h/2,row.position[3])*CFrame.Angles(0,0,math.pi/2)
        part.Transparency=1;part.Anchored=true;part.CanCollide=true;part.CanTouch=false;part.CanQuery=true;part.CastShadow=false
        part:SetAttribute("RSOwner",owner);part.Parent=collisions
    end
end
for _,s in sources do s.model:Destroy() end
local runtime=Instance.new("Script");runtime.Name="RuntimeGroundCheck";runtime.Source=cfg.runtimeSource;runtime.Parent=root
root.Parent=W
Assets:SavePlaceAsync({SaveWithoutPublish=false})
return output({saved=true,models=#rows,colliders=#collisions:GetChildren(),planDigest=cfg.planDigest})
