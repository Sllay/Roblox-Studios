-- Native terrain compiler. One continuous height field; no Air carving for paint.
local Http=game:GetService("HttpService")
local Terrain=workspace.Terrain
local cfg=Http:JSONDecode(__RS_CONFIG__)
assert(tostring(game.GameId)==cfg.universeId and tostring(game.PlaceId)==cfg.placeId,"Target mismatch")
local p=cfg.plan
local b=p.bounds
local lo=Vector3.new(b[1],b[2],b[3])
local hi=Vector3.new(b[4],b[5],b[6])
local region=Region3.new(lo,hi)
local nx,ny,nz=(hi.X-lo.X)/4,(hi.Y-lo.Y)/4,(hi.Z-lo.Z)/4
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local function smooth(t)
    t=math.clamp(t,0,1)
    return t*t*(3-2*t)
end
local function mix(a,b,t) return a+(b-a)*t end
local function noise(x,z,layer)
    local sum,amp,freq=0,1,1/layer.wavelength
    local weight=0
    for i=1,layer.octaves do
        sum+=math.noise(x*freq+p.seed*0.013+layer.seedOffset,z*freq-p.seed*0.017,i*0.31)*2*amp
        weight+=amp
        freq*=layer.lacunarity
        amp*=layer.persistence
    end
    return sum/weight*layer.amplitude
end
local function distanceToPath(x,z,points)
    local best=math.huge
    for i=1,#points-1 do
        local a,c=points[i],points[i+1]
        local dx,dz=c[1]-a[1],c[2]-a[2]
        local t=math.clamp(((x-a[1])*dx+(z-a[2])*dz)/(dx*dx+dz*dz),0,1)
        best=math.min(best,math.sqrt((x-a[1]-dx*t)^2+(z-a[2]-dz*t)^2))
    end
    return best
end
local function column(x,z)
    local xx,zz=x,z
    if p.warp.amplitude>0 then
        xx+=math.noise(x/p.warp.wavelength,z/p.warp.wavelength,p.seed*0.019)*2*p.warp.amplitude
        zz+=math.noise(x/p.warp.wavelength,z/p.warp.wavelength,p.seed*0.031+20)*2*p.warp.amplitude
    end
    local height=p.baseHeight
    for _,layer in p.noiseLayers do height+=noise(xx,zz,layer) end
    local edge=math.min(x-lo.X,hi.X-x,z-lo.Z,hi.Z-z)
    height=mix(p.edgeHeight,height,smooth(edge/p.edgeBlend))
    local lake=p.lake
    local angle=math.atan2(z-lake.center[2],x-lake.center[1])
    local radius=lake.radius*(1+lake.irregularity*math.noise(math.cos(angle)*2,math.sin(angle)*2,p.seed*0.023)*2)
    local d=math.sqrt((x-lake.center[1])^2+(z-lake.center[2])^2)
    local shoreline=d-radius
    local wet=shoreline<0
    if wet then
        height=mix(lake.level-lake.depth,lake.level,smooth(d/radius))
    elseif shoreline<lake.bankWidth then
        height=mix(lake.level,lake.level+lake.bankRise,smooth(shoreline/lake.bankWidth))
    elseif shoreline<lake.bankWidth+lake.blendWidth then
        height=mix(lake.level+lake.bankRise,math.max(height,lake.level+lake.bankRise),smooth((shoreline-lake.bankWidth)/lake.blendWidth))
    end
    -- No disconnected water outside the basin. Every dry neighbor of water
    -- reaches the same water plane. Sand is a surface material, not geometry.
    local water=if wet then lake.level else nil
    local material="Grass"
    if wet or (shoreline>=0 and shoreline<=lake.sandWidth) then material="Sand" end
    local onPath=distanceToPath(x,z,p.path.points)<=p.path.width/2
    if onPath then
        assert(not wet and shoreline>lake.sandWidth,"Path intersects lake or sand margin")
        material=p.path.material
    end
    assert(height>=lo.Y+p.minSolidDepth and height<=hi.Y-4,"Column exceeds vertical bounds")
    return height,water,material
