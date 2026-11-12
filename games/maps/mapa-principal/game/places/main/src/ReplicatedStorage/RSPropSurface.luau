-- Shared native surface placement. Caller owns lifecycle and publication.
local M={}
function M.frame(position,normal,yaw,align)
    local up=if align=="surface" then normal.Unit else Vector3.yAxis
    local heading=Vector3.new(math.cos(yaw),0,math.sin(yaw))
    local right=heading-up*heading:Dot(up)
    assert(right.Magnitude>1e-5,"Degenerate tangent")
    right=right.Unit
    return CFrame.fromMatrix(position,right,up,right:Cross(up))
end
function M.ray(world,terrain,x,z,top,depth)
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Include
    p.FilterDescendantsInstances={terrain}
    p.IgnoreWater=false
    p.RespectCanCollide=true
    local h=world:Raycast(Vector3.new(x,top,z),Vector3.new(0,-depth,0),p)
    if not h or h.Instance~=terrain or h.Material==Enum.Material.Water then return nil end
    return h
end
-- A bounded readiness probe must run after the terrain writer completes.
-- Never treat a missed ray as a valid height or silently use voxel estimates.
function M.waitReady(world,terrain,probes,timeout)
    assert(#probes>0 and timeout>0,"Readiness configuration")
    local deadline=os.clock()+timeout
    repeat
        local ok=true
        for _,p in probes do
            local h=M.ray(world,terrain,p.x,p.z,p.top,p.depth)
            if not h or math.abs(h.Position.Y-p.expectedY)>p.tolerance then ok=false;break end
        end
        if ok then return true end
        task.wait(.1)
    until os.clock()>=deadline
    return false
end
return M
