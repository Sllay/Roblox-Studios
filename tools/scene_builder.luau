
-- Uses the checked-in Safe Import v2 audit/serialization helpers and placement solver.
-- __RS_SHARED__
local plan=cfg.plan
local b=plan.bounds
local terrain=Workspace.Terrain
local region=Region3.new(Vector3.new(b[1],b[2],b[3]),Vector3.new(b[4],b[5],b[6]))
local nx,ny,nz=(b[4]-b[1])/4,(b[5]-b[2])/4,(b[6]-b[3])/4
local data=terrain:ReadVoxelChannels(region,4,{"SolidMaterial","SolidOccupancy","LiquidOccupancy"})
local bytes=buffer.create(nx*ny*nz*6)
local at=0
local grid={}
local counts={grass=0,water=0,other=0}
for x=1,nx do
    grid[x]={}
    for z=1,nz do grid[x][z]={material="Air",wet=false,height=b[2]} end
    for y=1,ny do for z=1,nz do
        local s,w=data.SolidOccupancy[x][y][z],data.LiquidOccupancy[x][y][z]
        local mat=data.SolidMaterial[x][y][z]
        buffer.writeu16(bytes,at,math.round(s*65535));buffer.writeu16(bytes,at+2,math.round(w*65535));buffer.writeu16(bytes,at+4,mat.Value);at+=6
        local c=grid[x][z]
        if w>0.02 then c.wet=true end
        if s>0.02 then c.material=mat.Name;c.height=b[2]+(y-1+s)*4 end
    end end
end
local terrainDigest=buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(bytes,Enum.HashAlgorithm.Sha256)))
assert(terrainDigest==plan.terrainDigest,"Terrain baseline changed")
for x=1,nx do for z=1,nz do
    local c=grid[x][z]
    if c.wet then counts.water+=1 elseif c.material=="Grass" then counts.grass+=1 else counts.other+=1 end
end end
local function equivalent(a,b)
    if typeof(a)~=typeof(b) then return false end
    if typeof(a)=="number" then return math.abs(a-b)<0.035 end
    if typeof(a)~="table" then return a==b end
    for k,v in a do if not equivalent(v,b[k]) then return false end end
    for k in b do if a[k]==nil then return false end end
    return true
end
local function clearGround(x,z,r)
    if x-r<b[1]+4 or x+r>b[4]-4 or z-r<b[3]+4 or z+r>b[6]-4 then return false end
    local ix,iz=math.floor((x-b[1])/4)+1,math.floor((z-b[3])/4)+1
    local cells=math.ceil(r/4)+1
    for i=math.max(1,ix-cells),math.min(nx,ix+cells) do
        for j=math.max(1,iz-cells),math.min(nz,iz+cells) do
            local cx,cz=b[1]+(i-0.5)*4,b[3]+(j-0.5)*4
            if (cx-x)^2+(cz-z)^2<=(r+2.83)^2 then
                local c=grid[i][j]
                if c.wet or c.material~="Grass" then return false end
            end
        end
    end
    return true
end
local function scaledProfile(spec,scale)
    local p=table.clone(spec.profile)
    p.buryDepthStuds*=scale
    p.supportRadiusStuds*=scale
    p.groundNames={"Terrain"}
    p.maxHeightDeltaStuds=2
    return p
end
-- The edit-time cloud session does not expose collision raycasts on this
-- native Terrain. Use the actual persisted occupancy field, not a guessed
-- height or the historical generation plan. The live server verifies it.
local function heightAt(x,z)
    local gx=(x-b[1])/4+0.5
    local gz=(z-b[3])/4+0.5
    local i,j=math.floor(gx),math.floor(gz)
    assert(i>=1 and i<nx and j>=1 and j<nz,"Outside terrain interpolation domain")
    local tx,tz=gx-i,gz-j
    local a,c,d,f=grid[i][j],grid[i+1][j],grid[i][j+1],grid[i+1][j+1]
    for _,v in {a,c,d,f} do assert(v.material=="Grass" and not v.wet,"Non-grass support") end
    local y0=a.height+(c.height-a.height)*tx
    local y1=d.height+(f.height-d.height)*tx
    return y0+(y1-y0)*tz