end
local function compile()
    local solid,liquid,material,painted={},{},{},{}
    local grid={}
    local count={wetColumns=0,sandColumns=0,pathColumns=0,grassColumns=0,solidVoxels=0,waterVoxels=0}
    local minH,maxH=math.huge,-math.huge
    for ix=1,nx do
        solid[ix]={};liquid[ix]={};material[ix]={};painted[ix]={};grid[ix]={}
        for iy=1,ny do solid[ix][iy]={};liquid[ix][iy]={};material[ix][iy]={};painted[ix][iy]={} end
        for iz=1,nz do
            local x,z=lo.X+(ix-0.5)*4,lo.Z+(iz-0.5)*4
            local height,water,surface=column(x,z)
            minH=math.min(minH,height);maxH=math.max(maxH,height)
            if water then count.wetColumns+=1;assert(ix>1 and ix<nx and iz>1 and iz<nz,"Water reaches boundary") end
            if surface=="Sand" then count.sandColumns+=1 elseif surface==p.path.material then count.pathColumns+=1 else count.grassColumns+=1 end
            grid[ix][iz]={math.round(height*100)/100,water or false,surface}
            for iy=1,ny do
                local y=lo.Y+(iy-1)*4
                local s=math.clamp((height-y)/4,0,1)
                local w=if water then math.min(1-s,math.clamp((water-y)/4,0,1)) else 0
                local mat=Enum.Material.Air
                if s>0 then
                    mat=if y+4>=height-p.surfaceDepth then Enum.Material.Grass elseif y+4>=height-p.soilDepth then Enum.Material.Ground else Enum.Material.Rock
                    count.solidVoxels+=1
                end
                if w>0 then count.waterVoxels+=1 end
                solid[ix][iy][iz]=s;liquid[ix][iy][iz]=w
                material[ix][iy][iz]=mat
                painted[ix][iy][iz]=if s>0 and y+4>=height-p.surfaceDepth then Enum.Material[surface] else mat
            end
        end
    end
    assert(count.wetColumns>0 and count.sandColumns>count.wetColumns and count.pathColumns>0 and count.grassColumns>0,"Missing terrain feature")
    -- Check continuous solid foundation and cardinal-neighbor water containment.
    for x=1,nx do for z=1,nz do
        assert(solid[x][1][z]>=0.999,"Foundation gap")
        if grid[x][z][2] then
            for _,off in {{1,0},{-1,0},{0,1},{0,-1}} do
                local other=grid[x+off[1]][z+off[2]]
                assert(other[2] or other[1]>=p.lake.level-0.01,"Water adjacent to uncontained dry column")
            end
        end
    end end
    return {SolidMaterial=material,SolidOccupancy=solid,LiquidOccupancy=liquid},painted,grid,count,minH,maxH
end
local function read() return Terrain:ReadVoxelChannels(region,4,channels) end
local function compare(a,b,paintOnly)
    local maxSolid,maxWater,materials=0,0,0
    for x=1,nx do for y=1,ny do for z=1,nz do
        maxSolid=math.max(maxSolid,math.abs(a.SolidOccupancy[x][y][z]-b.SolidOccupancy[x][y][z]))
        maxWater=math.max(maxWater,math.abs(a.LiquidOccupancy[x][y][z]-b.LiquidOccupancy[x][y][z]))
        if a.SolidMaterial[x][y][z]~=b.SolidMaterial[x][y][z] and a.SolidOccupancy[x][y][z]>0.02 then materials+=1 end
    end end end
    if paintOnly then assert(maxSolid==0 and maxWater==0,"Paint changed geometry or water")
    else assert(maxSolid<=0.02 and maxWater<=0.02 and materials==0,"Native voxel readback differs") end
    return {solidError=maxSolid,waterError=maxWater,materialDifferences=materials}
end
local function digest(data)
    local bytes=buffer.create(nx*ny*nz*6)
    local at=0
    for x=1,nx do for y=1,ny do for z=1,nz do
        buffer.writeu16(bytes,at,data.SolidMaterial[x][y][z].Value)
        buffer.writeu16(bytes,at+2,math.round(data.SolidOccupancy[x][y][z]*65535))
        buffer.writeu16(bytes,at+4,math.round(data.LiquidOccupancy[x][y][z]*65535))
        at+=6
    end end end
    local E=game:GetService("EncodingService")
    return buffer.tostring(E:Base64Encode(E:ComputeBufferHash(bytes,Enum.HashAlgorithm.Sha256)))
