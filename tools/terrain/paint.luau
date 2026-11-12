
-- Paint EXISTING terrain only, never sculpt or touch liquid occupancy.
local Http=game:GetService("HttpService")
local E=game:GetService("EncodingService")
local T=workspace.Terrain
local cfg=Http:JSONDecode(__RS_CONFIG__)
assert(tostring(game.GameId)==cfg.universeId and tostring(game.PlaceId)==cfg.placeId,"Target mismatch")
local p=cfg.plan
local b=p.bounds
local lo,hi=Vector3.new(b[1],b[2],b[3]),Vector3.new(b[4],b[5],b[6])
local region=Region3.new(lo,hi)
local nx,ny,nz=(hi.X-lo.X)/4,(hi.Y-lo.Y)/4,(hi.Z-lo.Z)/4
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local function hash(data,geometryOnly)
    local bytes=buffer.create(nx*ny*nz*(if geometryOnly then 4 else 6))
    local at=0
    for x=1,nx do for y=1,ny do for z=1,nz do
        buffer.writeu16(bytes,at,math.round(data.SolidOccupancy[x][y][z]*65535))
        buffer.writeu16(bytes,at+2,math.round(data.LiquidOccupancy[x][y][z]*65535))
        at+=4
        if not geometryOnly then buffer.writeu16(bytes,at,data.SolidMaterial[x][y][z].Value);at+=2 end
    end end end
    return buffer.tostring(E:Base64Encode(E:ComputeBufferHash(bytes,Enum.HashAlgorithm.Sha256)))
end
local function mask(x,z)
    local m=p.mask
    if m.kind=="circle" or m.kind=="ring" then
        local d=math.sqrt((x-m.center[1])^2+(z-m.center[2])^2)
        return d<=m.radius and (m.kind=="circle" or d>=m.innerRadius)
    elseif m.kind=="rectangle" then return x>=m.min[1] and x<=m.max[1] and z>=m.min[2] and z<=m.max[2]
    else
        for i=1,#m.points-1 do
            local a,c=m.points[i],m.points[i+1]
            local dx,dz=c[1]-a[1],c[2]-a[2]
            local t=math.clamp(((x-a[1])*dx+(z-a[2])*dz)/(dx*dx+dz*dz),0,1)
            if (x-a[1]-dx*t)^2+(z-a[2]-dz*t)^2<=(m.width/2)^2 then return true end
        end
        return false
    end
end
local function output(data)
    data.universeId=tostring(game.GameId);data.placeId=tostring(game.PlaceId)
    return Http:JSONEncode(data)
end
local before=T:ReadVoxelChannels(region,4,channels)
local geometry=hash(before,true)
local baseline=hash(before,false)
if cfg.mode=="verify" then
    assert(geometry==cfg.geometryDigest and baseline==cfg.afterDigest,"Paint persistence mismatch")
    return output({verified=true,geometryDigest=geometry,afterDigest=baseline})
end
local mat={}
local changed,selected,wetSkipped=0,0,0
local target=Enum.Material[p.material]
local source={}
for _,name in p.sourceMaterials do source[Enum.Material[name]]=true end
for x=1,nx do
    mat[x]={}
    for y=1,ny do mat[x][y]={} end
    for z=1,nz do
        local top=0
        local wet=false
        for y=1,ny do
            mat[x][y][z]=before.SolidMaterial[x][y][z]
            if before.SolidOccupancy[x][y][z]>0.02 then top=y end
            if before.LiquidOccupancy[x][y][z]>0.02 then wet=true end
        end
        if top>0 and mask(lo.X+(x-0.5)*4,lo.Z+(z-0.5)*4) then
            assert(top<ny,"Paint region cuts through solid terrain vertically")
            selected+=1
            if wet and not p.allowUnderwater then wetSkipped+=1
            else
                for y=top,math.max(1,top-p.depthCells+1),-1 do
                    if before.SolidOccupancy[x][y][z]>0.02 and source[mat[x][y][z]] and mat[x][y][z]~=target then
                        mat[x][y][z]=target;changed+=1
                    end
                end
            end
        end
    end
end
local expected={SolidMaterial=mat,SolidOccupancy=before.SolidOccupancy,LiquidOccupancy=before.LiquidOccupancy}
local afterHash=hash(expected,false)
if cfg.mode=="preview" then return output({changedVoxels=changed,selectedColumns=selected,wetSkipped=wetSkipped,beforeDigest=baseline,geometryDigest=geometry,afterDigest=afterHash}) end
assert(cfg.mode=="apply" and cfg.environment=="staging" and game.PlaceVersion==cfg.expectedVersion,"Target/version changed")
assert(cfg.beforeDigest==baseline and cfg.afterDigest==afterHash and cfg.geometryDigest==geometry,"Paint plan baseline changed")
assert(changed>0,"No material changes")
T:WriteVoxelChannels(region,4,{SolidMaterial=mat})
local after=T:ReadVoxelChannels(region,4,channels)
assert(hash(after,true)==geometry and hash(after,false)==afterHash,"Paint changed geometry/liquid or unexpected material")
-- Explicit exact comparison, not just a rounded digest.
for x=1,nx do for y=1,ny do for z=1,nz do
    assert(after.SolidOccupancy[x][y][z]==before.SolidOccupancy[x][y][z] and after.LiquidOccupancy[x][y][z]==before.LiquidOccupancy[x][y][z],"Paint altered occupancy")
end end end
game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false})
return output({saved=true,changedVoxels=changed,beforeDigest=baseline,geometryDigest=geometry,afterDigest=afterHash})
