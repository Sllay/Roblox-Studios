-- S07 disposable geometry and native contact probe. Never saves a Place.
local W=workspace
local T=W.Terrain
local F=W.RSResourcesP45.Models
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local before=terrainState()
local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances={T};ray.IgnoreWater=false;ray.RespectCanCollide=true
local function hit(x,z)
    local h=W:Raycast(Vector3.new(x,112,z),Vector3.new(0,-144,0),ray)
    if h and h.Instance==T and (h.Material==Enum.Material.Grass or h.Material==Enum.Material.Ground) then return h end
end
local function write(region,d) T:WriteVoxelChannels(region,4,{SolidMaterial=d.SolidMaterial,SolidOccupancy=d.SolidOccupancy,LiquidOccupancy=d.LiquidOccupancy}) end
local out={}
for _,r in cfg.rows do
    local src=F:FindFirstChild(r.sourceId);assert(src and src:IsA("Model"),"Source")
    local m=src:Clone();assert(m,"Clone")
    local parts={}
    for _,p in m:GetDescendants() do if p:IsA("BasePart") then table.insert(parts,p) end end
    assert(#parts==1 and parts[1]:IsA("MeshPart"),"Single mesh geometry required")
    local p=parts[1];local rel=m:GetPivot():ToObjectSpace(p.CFrame)
    local factors=Vector3.new(table.unpack(r.factors))*r.scale
    local function axis(v)
        local a=Vector3.new(math.abs(v.X),math.abs(v.Y),math.abs(v.Z))
        assert(math.max(a.X,a.Y,a.Z)>.999,"Non-axis-aligned source geometry")
        return a:Dot(factors)
    end
    local oldSize=p.Size
    p.Size=oldSize*Vector3.new(axis(rel.RightVector),axis(rel.UpVector),axis(rel.LookVector))
    local desiredSize=p.Size
    local x,z=r.x,r.z
    local region=Region3.new(Vector3.new(math.floor(x/4)*4-12,-32,math.floor(z/4)*4-12),Vector3.new(math.floor(x/4)*4+16,112,math.floor(z/4)*4+16))
    local original=T:ReadVoxelChannels(region,4,channels)
    local empty=T:ReadVoxelChannels(region,4,channels)
    for i=1,7 do for j=1,36 do for k=1,7 do
        empty.SolidMaterial[i][j][k]=Enum.Material.Air;empty.SolidOccupancy[i][j][k]=0;empty.LiquidOccupancy[i][j][k]=0
    end end end
    write(region,empty);write(region,original)
    local h
    for _=1,20 do h=hit(x,z);if h then break end;task.wait(.1) end
    local row={id=r.id,type=r.type,tile=r.tile,oldSize={oldSize.X,oldSize.Y,oldSize.Z},newSize={desiredSize.X,desiredSize.Y,desiredSize.Z},accepted=false}
    if h then
        local up=h.Normal.Unit
        local heading=Vector3.new(math.cos(math.rad(r.yaw)),0,math.sin(math.rad(r.yaw)))
        local right=(heading-up*heading:Dot(up)).Unit
        local frame=CFrame.fromMatrix(h.Position,right,up,right:Cross(up))
        -- Center the actual mesh bounds, retaining its audited local axis orientation.
        p.CFrame=frame*rel.Rotation
        local cf,size=m:GetBoundingBox()
        local low,high=math.huge,-math.huge
        local valid=true
        for _,a in {{0,0},{-.42,0},{.42,0},{0,-.42},{0,.42},{-.42,-.42},{.42,.42},{-.42,.42},{.42,-.42}} do
            local q=frame:PointToWorldSpace(Vector3.new(a[1]*r.bounds[1]*r.scale,-r.bounds[2]*r.scale/2,a[2]*r.bounds[3]*r.scale))
            local s=hit(q.X,q.Z)
            if not s then valid=false;break end
            local gap=q.Y-s.Position.Y;low=math.min(low,gap);high=math.max(high,gap)
        end
        if valid then
            local lift=.01-low
            p.CFrame=p.CFrame+Vector3.yAxis*lift
            row.gap=high-low+.01;row.slope=math.deg(math.acos(math.clamp(up.Y,-1,1)))
            row.accepted=row.gap<.22 and row.slope<=35
            row.normal={up.X,up.Y,up.Z}
        end
    end
    m:Destroy();table.insert(out,row)
end
local after=terrainState()
for i,r in after do assert(r.digest==before[i].digest,"Terrain changed") end
return syncResult({rows=out,noPlaceWrites=true,all49Restored=#after==49,clientRenderVerified=false})
