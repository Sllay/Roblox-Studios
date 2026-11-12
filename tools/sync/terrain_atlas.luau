-- Pinned read-only native terrain atlas, decimated for visual overview.
local T=workspace.Terrain
local tiles={}
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local step=2
for _,region in cfg.regions do
    if not region.playable then continue end
    local b=region.bounds
    local nx,ny,nz=(b[4]-b[1])/4,(b[5]-b[2])/4,(b[6]-b[3])/4
    assert(nx%step==0 and nz%step==0,"Atlas alignment")
    local d=T:ReadVoxelChannels(Region3.new(Vector3.new(b[1],b[2],b[3]),Vector3.new(b[4],b[5],b[6])),4,channels)
    local all=buffer.create(nx*ny*nz*6)
    local offset=0
    for x=1,nx do for y=1,ny do for z=1,nz do
        buffer.writeu16(all,offset,math.round(d.SolidOccupancy[x][y][z]*65535))
        buffer.writeu16(all,offset+2,math.round(d.LiquidOccupancy[x][y][z]*65535))
        buffer.writeu16(all,offset+4,d.SolidMaterial[x][y][z].Value);offset+=6
    end end end
    local digest=buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(all,Enum.HashAlgorithm.Sha256)))
    local samples=buffer.create(nx*nz/(step*step)*5)
    local at=0
    for z=1,nz,step do for x=1,nx,step do
        local h=b[2];local material=Enum.Material.Air.Value;local wet=false
        for y=1,ny do
            local o=d.SolidOccupancy[x][y][z]
            if o>0.02 then h=b[2]+(y-1+o)*4;material=d.SolidMaterial[x][y][z].Value end
            if d.LiquidOccupancy[x][y][z]>0.02 then wet=true end
        end
        buffer.writei16(samples,at,math.round(h*10));buffer.writeu16(samples,at+2,material);buffer.writeu8(samples,at+4,if wet then 1 else 0)
        at+=5
    end end
    table.insert(tiles,{id=region.id,bounds=b,digest=digest,nx=nx/step,nz=nz/step,samples=buffer.tostring(Encoding:Base64Encode(samples))})
end
local materials={}
for _,m in Enum.Material:GetEnumItems() do materials[tostring(m.Value)]=m.Name end
return syncResult({schemaVersion=1,stepStuds=8,sampleOffsetStuds=2,tiles=tiles,materials=materials,noPlaceWrites=true})
