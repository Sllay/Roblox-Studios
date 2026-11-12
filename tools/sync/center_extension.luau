-- Inserted after inventory helpers. One bounded native Terrain extension.
-- Old objects are archived unchanged, not destroyed.
local W=workspace
local T=W.Terrain
local SS=game:GetService("ServerStorage")
local SSS=game:GetService("ServerScriptService")
local plan=cfg.plan
local b=plan.bounds
local region=Region3.new(Vector3.new(b[1],b[2],b[3]),Vector3.new(b[4],b[5],b[6]))
local nx,ny,nz=(b[4]-b[1])/4,(b[5]-b[2])/4,(b[6]-b[3])/4
local ch={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local oldRegion=Region3.new(Vector3.new(96,0,-128),Vector3.new(352,64,128))
local old=T:ReadVoxelChannels(oldRegion,4,ch)
local function digest(d,sx,sy,sz)
    local blob=buffer.create(sx*sy*sz*6)
    local at=0
    for x=1,sx do for y=1,sy do for z=1,sz do
        buffer.writeu16(blob,at,math.round(d.SolidOccupancy[x][y][z]*65535));buffer.writeu16(blob,at+2,math.round(d.LiquidOccupancy[x][y][z]*65535));buffer.writeu16(blob,at+4,d.SolidMaterial[x][y][z].Value);at+=6
    end end end
    return buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(blob,Enum.HashAlgorithm.Sha256)))
end
assert(digest(old,64,16,64)==plan.pilotDigest,"Approved forest terrain changed")
local edge={}
local edgeMat={}
for z=1,64 do
    local height=0
    local material=Enum.Material.Grass
    for y=1,16 do
        local o=old.SolidOccupancy[1][y][z]
        assert(old.LiquidOccupancy[1][y][z]==0,"Water at seam")
        if o>0.02 then height=(y-1+o)*4;material=old.SolidMaterial[1][y][z] end
    end
    edge[z]=height;edgeMat[z]=material