end
local function solveVoxel(model,x,z,yaw,profile)
    local radius=profile.supportRadiusStuds
    local heights={}
    for _,off in {{0,0},{radius,0},{-radius,0},{0,radius},{0,-radius}} do
        table.insert(heights,heightAt(x+off[1],z+off[2]))
    end
    local slope=math.deg(math.atan(math.sqrt(((heights[2]-heights[3])/(2*radius))^2+((heights[4]-heights[5])/(2*radius))^2)))
    assert(slope<=profile.maxSlopeDegrees,"Voxel slope exceeds profile")
    assert(math.max(table.unpack(heights))-math.min(table.unpack(heights))<=profile.maxHeightDeltaStuds,"Voxel support uneven")
    local old=model:GetPivot()
    model:PivotTo(CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(yaw),0))
    local bb,size=model:GetBoundingBox()
    local bottom=bb.Position.Y-size.Y/2
    model:PivotTo(old)
    assert(profile.buryDepthStuds<size.Y*0.5,"Burial exceeds half model height")
    return {position={x,heights[1]-bottom-profile.buryDepthStuds,z},groundY=heights[1],
        buriedDepth=profile.buryDepthStuds,bottomOffset=bottom,slope=slope,supportHeights=heights,method="native_voxel_surface_estimate"}
end
local function normalized(model,scale)
    local a=audit(model)
    for _,row in a.rows do if row.class=="MeshPart" then
        for i=1,3 do row.relative[i]/=scale;row.size[i]/=scale end
    end end
    -- Bounding boxes can be axis-aligned differently after yaw. Relative
    -- geometry and each mesh size are the invariant, not the world AABB.
    a.bounds=nil
    return a
end
local function sourceAudit(a)
    local copy=table.clone(a);copy.bounds=nil;return copy
end
local function sanitize(model)
    for _,obj in model:GetDescendants() do
        for name in obj:GetAttributes() do obj:SetAttribute(name,nil) end
        for _,tag in Tags:GetTags(obj) do Tags:RemoveTag(obj,tag) end
        if obj:IsA("BasePart") then obj.Anchored=true;obj.CanCollide=false;obj.CanTouch=false;obj.CanQuery=false end
    end
    for name in model:GetAttributes() do model:SetAttribute(name,nil) end
    for _,tag in Tags:GetTags(model) do Tags:RemoveTag(model,tag) end
