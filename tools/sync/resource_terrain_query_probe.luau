-- Read-only published scene audit; temporary control terrain is restored in this disposable session.
local W=workspace
local T=W.Terrain
local function xyz(p)return {p.X,p.Y,p.Z} end
local function hitAt(pos,physical,include)
    local p=RaycastParams.new();p.IgnoreWater=false;p.RespectCanCollide=physical
    if include then p.FilterType=Enum.RaycastFilterType.Include;p.FilterDescendantsInstances={T} end
    local r=W:Raycast(pos,Vector3.new(0,-100,0),p)
    return if r then {instance=r.Instance.ClassName,name=r.Instance.Name,y=r.Position.Y,material=r.Material.Name,normal=xyz(r.Normal)} else false
end
local function queries(pos)
    return {filtered=hitAt(pos,false,true),physical=hitAt(pos,true,true),unfiltered=hitAt(pos,false,false)}
end
local settings={canQuery=T.CanQuery,canCollide=T.CanCollide,collisionGroup=T.CollisionGroup,decoration=T.Decoration}
local ok,g=pcall(function()return T.GrassLength end);if ok then settings.grassLength=g end
local rocks={}
for _,m in W.RSEnvironmentP4Detail.Models:GetChildren() do
    if m:IsA("Model") and m:GetAttribute("RSSpecies")=="Mossy_Rock1_M_Mossy_Rock_0_Node" then
        local cf,s=m:GetBoundingBox();local p=m:FindFirstChildWhichIsA("MeshPart",true)
        local e=(math.abs(cf.RightVector.Y)*s.X+math.abs(cf.UpVector.Y)*s.Y+math.abs(cf.LookVector.Y)*s.Z)/2
        local expected=m:GetAttribute("RSExpectedGroundY")
        local row={id=m.Name,position=xyz(cf.Position),size=xyz(s),burial=m:GetAttribute("RSBuriedDepth"),expectedGround=expected,bottom=cf.Position.Y-e,top=cf.Position.Y+e,transparency=p.Transparency,meshId=p.MeshId,canCollide=p.CanCollide,ray=queries(cf.Position+Vector3.yAxis*40)}
        if expected then row.estimatedBaseGap=row.bottom-expected;row.estimatedTopGap=row.top-expected end
        table.insert(rocks,row)
    end
end
assert(#rocks==6,"Large rocks")
table.sort(rocks,function(a,b)return a.id<b.id end)
-- A disposable, distant empty column distinguishes persisted terrain from newly authored terrain.
local region=Region3.new(Vector3.new(2040,160,2040),Vector3.new(2056,176,2056))
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local d=T:ReadVoxelChannels(region,4,channels)
local function digest(data)
    local b=buffer.create(4*4*4*6);local off=0
    for x=1,4 do for y=1,4 do for z=1,4 do
        buffer.writeu16(b,off,math.round(data.SolidOccupancy[x][y][z]*65535));buffer.writeu16(b,off+2,math.round(data.LiquidOccupancy[x][y][z]*65535));buffer.writeu16(b,off+4,data.SolidMaterial[x][y][z].Value);off+=6
    end end end
    return buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(b,Enum.HashAlgorithm.Sha256)))
end
local before=digest(d)
for x=1,4 do for y=1,4 do for z=1,4 do assert(d.SolidOccupancy[x][y][z]==0 and d.LiquidOccupancy[x][y][z]==0,"Control must be empty") end end end
local pos=Vector3.new(2048,195,2048)
local initial=queries(pos)
T:FillBlock(CFrame.new(2048,168,2048),Vector3.new(16,16,16),Enum.Material.Rock)
local filled=T:ReadVoxelChannels(region,4,channels)
local count=0
for x=1,4 do for y=1,4 do for z=1,4 do if filled.SolidOccupancy[x][y][z]>0 then count+=1 end end end end
assert(count>0,"Control terrain not generated")
local immediate=queries(pos)
task.wait(.5)
local delayed=queries(pos)
T:WriteVoxelChannels(region,4,{SolidMaterial=d.SolidMaterial,SolidOccupancy=d.SolidOccupancy,LiquidOccupancy=d.LiquidOccupancy})
local after=digest(T:ReadVoxelChannels(region,4,channels));assert(after==before,"Control terrain restore")
return syncResult({settings=settings,rocks=rocks,temporaryTerrain={filledVoxels=count,before=initial,immediate=immediate,delayed=delayed,restoredExact=true},noPlaceWrites=true,clientRenderVerified=false})
