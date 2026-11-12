-- Read-only historical capability probe. No SavePlaceAsync, no third-party code.
local H=game:GetService("HttpService")
local cfg=H:JSONDecode(__RS_CONFIG__)
assert(tostring(game.GameId)==cfg.universeId and tostring(game.PlaceId)==cfg.placeId,"Target mismatch")
local W=workspace
local results={}
local function test(name,fn)
    local ok,value=pcall(fn)
    results[name]={status=if ok then "executed" else "error",value=if ok then value else tostring(value):sub(1,350)}
end
local function xyz(v) return {v.X,v.Y,v.Z} end
local function hit(v)
    if not v then return {hit=false} end
    return {hit=true,name=v.Instance.Name,position=xyz(v.Position),normal=xyz(v.Normal),material=v.Material.Name}
end
local spawn=W:FindFirstChild("RSCentralSpawns")
local a
if spawn then for _,v in spawn:GetChildren() do if v:IsA("SpawnLocation") then a=v;break end end end
assert(a,"No sample spawn")
local pos=a.Position
local param=RaycastParams.new()
param.FilterType=Enum.RaycastFilterType.Include
param.FilterDescendantsInstances={W.Terrain}
test("terrain.raycast",function()
    return hit(W:Raycast(pos+Vector3.new(0,32,0),Vector3.new(0,-100,0),param))
end)
test("terrain.spherecast",function()
    return hit(W:Spherecast(pos+Vector3.new(0,32,0),1,Vector3.new(0,-100,0),param))
end)
test("terrain.voxel",function()
    local center=Vector3.new(math.floor(pos.X/4)*4,math.floor(pos.Y/4)*4,math.floor(pos.Z/4)*4)
    local d=W.Terrain:ReadVoxelChannels(Region3.new(center-Vector3.new(4,16,4),center+Vector3.new(4,4,4)),4,{"SolidMaterial","SolidOccupancy","LiquidOccupancy"})
    local solid,water=0,0
    for x=1,2 do for y=1,5 do for z=1,2 do
        solid+=d.SolidOccupancy[x][y][z];water+=d.LiquidOccupancy[x][y][z]
    end end end
    return {solidOccupancySum=solid,liquidOccupancySum=water}
end)
test("physics.overlap",function()
    local p=OverlapParams.new();p.FilterType=Enum.RaycastFilterType.Include;p.FilterDescendantsInstances={a}
    p.MaxParts=8
    local parts=W:GetPartBoundsInBox(a.CFrame,a.Size+Vector3.one,p)
    return {count=#parts,containsSample=table.find(parts,a)~=nil}
end)
test("physics.part_raycast",function()
    local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Include;p.FilterDescendantsInstances={a}
    return hit(W:Raycast(pos+Vector3.new(0,12,0),Vector3.new(0,-24,0),p))
end)
test("navigation.path",function()
    local other
    for _,v in spawn:GetChildren() do
        if v:IsA("SpawnLocation") and (v.Position-pos).Magnitude>12 and (v.Position-pos).Magnitude<100 then other=v;break end
    end
    if not other then return {status="no_sample"} end
    local path=game:GetService("PathfindingService"):CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true})
    path:ComputeAsync(pos+Vector3.yAxis*2,other.Position+Vector3.yAxis*2)
    local value={status=path.Status.Name,waypoints=#path:GetWaypoints()}
    path:Destroy()
    return value
end)
test("mesh.editable_read",function()
    local root=W:FindFirstChild("RSManagedAssets")
    local m=root and root:FindFirstChildWhichIsA("MeshPart",true)
    assert(m and m.MeshId~="","No audited mesh")
    local mesh=game:GetService("AssetService"):CreateEditableMeshAsync(Content.fromUri(m.MeshId),{FixedSize=true})
    assert(mesh,"No editable memory or mesh access")
    local value={meshId=m.MeshId,vertices=#mesh:GetVertices(),faces=#mesh:GetFaces()}
    mesh:Destroy()
    return value
end)
test("serialization.roundtrip",function()
    local serial=game:GetService("SerializationService")
    local b=serial:SerializeInstancesAsync({a})
    local copies=serial:DeserializeInstancesAsync(b)
    local same=#copies==1 and copies[1].ClassName==a.ClassName and copies[1].Size==a.Size
    for _,v in copies do v:Destroy() end
    return {bytes=buffer.len(b),matchingSample=same}
end)
return H:JSONEncode({schemaVersion=1,universeId=cfg.universeId,placeId=cfg.placeId,context="headless_edit",sampleSpawn=a.Name,results=results,noPlaceWrites=true})