end
local function smooth(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function mix(a,c,t) return a+(c-a)*t end
local function distance(x,z,a,c)
    local dx,dz=c[1]-a[1],c[2]-a[2]
    local t=math.clamp(((x-a[1])*dx+(z-a[2])*dz)/(dx*dx+dz*dz),0,1)
    return math.sqrt((x-a[1]-dx*t)^2+(z-a[2]-dz*t)^2)
end
local function heightAt(x,z)
    local h=14+math.noise(x/100,z/100,plan.seed*0.01)*10+math.noise(x/34,z/34,plan.seed*0.02)*3
    local e=math.min(x-b[1],z-b[3],b[6]-z)
    h=mix(2,h,smooth(e/32))
    local center=math.sqrt(x*x+z*z)
    h=mix(14,h,smooth((center-32)/16))
    -- Keep the already approved Tree_01 exactly on its previous Y=0 ground.
    local treeDist=math.sqrt((x-40)^2+(z+18)^2)
    h=mix(0,h,smooth((treeDist-7)/9))
    local iz=math.clamp(math.floor((z+128)/4)+1,1,64)
    h=mix(edge[iz],h,smooth((96-x-2)/28))
    return h
end
local function generate()
    local d={SolidMaterial={},SolidOccupancy={},LiquidOccupancy={}}
    local solid=0
    for x=1,nx do
        for _,k in ch do d[k][x]={};for y=1,ny do d[k][x][y]={} end end
        for z=1,nz do
            local wx,wz=b[1]+(x-0.5)*4,b[3]+(z-0.5)*4
            local h=heightAt(wx,wz)
            local surface=Enum.Material.Grass
            if math.min(distance(wx,wz,{-12,-36},{36,-48}),distance(wx,wz,{36,-48},{96,-68}))<=6 then surface=Enum.Material.Ground end
            if x==nx then surface=edgeMat[z] end
            for y=1,ny do
                local bottom=b[2]+(y-1)*4
                local o=math.clamp((h-bottom)/4,0,1)
                d.SolidOccupancy[x][y][z]=o;d.LiquidOccupancy[x][y][z]=0
                d.SolidMaterial[x][y][z]=if o==0 then Enum.Material.Air elseif bottom+4>=h-8 then surface elseif bottom+4>=h-16 then Enum.Material.Ground else Enum.Material.Rock
                if o>0 then solid+=1 end
            end
            assert(d.SolidOccupancy[x][1][z]==1,"Foundation gap")
        end
    end
    return d,solid
end
local function same(a,c)
    if typeof(a)~=typeof(c) then return false end
    if typeof(a)=="number" then return math.abs(a-c)<0.0001 end
    if typeof(a)~="table" then return a==c end
    for k,v in a do if not same(v,c[k]) then return false end end
    for k in c do if a[k]==nil then return false end end
    return true
end
local function output(d) d.universeId=tostring(game.GameId);d.placeId=tostring(game.PlaceId);return Http:JSONEncode(d) end
local function findArchive()
    local a=SS:FindFirstChild("RSSceneSyncArchive")
    assert(a and a:IsA("Folder") and a:GetAttribute("RSOwner")=="RSSceneSyncV1","Archive missing")
    return a
end
local function verifyNew()
    local root=W:FindFirstChild("RSCentralSpawns")
    assert(root and root:IsA("Folder") and root:GetAttribute("RSOwner")=="RSSceneSyncV1","Spawn folder missing")
    local scriptObj=SSS:FindFirstChild("RSCentralSpawnSafety")
    assert(scriptObj and scriptObj:IsA("Script") and scriptObj.Source==cfg.runtimeSource and scriptObj:GetAttribute("RSOwner")=="RSSceneSyncV1","Spawn safety script mismatch")
    assert(not W:FindFirstChild("Baseplate") and not W:FindFirstChild("SpawnLocation"),"Old defaults still in Workspace")
    local archive=findArchive()
    for _,r in cfg.targets do
        local obj=archive:FindFirstChild(r.name)
        assert(obj and obj.ClassName==r.class,"Archived original missing")
        local actual=record(SS,obj)
        assert(same(actual.properties,r.properties) and actual.childCount==r.childCount and actual.attributesHash==r.attributesHash and actual.tagsHash==r.tagsHash,"Archived original changed")
    end
    assert(#root:GetChildren()==#plan.spawnPoints,"Spawn count")
    local points={}
    for i,p in plan.spawnPoints do
        local s=root:FindFirstChild(string.format("Central_%02d",i))
        assert(s and s:IsA("SpawnLocation") and s.Enabled and s.Neutral and s.Anchored and s.Transparency==1 and not s.CanCollide and s.Duration==0,"Spawn property mismatch")
        assert((s.Position-Vector3.new(p[1],16,p[2])).Magnitude<0.01,"Spawn position mismatch")
        table.insert(points,vec(s.Position))
    end
    local current=T:ReadVoxelChannels(region,4,ch)
    local d=digest(current,nx,ny,nz)
    assert(d==cfg.expectedDigest,"Extension terrain changed")
    assert(W:FindFirstChild("RSManagedAssets"):FindFirstChild("yasu-tree-01"):GetPivot().Position.Y<2.01,"Original tree moved")
    return {verified=true,terrainDigest=d,pilotDigest=plan.pilotDigest,spawns=points,archived=2}
end
if cfg.mode=="verify" then return output(verifyNew()) end
assert(cfg.environment=="staging" and game.PlaceVersion==cfg.expectedVersion,"Staging/version mismatch")
local current=T:ReadVoxelChannels(region,4,ch)
if cfg.mode=="rollback" then
    verifyNew()
    local archive=findArchive()
    local root=W:FindFirstChild("RSCentralSpawns")
    local sc=SSS:FindFirstChild("RSCentralSpawnSafety")
    -- Inverse only on exactly the reviewed extension; original region untouched.
    for x=1,nx do for y=1,ny do for z=1,nz do
        current.SolidOccupancy[x][y][z]=0;current.LiquidOccupancy[x][y][z]=0;current.SolidMaterial[x][y][z]=Enum.Material.Air
    end end end
    T:WriteVoxelChannels(region,4,current)
    root:Destroy();sc:Destroy()
    for _,r in cfg.targets do archive:FindFirstChild(r.name).Parent=W end
    archive:Destroy()
    game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false})
    return output({rolledBack=true,pilotDigest=plan.pilotDigest})
end
assert(cfg.mode=="preview" or cfg.mode=="apply","Unknown mode")
for x=1,nx do for y=1,ny do for z=1,nz do
    assert(current.SolidOccupancy[x][y][z]==0 and current.LiquidOccupancy[x][y][z]==0,"New region already occupied")
end end end
assert(not SS:FindFirstChild("RSSceneSyncArchive") and not W:FindFirstChild("RSCentralSpawns") and not SSS:FindFirstChild("RSCentralSpawnSafety"),"Managed name collision")
local targets={}
for _,r in cfg.targets do
    local obj=locate(r.service,r.path)
    assert(obj.Parent==W and same(record(W,obj),r),"External object changed")
    assert(obj:IsA("BasePart") and obj.Anchored,"Unexpected default")
    for _,desc in obj:GetDescendants() do assert(desc:IsA("Texture") or desc:IsA("Decal"),"Unexpected default descendant") end
    table.insert(targets,obj)