end
local function sourceModels()
    local root=Assets:LoadAssetAsync(tonumber(plan.assetId))
    assert(root:IsA("Model") and root.Parent==nil,"Pack not detached")
    local sources,reports={},{}
    for _,spec in plan.species do
        local cursor: Instance=root
        for _,s in spec.selector do
            local child=cursor:GetChildren()[s.index]
            assert(child and child.Name==s.name and child.ClassName==s.class,"Selector changed")
            cursor=child
        end
        assert(cursor:IsA("Model"),"Expected individual model")
        local m=cursor:Clone()
        assert(m and m.Parent==nil and #m:GetDescendants()==#cursor:GetDescendants(),"Incomplete clone")
        local a=audit(m)
        assert(a.parts==2 and a.surfaces==2 and a.instances==4,"Pilot model complexity changed")
        local fetched=fetchDependencies(m,a)
        local blob,digest=serialize(m)
        if spec.digest then assert(spec.digest==digest,"Known source digest changed") end
        sources[spec.name]=m
        reports[spec.name]={audit=a,dependencyFetch=fetched,digest=digest,selector=spec.selector}
        if cfg.mode=="preview" then reports[spec.name].serializedBase64=buffer.tostring(Encoding:Base64Encode(blob)) end
    end
    root:Destroy()
    return sources,reports
end
local specs={}
for _,s in plan.species do specs[s.name]=s end
local function rootFolder()
    local root=Workspace:FindFirstChild("RSSceneBuilder")
    if root then assert(root:IsA("Folder") and root:GetAttribute("RSOwner")=="RSSceneBuilderV1","Root collision") end
    return root
end
local function positionCheck(row,model)
    local spec=specs[row.species]
    local p=scaledProfile(spec,row.scale)
    local clone=model:Clone()
    assert(clone,"Clone failed")
    clone:ScaleTo(row.scale)
    local solved=solveVoxel(clone,row.position[1],row.position[3],row.yaw,p)
    clone:Destroy()
    assert(equivalent(solved.position,row.position),"Ground changed")
    assert(clearGround(row.position[1],row.position[3],row.clearance),"Ground mask changed")
    return solved
end
local function separation(rows)
    for i,a in rows do for j=1,i-1 do
        local c=rows[j]
        local min=math.max(plan.minSpacing,(a.radius+c.radius)*plan.canopySpacing)
        assert((a.position[1]-c.position[1])^2+(a.position[3]-c.position[3])^2>=min^2-0.01,"Spacing violation")
    end end
end
local function collider(row,folder)
    local spec=specs[row.species]
    if not spec.collision then return end
    local part=Instance.new("Part")
    part.Name=row.id
    part.Shape=Enum.PartType.Cylinder
    local radius=spec.collision.radius*row.scale
    local height=spec.collision.height*row.scale
    part.Size=Vector3.new(height,radius*2,radius*2)
    part.CFrame=CFrame.new(row.position[1],row.groundY+height/2,row.position[3])*CFrame.Angles(0,0,math.pi/2)
    part.Transparency=1;part.Anchored=true;part.CanCollide=true;part.CanTouch=false;part.CanQuery=true
    part.CastShadow=false
    part:SetAttribute("RSOwner","RSSceneBuilderV1")
    part.Parent=folder
end
if cfg.mode=="verify" then
    local root=rootFolder()
    assert(root and root:GetAttribute("RSPlanDigest")==cfg.planDigest,"Scene missing or wrong plan")
    local models=root:FindFirstChild("Models")
    local collisions=root:FindFirstChild("Collisions")
    assert(models and collisions and #models:GetChildren()==#cfg.rows,"Scene count mismatch")
    local liveCheck=root:FindFirstChild("RuntimeGroundCheck")
    assert(liveCheck and liveCheck:IsA("Script") and liveCheck.Source==cfg.runtimeSource and liveCheck:GetAttribute("RSOwner")=="RSSceneBuilderV1","Runtime check missing")
    local expectedColliders=0
    local samples={}
    for _,row in cfg.rows do
        local spec=specs[row.species]
        local m=models:FindFirstChild(row.id)
        assert(m and m:IsA("Model") and m:GetAttribute("RSManagedId")==row.id and m:GetAttribute("RSModelDigest")==cfg.sources[row.species].digest,"Model provenance mismatch")
        assert(math.abs(m:GetScale()-row.scale)<0.001,"Scale mismatch")
        local cf=CFrame.new(table.unpack(row.position))*CFrame.Angles(0,math.rad(row.yaw),0)
        assert(equivalent({m:GetPivot():GetComponents()},{cf:GetComponents()}),"Pivot mismatch")
        assert(equivalent(normalized(m,row.scale),sourceAudit(cfg.sources[row.species].audit)),"Visual/geometry audit changed")
        for _,obj in m:GetDescendants() do if obj:IsA("BasePart") then
            assert(obj.Anchored and not obj.CanCollide and not obj.CanTouch and not obj.CanQuery,"Visual physics mismatch")
        end end
        local check=m:Clone()
        local solved=solveVoxel(check,row.position[1],row.position[3],row.yaw,scaledProfile(spec,row.scale))
        check:Destroy()
        assert(equivalent(solved.position,row.position) and clearGround(row.position[1],row.position[3],row.clearance),"Persisted placement mismatch")
        if not samples[row.species] then
            local blob,digest=serialize(m)
            samples[row.species]={persistedDigest=digest,serializedBase64=buffer.tostring(Encoding:Base64Encode(blob))}
        end
        if spec.collision then
            expectedColliders+=1
            local c=collisions:FindFirstChild(row.id)
            local radius,height=spec.collision.radius*row.scale,spec.collision.height*row.scale
            assert(c and c:IsA("Part") and c.Shape==Enum.PartType.Cylinder and c.Anchored and c.CanCollide and c.Transparency==1 and not c.CanTouch and c.CanQuery and not c.CastShadow,"Collider mismatch")
            assert(equivalent(vector(c.Size),{height,radius*2,radius*2}) and equivalent(vector(c.Position),{row.position[1],row.groundY+height/2,row.position[3]}),"Collider geometry mismatch")
        end
    end
    assert(#collisions:GetChildren()==expectedColliders,"Collider count mismatch")
    separation(cfg.rows)
    return output({verified=true,terrainDigest=terrainDigest,models=#cfg.rows,colliders=expectedColliders,planDigest=cfg.planDigest,serializedSamples=samples})
end
assert(game.PlaceVersion==cfg.expectedVersion and not rootFolder(),"Scene version changed or already exists")
local sources,reports=sourceModels()
if cfg.mode=="preview" then
    local rng=Random.new(plan.seed)
    local cells={}
    for x=1,nx do for z=1,nz do if grid[x][z].material=="Grass" and not grid[x][z].wet then table.insert(cells,{x,z}) end end end
    for i=#cells,2,-1 do local j=rng:NextInteger(1,i);cells[i],cells[j]=cells[j],cells[i] end
    local rows,stats={},{}
    -- Largest vegetation first, then undergrowth. Seeded shuffle + noise density + hard spacing.
    for _,spec in plan.species do
        local n=0
        local rejected={mask=0,spacing=0,slope=0,density=0}
        local failureReasons={}
        local failureSamples={}
        for _,cell in cells do
            if n>=spec.count then break end
            local x,z=b[1]+(cell[1]-0.5)*4,b[3]+(cell[2]-0.5)*4
            local scale=math.round(rng:NextNumber(spec.scale[1],spec.scale[2])*100)/100
            local yaw=rng:NextInteger(0,359)
            local a=reports[spec.name].audit.bounds
            local radius=math.max(a[1],a[3])*scale/2
            local clearance=math.max(spec.clearance,radius*0.55)
            local density=math.clamp(0.65+math.noise(x/55,z/55,plan.seed*0.01),0.15,1)
            if rng:NextNumber()>density then rejected.density+=1;continue end
            if not clearGround(x,z,clearance) then rejected.mask+=1;continue end
            local spaced=true
            for _,prev in rows do
                local d=math.max(plan.minSpacing,(radius+prev.radius)*plan.canopySpacing)
                if (x-prev.position[1])^2+(z-prev.position[3])^2<d*d then spaced=false;break end
            end
            if not spaced then rejected.spacing+=1;continue end
            local clone=sources[spec.name]:Clone()
            clone:ScaleTo(scale)
            local ok,solved=pcall(solveVoxel,clone,x,z,yaw,scaledProfile(spec,scale))
            clone:Destroy()
            if not ok then
                rejected.slope+=1
                local reason=tostring(solved)
                failureReasons[reason]=(failureReasons[reason] or 0)+1
                if #failureSamples<5 then table.insert(failureSamples,{x=x,z=z,reason=reason}) end
                continue
            end
            n+=1
            table.insert(rows,{id=string.format("forest-%s-%02d",string.lower(spec.name),n),species=spec.name,position=solved.position,groundY=solved.groundY,yaw=yaw,scale=scale,radius=radius,clearance=clearance,buriedDepth=solved.buriedDepth,supportMethod=solved.method,slope=solved.slope,bottomOffset=solved.bottomOffset})
        end
        stats[spec.name]={placed=n,rejected=rejected,failureReasons=failureReasons,failureSamples=failureSamples,minimum=spec.minCount}
    end
    separation(rows)
    for _,m in sources do m:Destroy() end
    return output({rows=rows,sources=reports,stats=stats,terrainDigest=terrainDigest,grid=grid,counts=counts})
end
assert(cfg.mode=="apply" and cfg.environment=="staging","Wrong mode")
assert(#cfg.rows<=plan.maxModels and #cfg.rows>0,"Model budget")
for name,report in reports do assert(report.digest==cfg.sources[name].digest and equivalent(report.audit,cfg.sources[name].audit),"Source audit changed") end
separation(cfg.rows)
local root=Instance.new("Folder");root.Name="RSSceneBuilder";root:SetAttribute("RSOwner","RSSceneBuilderV1");root:SetAttribute("RSPlanDigest",cfg.planDigest)
local models=Instance.new("Folder");models.Name="Models";models.Parent=root
local collisions=Instance.new("Folder");collisions.Name="Collisions";collisions.Parent=root
local seen={}
for _,row in cfg.rows do
    assert(not seen[row.id],"Duplicate managed ID");seen[row.id]=true
    local spec=specs[row.species]
    local source=sources[row.species]
    positionCheck(row,source)
    local m=source:Clone();sanitize(m);m:ScaleTo(row.scale)
    m:PivotTo(CFrame.new(table.unpack(row.position))*CFrame.Angles(0,math.rad(row.yaw),0))
    assert(equivalent(normalized(m,row.scale),sourceAudit(reports[row.species].audit)),"Scaled model changed appearance")
    m.Name=row.id;m:SetAttribute("RSManagedId",row.id);m:SetAttribute("RSAssetId",plan.assetId)
    m:SetAttribute("RSModelDigest",reports[row.species].digest);m:SetAttribute("Biome",spec.biome)
    m:SetAttribute("RSSelector",Http:JSONEncode(spec.selector));m:SetAttribute("RSExpectedGroundY",row.groundY);m:SetAttribute("RSBuriedDepth",row.buriedDepth);m:SetAttribute("RSSupportRadius",spec.profile.supportRadiusStuds*row.scale);m.Parent=models
    collider(row,collisions)
end
for _,m in sources do m:Destroy() end
local runtime=Instance.new("Script")
runtime.Name="RuntimeGroundCheck";runtime:SetAttribute("RSOwner","RSSceneBuilderV1");runtime.Source=cfg.runtimeSource;runtime.Parent=root
root.Parent=Workspace
Assets:SavePlaceAsync({SaveWithoutPublish=false})
return output({saved=true,models=#cfg.rows,colliders=#collisions:GetChildren(),terrainDigest=terrainDigest,planDigest=cfg.planDigest})
