-- Disposable geometry-only rehydration of exact existing voxel channels.
-- Never saves the Place. All 49 persisted terrain hashes must be restored.
local W=workspace
local T=W.Terrain
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local before=terrainState()
for _,r in before do assert(cfg.terrainExpected[r.id]==r.digest,"Stale terrain") end
local folder=W.RSResourcesP45.Models
local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances={T};ray.RespectCanCollide=true;ray.IgnoreWater=false
local function cast(pos)
    local h=W:Raycast(pos+Vector3.yAxis*40,-Vector3.yAxis*100,ray)
    if h and h.Instance==T then return {y=h.Position.Y,material=h.Material.Name,normal={h.Normal.X,h.Normal.Y,h.Normal.Z}} end
    return false
end
local function survey()
    local rows={};local hits=0
    for _,r in cfg.rows do
        local m=folder:FindFirstChild(r.id);assert(m and m:IsA("Model"),"Resource")
        local cf,s=m:GetBoundingBox()
        local e=(math.abs(cf.RightVector.Y)*s.X+math.abs(cf.UpVector.Y)*s.Y+math.abs(cf.LookVector.Y)*s.Z)/2
        local bottom,top=cf.Position.Y-e,cf.Position.Y+e
        local center=cast(cf.Position)
        local row={id=r.id,category=r.category,expectedGround=r.groundY,bottom=bottom,top=top,center=center,footprint={}}
        if center then
            hits+=1;row.groundDelta=center.y-r.groundY;row.baseGap=bottom-center.y;row.topGap=top-center.y
        end
        for _,a in {{0,0},{-.42,0},{.42,0},{0,-.42},{0,.42}} do
            local p=cf:PointToWorldSpace(Vector3.new(a[1]*s.X,0,a[2]*s.Z))
            local hit=cast(p);table.insert(row.footprint,{x=p.X,z=p.Z,hit=hit})
        end
        table.insert(rows,row)
    end
    return rows,hits
end
local _,initial=survey()
local function write(r,d)
    T:WriteVoxelChannels(r,4,{SolidMaterial=d.SolidMaterial,SolidOccupancy=d.SolidOccupancy,LiquidOccupancy=d.LiquidOccupancy})
end
local function rebuild(force)
    for _,p in cfg.patches do
        local x,z=p.center[1],p.center[2]
        local region=Region3.new(Vector3.new(x-12,-32,z-12),Vector3.new(x+12,112,z+12))
        local d=T:ReadVoxelChannels(region,4,channels)
        if force then
            local empty=T:ReadVoxelChannels(region,4,channels)
            for i=1,6 do for j=1,36 do for k=1,6 do
                empty.SolidMaterial[i][j][k]=Enum.Material.Air
                empty.SolidOccupancy[i][j][k]=0;empty.LiquidOccupancy[i][j][k]=0
            end end end
            write(region,empty)
        end
        write(region,d)
    end
end
rebuild(false)
task.wait(1)
local rows,hits=survey()
local sameHits=hits;local mode="exact_channel_rewrite"
if hits<#cfg.rows then
    rebuild(true)
    task.wait(1)
    rows,hits=survey();mode="temporary_clear_and_exact_restore"
end
local after=terrainState()
for i,r in after do assert(r.id==before[i].id and r.digest==before[i].digest and r.solidVoxels==before[i].solidVoxels and r.waterVoxels==before[i].waterVoxels,"Terrain restore mismatch") end
return syncResult({initialHits=initial,sameRewriteHits=sameHits,finalHits=hits,mode=mode,rows=rows,all49Restored=#after==49,noPlaceWrites=true,clientRenderVerified=false})
