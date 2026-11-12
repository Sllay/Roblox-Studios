
-- Shared placement solver, injected into checked-in Open Cloud tasks.
-- Approved ground only; no arbitrary geometry or decoration as support.
local function solvePlacement(model: Model, x: number, z: number, yaw: number, profile)
    assert(profile.schemaVersion==1 and profile.orientation=="upright","Unsupported profile")
    assert(profile.mountType=="sit_on_ground" or profile.mountType=="bury_in_ground","Unsupported mount type")
    local depth=profile.buryDepthStuds
    assert(typeof(depth)=="number" and depth>=0 and depth<=64,"Invalid burial")
    assert(profile.mountType~="sit_on_ground" or depth==0,"Invalid sit profile")
    assert(profile.contactRule=="bounds_bottom_plus_burial","Unsupported contact rule")
    local ground={}
    for _,name in profile.groundNames do
        local obj=Workspace:FindFirstChild(name)
        assert(obj and obj:IsA("BasePart") and obj.Anchored and obj.CanCollide,"Approved ground missing: "..name)
        table.insert(ground,obj)
    end
    assert(#ground>0,"No approved ground")
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances=ground
    params.RespectCanCollide=true
    params.IgnoreWater=true
    local radius=profile.supportRadiusStuds
    local heights={}
    local hitNames={}
    local normals={}
    for _,offset in {{0,0},{radius,0},{-radius,0},{0,radius},{0,-radius}} do
        local hit=Workspace:Raycast(Vector3.new(x+offset[1],profile.rayTop,z+offset[2]),Vector3.new(0,profile.rayBottom-profile.rayTop,0),params)
        assert(hit,"Ground missing under support footprint")
        assert(hit.Material~=Enum.Material.Water,"Water is not ground")
        local slope=math.deg(math.acos(math.clamp(hit.Normal.Y,-1,1)))
        assert(slope<=profile.maxSlopeDegrees,"Ground slope exceeds profile")
        table.insert(heights,hit.Position.Y)
        table.insert(hitNames,hit.Instance:GetFullName())
        table.insert(normals,{hit.Normal.X,hit.Normal.Y,hit.Normal.Z})
    end
    assert(math.max(table.unpack(heights))-math.min(table.unpack(heights))<=profile.maxHeightDeltaStuds,"Uneven support")
    -- Evaluate actual rotated bounds without changing geometry. Restore the original pivot.
    local old=model:GetPivot()
    model:PivotTo(CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(yaw),0))
    local bb,size=model:GetBoundingBox()
    -- GetBoundingBox follows the model's orientation; upright yaw preserves Y.
    local bottom=bb.Position.Y-size.Y/2
    model:PivotTo(old)
    assert(depth<size.Y*0.5,"Burial exceeds half model height")
    local y=heights[1]-bottom-depth
    return {position={x,y,z},groundY=heights[1],bottomOffset=bottom,
        contactY=heights[1],buriedDepth=depth,groundPaths=hitNames,supportHeights=heights,supportNormals=normals}
end