end
assert(#targets==2 and targets[1].Name=="Baseplate" and targets[2].Name=="SpawnLocation","Default object selection mismatch")
local tree=W:FindFirstChild("RSManagedAssets"):FindFirstChild("yasu-tree-01")
assert(tree and tree:IsA("Model") and (tree:GetPivot().Position-Vector3.new(40,1.99861145,-18)).Magnitude<0.02,"Original tree moved")
-- Protect every unrelated BasePart: only the known tree overlaps the extension.
for _,obj in W:GetDescendants() do
    if obj:IsA("BasePart") and not obj:IsA("Terrain") and obj~=targets[1] and obj~=targets[2] and not obj:IsDescendantOf(tree) then
        local half=obj.Size/2;local cf=obj.CFrame
        local ex=Vector3.new(math.abs(cf.RightVector.X)*half.X+math.abs(cf.UpVector.X)*half.Y+math.abs(cf.LookVector.X)*half.Z,math.abs(cf.RightVector.Y)*half.X+math.abs(cf.UpVector.Y)*half.Y+math.abs(cf.LookVector.Y)*half.Z,math.abs(cf.RightVector.Z)*half.X+math.abs(cf.UpVector.Z)*half.Y+math.abs(cf.LookVector.Z)*half.Z)
        local a,c=obj.Position-ex,obj.Position+ex
        assert(c.X<=b[1] or a.X>=b[4] or c.Y<=b[2] or a.Y>=b[5] or c.Z<=b[3] or a.Z>=b[6],"Unrelated object intersects new terrain: "..obj:GetFullName())
    end
end
local generated,solid=generate()
local seamError=0
for z=1,nz do
    seamError=math.max(seamError,math.abs(heightAt(94,b[3]+(z-0.5)*4)-edge[z]))
end
assert(seamError<0.01,"Seam height mismatch")
for _,p in plan.spawnPoints do
    assert(p[1]^2+p[2]^2<=plan.spawnRadius^2,"Spawn outside radius")
    for _,o in {{0,0},{2,0},{-2,0},{0,2},{0,-2}} do
        assert(math.abs(heightAt(p[1]+o[1],p[2]+o[2])-14)<0.01,"Spawn support not flat")
    end
end
if cfg.mode=="preview" then return output({preview=true,solidVoxels=solid,seamError=seamError,spawnCount=#plan.spawnPoints,pilotDigest=plan.pilotDigest}) end
-- Only now modify the detached task DataModel. One save, after all checks.
T:WriteVoxelChannels(region,4,generated)
local actual=T:ReadVoxelChannels(region,4,ch)
local maxError=0
for x=1,nx do for y=1,ny do for z=1,nz do
    maxError=math.max(maxError,math.abs(actual.SolidOccupancy[x][y][z]-generated.SolidOccupancy[x][y][z]))
    assert(actual.LiquidOccupancy[x][y][z]==0,"Unexpected water")
    if generated.SolidOccupancy[x][y][z]>0.02 then assert(actual.SolidMaterial[x][y][z]==generated.SolidMaterial[x][y][z],"Material readback mismatch") end
end end end
assert(maxError<=0.02,"Terrain readback error")
assert(digest(T:ReadVoxelChannels(oldRegion,4,ch),64,16,64)==plan.pilotDigest,"Pilot terrain modified")
local root=Instance.new("Folder");root.Name="RSCentralSpawns";root:SetAttribute("RSOwner","RSSceneSyncV1")
for i,p in plan.spawnPoints do
    local s=Instance.new("SpawnLocation");s.Name=string.format("Central_%02d",i);s.Size=Vector3.new(4,1,4)
    s.Position=Vector3.new(p[1],16,p[2]);s.Anchored=true;s.CanCollide=false;s.CanTouch=false;s.CanQuery=false
    s.Transparency=1;s.CastShadow=false;s.Neutral=true;s.Enabled=true;s.Duration=0;s.AllowTeamChangeOnTouch=false
    s:SetAttribute("RSSceneSyncId","central-spawn-"..i);s.Parent=root
end
root.Parent=W
local sc=Instance.new("Script");sc.Name="RSCentralSpawnSafety";sc:SetAttribute("RSOwner","RSSceneSyncV1");sc.Source=cfg.runtimeSource;sc.Parent=SSS
local archive=Instance.new("Folder");archive.Name="RSSceneSyncArchive";archive:SetAttribute("RSOwner","RSSceneSyncV1");archive.Parent=SS
for _,obj in targets do obj.Parent=archive end
local hashValue=digest(actual,nx,ny,nz)
game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false})
return output({saved=true,terrainDigest=hashValue,pilotDigest=plan.pilotDigest,solidVoxels=solid,seamError=seamError,readbackError=maxError,spawnCount=#plan.spawnPoints,archived=2})
