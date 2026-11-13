-- Disposable integrated S07 migration preview. No save operation exists here.
local W=workspace
local T=W.Terrain
local F=W.RSResourcesP45.Models
local V=W.RSVegetationS06
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local function write(region,d)
    T:WriteVoxelChannels(region,4,{SolidMaterial=d.SolidMaterial,SolidOccupancy=d.SolidOccupancy,LiquidOccupancy=d.LiquidOccupancy})
end
assert(game.PlaceId==93428341652658 and #cfg.rows==2000,"Target/count")
local function fingerprint()
    local hashes={};local records={}
    for _,name in cfg.services do
        local svc=game:GetService(name)
        for _,o in svc:GetDescendants() do
            local row=record(svc,o)
            -- Record serialization is canonicalized recursively; no table iteration order dependency.
            local function canon(x)
                if typeof(x)~="table" then return Http:JSONEncode(x) end
                local keys={};for k in x do table.insert(keys,k) end
                table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
                local out={};for _,k in keys do table.insert(out,Http:JSONEncode(tostring(k))..":"..canon(x[k])) end
                return "{"..table.concat(out,",").."}"
            end
            local k=svc.Name..":"..canon(row.path)
            local digest=hash(canon(row));table.insert(hashes,digest);records[k]={digest=digest,row=row}
        end
    end
    table.sort(hashes);return hash(table.concat(hashes,";")),records
end
local function audit(records)
    local groups={}
    for _,entry in records do
        local row=entry.row
        local root=row.service..":"..row.path[1].name..":"..row.class
        local function add(field,value)
            local k=root..":"..field
            groups[k]=groups[k] or {}
            table.insert(groups[k],hash(Http:JSONEncode(value)))
        end
        add("identity",{row.path,row.managedId})
        add("attributes",row.attributesHash);add("tags",row.tagsHash)
        for k,v in row.properties do add(k,{row.path,v}) end
    end
    local out={}
    for k,v in groups do table.sort(v);out[k]=hash(table.concat(v,";")) end
    return out
end
local beforeFingerprint,beforeRecords=fingerprint()
if cfg.mode=="diagnose" then
    local counts={Branch=0,Stone=0,Other=0}
    for _,m in F:GetChildren() do local k=m:GetAttribute("RSResourceType");if k=="Stick" then counts.Branch+=1 elseif k=="Stone" then counts.Stone+=1 else counts.Other+=1 end end
    local terrain=terrainState();local mismatches={};for _,r in terrain do if cfg.expectedTerrain[r.id]~=r.digest then table.insert(mismatches,r.id) end end
    return syncResult({noPlaceWrites=true,afterFingerprint=beforeFingerprint,counts=counts,terrain=terrain,terrainMismatches=mismatches,objectCount=#F:GetChildren(),audit=if cfg.audit then audit(beforeRecords) else nil})
end
if cfg.mode=="verify" then
    assert(#F:GetChildren()==2000,"Persisted count")
    assert(beforeFingerprint==cfg.expectedAfter,"Persisted fingerprint")
    local terrain=terrainState();for _,r in terrain do assert(cfg.expectedTerrain[r.id]==r.digest,"Persisted terrain") end
    return syncResult({verified=true,noPlaceWrites=true,afterFingerprint=beforeFingerprint,terrain=terrain})
end
assert(#F:GetChildren()==216,"Baseline count")
if cfg.mode=="apply" then assert(beforeFingerprint==cfg.expectedBefore,"Reviewed baseline") end
local before=terrainState()
for _,r in before do assert(cfg.terrainExpected[r.id]==r.digest,"Terrain baseline") end
local templates={}
for _,id in cfg.sources do
    local m=F:FindFirstChild(id);assert(m and m:IsA("Model"),"Source")
    templates[id]=m:Clone()
end
local old=F:GetChildren()
for _,m in old do m.Parent=nil end
local created={}
local counts={Branch=0,Stone=0}
for _,a in cfg.rows do
    local r={id=a[1],kind=a[2],tile=a[3],source=a[4],size=a[5],frame=a[6],groundY=a[7],radius=a[8]}
    local m=templates[r.source]:Clone()
    local p=m:FindFirstChildWhichIsA("MeshPart",true)
    assert(p and #m:GetDescendants()==1,"Single mesh source")
    m.Name=r.id;m:SetAttribute("RSManagedId",r.id)
    p:SetAttribute("RSManagedId",nil)
    m:SetAttribute("RSResourceType",if r.kind=="Branch" then "Stick" else "Stone")
    m:SetAttribute("RSResourceState","decorative")
    m:SetAttribute("RSResourceChunk",r.tile)
    m:SetAttribute("RSExpectedGroundY",r.groundY)
    m:SetAttribute("RSBuriedDepth",0)
    m:SetAttribute("RSContactMethod","native_terrain_ray")
    m:SetAttribute("RSSupportRadius",r.radius)
    p.Size=Vector3.new(table.unpack(r.size))
    p.CFrame=CFrame.new(table.unpack(r.frame))
    p.Anchored=true;p.CanCollide=true;p.CanQuery=true;p.CanTouch=false;p.CollisionGroup="RSNaturalResource"
    m.Parent=F;created[#created+1]=m;counts[r.kind]+=1
end
assert(counts.Branch==1000 and counts.Stone==1000,"Population")
local paint={}
local changed=0
for _,c in cfg.columns do
    local region=Region3.new(Vector3.new(c.x,-32,c.z),Vector3.new(c.x+4,112,c.z+4))
    local original=T:ReadVoxelChannels(region,4,channels)
    local d=T:ReadVoxelChannels(region,4,channels)
    for y=1,36 do
        assert(math.abs(d.SolidOccupancy[1][y][1]-c.solid[y])<.000001 and math.abs(d.LiquidOccupancy[1][y][1]-c.liquid[y])<.000001,"Occupancy changed")
        local target=Enum.Material[c.material[y]]
        if d.SolidMaterial[1][y][1]~=target then
            assert(target==Enum.Material.Grass and d.SolidMaterial[1][y][1]==Enum.Material.Ground,"Unexpected material delta")
            d.SolidMaterial[1][y][1]=target;changed+=1
        end
    end
    write(region,d);paint[#paint+1]={region=region,original=original}
end
local originalVegetation=V
V=originalVegetation:Clone();assert(V,"Vegetation clone")
originalVegetation.Parent=nil;V.Parent=W
local rotated={}
for _,m in V.Models:GetChildren() do
    if m:IsA("Model") then
        local pivot=m:GetPivot()
        local seed=73007;for i=1,#m.Name do seed=(seed*131+string.byte(m.Name,i))%2147483647 end
        local yaw=Random.new(seed):NextNumber(0,360)
        local target=CFrame.new(pivot.Position)*CFrame.Angles(0,math.rad(yaw),0)*pivot.Rotation
        local delta=target*pivot:Inverse()
        local saved={m=m,pivot=pivot,colliders={}}
        for _,name in {m.Name,m.Name.."-cap"} do
            local p=V.Collisions:FindFirstChild(name)
            if p then saved.colliders[#saved.colliders+1]={p=p,cf=p.CFrame};p.CFrame=delta*p.CFrame end
        end
        m:PivotTo(target);rotated[#rotated+1]=saved
    end
end
local op=OverlapParams.new();op.FilterType=Enum.RaycastFilterType.Include;op.FilterDescendantsInstances={F,V.Collisions};op.MaxParts=0
for _,m in created do
    local p=m:FindFirstChildWhichIsA("MeshPart",true)
    for _,other in W:GetPartBoundsInBox(p.CFrame,p.Size,op) do assert(other==p,"Resource/collider overlap "..m.Name) end
end
local afterFingerprint,afterRecords=fingerprint()
local after=terrainState()
for i,r in after do assert(r.solidVoxels==before[i].solidVoxels and r.waterVoxels==before[i].waterVoxels,"Terrain volume") end
if cfg.mode=="apply" then
    assert(afterFingerprint==cfg.expectedAfter,"Reviewed after fingerprint")
    for _,r in after do assert(cfg.expectedTerrain[r.id]==r.digest,"Reviewed terrain") end
    assert(changed==864 and #rotated==212,"Reviewed counts")
    game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false})
    return syncResult({saved=true,afterFingerprint=afterFingerprint})
end
V:Destroy();originalVegetation.Parent=W
for _,m in created do m:Destroy() end
for _,m in old do m.Parent=F end
for _,m in templates do m:Destroy() end
for _,r in paint do write(r.region,r.original) end
local restored=terrainState()
for i,r in restored do assert(r.digest==before[i].digest,"Terrain inverse") end
local restoredFingerprint,restoredRecords=fingerprint()
if restoredFingerprint~=beforeFingerprint then
    local differences={}
    for k,a in beforeRecords do
        local b=restoredRecords[k]
        if not b or a.digest~=b.digest then
            local fields={};if b then for f,v in a.row do if Http:JSONEncode(v)~=Http:JSONEncode(b.row[f]) then table.insert(fields,f) end end end
            table.insert(differences,{path=k,fields=fields,before=a.row,after=b and b.row})
        end
    end
    return syncResult({preview=false,noPlaceWrites=true,inverseMismatch=true,differenceCount=#differences,differences={table.unpack(differences,1,math.min(5,#differences))}})
end
assert(#F:GetChildren()==216,"Resource inverse")
return syncResult({preview=true,noPlaceWrites=true,beforeFingerprint=beforeFingerprint,afterFingerprint=afterFingerprint,counts=counts,vegetationRotated=#rotated,restoredMaterialVoxels=changed,terrain=after,all49Restored=#restored==49,resourceInverse=true,clientRenderVerified=false,audit=if cfg.audit then audit(afterRecords) else nil})