end
local function output(data)
    data.universeId=tostring(game.GameId);data.placeId=tostring(game.PlaceId)
    return Http:JSONEncode(data)
end
local initial,painted,grid,counts,minH,maxH=compile()
local expected={SolidMaterial=painted,SolidOccupancy=initial.SolidOccupancy,LiquidOccupancy=initial.LiquidOccupancy}
if cfg.mode=="preview" then return output({grid=grid,counts=counts,minHeight=minH,maxHeight=maxH}) end
local actual=read()
if cfg.mode=="verify" then
    local errors=compare(expected,actual,false)
    assert(digest(actual)==cfg.expectedDigest,"Persisted terrain digest changed")
    return output({verified=true,digest=digest(actual),errors=errors,counts=counts,grid=grid,minHeight=minH,maxHeight=maxH})
end
assert(cfg.mode=="apply" and cfg.environment=="staging" and game.PlaceVersion==cfg.expectedVersion,"Wrong mode/version")
-- Refuse overwrite. This first compiler creates a bounded new terrain region.
for x=1,nx do for y=1,ny do for z=1,nz do
    assert(actual.SolidOccupancy[x][y][z]==0 and actual.LiquidOccupancy[x][y][z]==0,"Existing terrain; refusing overwrite")
end end end
-- Check adjacent voxels so the bounded pilot cannot unexpectedly join unknown terrain.
local halo=Terrain:ReadVoxelChannels(Region3.new(lo-Vector3.new(4,4,4),hi+Vector3.new(4,4,4)),4,{"SolidOccupancy","LiquidOccupancy"})
for x=1,nx+2 do for y=1,ny+2 do for z=1,nz+2 do
    if x==1 or y==1 or z==1 or x==nx+2 or y==ny+2 or z==nz+2 then
        assert(halo.SolidOccupancy[x][y][z]==0 and halo.LiquidOccupancy[x][y][z]==0,"Existing terrain at boundary")
    end
end end end
for _,obj in workspace:GetDescendants() do
    if obj:IsA("BasePart") and not obj:IsA("Terrain") then
        local cf=obj.CFrame
        local half=obj.Size/2
        local extent=Vector3.new(
            math.abs(cf.RightVector.X)*half.X+math.abs(cf.UpVector.X)*half.Y+math.abs(cf.LookVector.X)*half.Z,
            math.abs(cf.RightVector.Y)*half.X+math.abs(cf.UpVector.Y)*half.Y+math.abs(cf.LookVector.Y)*half.Z,
            math.abs(cf.RightVector.Z)*half.X+math.abs(cf.UpVector.Z)*half.Y+math.abs(cf.LookVector.Z)*half.Z)
        local a,c=obj.Position-extent,obj.Position+extent
        assert(c.X<=lo.X or a.X>=hi.X or c.Y<=lo.Y+0.01 or a.Y>=hi.Y or c.Z<=lo.Z or a.Z>=hi.Z,"Existing object intersects terrain: "..obj:GetFullName())
    end
end
Terrain:WriteVoxelChannels(region,4,initial)
local beforePaint=read()
compare(initial,beforePaint,false)
-- Native material-only paint. Never write occupancy or liquid in this pass.
Terrain:WriteVoxelChannels(region,4,{SolidMaterial=painted})
local afterPaint=read()
local paintCheck=compare(beforePaint,afterPaint,true)
local finalCheck=compare(expected,afterPaint,false)
assert(paintCheck.materialDifferences>0,"Paint did not change materials")
-- Remove only the owned temporary P1 visual lab, not the imported tree.
local rs=game:GetService("ReplicatedStorage")
local sps=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local control=rs:FindFirstChild("RSLightingLabSource")
local lab=sps:FindFirstChild("RSLightingLab")
if p.cleanupLightingLab then
    assert(control and control:IsA("Model") and control:GetAttribute("RSOwner")=="RSLightingLabV1","Control ownership mismatch")
    assert(lab and lab:IsA("LocalScript") and lab:GetAttribute("RSOwner")=="RSLightingLabV1","Lab ownership mismatch")
    control:Destroy();lab:Destroy()
end
local hash=digest(afterPaint)
game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false})
return output({saved=true,digest=hash,counts=counts,paintCheck=paintCheck,finalCheck=finalCheck,minHeight=minH,maxHeight=maxH,labRemoved=p.cleanupLightingLab})
