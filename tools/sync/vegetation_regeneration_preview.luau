-- Detached native geometry proof of a reviewed vegetation plan. No Place writes.
local function v(a)return Vector3.new(table.unpack(a)) end
local function near(a,b,t)return (a-b).Magnitude<(t or .005) end
local function bounds(m)
    local pivot=m:GetPivot().Position;local radius,low,top=0,math.huge,-math.huge
    for _,p in m:GetDescendants() do
        assert(p:IsA("MeshPart") or p:IsA("SurfaceAppearance"),"Unexpected vegetation class")
        if p:IsA("MeshPart") then
            assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,"Visual physics")
            local c,s=p.CFrame,p.Size/2
            local x=math.abs(c.RightVector.X)*s.X+math.abs(c.UpVector.X)*s.Y+math.abs(c.LookVector.X)*s.Z
            local y=math.abs(c.RightVector.Y)*s.X+math.abs(c.UpVector.Y)*s.Y+math.abs(c.LookVector.Y)*s.Z
            local z=math.abs(c.RightVector.Z)*s.X+math.abs(c.UpVector.Z)*s.Y+math.abs(c.LookVector.Z)*s.Z
            low=math.min(low,c.Position.Y-y);top=math.max(top,c.Position.Y+y)
            radius=math.max(radius,math.sqrt((math.abs(c.Position.X-pivot.X)+x)^2+(math.abs(c.Position.Z-pivot.Z)+z)^2))
        end
    end
    return low,top,radius
end
local function piece(spec)
    local p=Instance.new("Part");p.Shape=Enum.PartType[spec.shape];p.Size=v(spec.size)
    p.CFrame=CFrame.new(v(spec.position))*(if spec.rotation=="Z90" then CFrame.Angles(0,0,math.pi/2) else CFrame.identity)
    p.Anchored=true;p.CanCollide=true
    assert(near(p.Size,v(spec.size)) and near(p.Position,v(spec.position)),"Native collider dimensions")
    return p
end
local n,trees=0,0;local maxHeightError,maxRadiusError=0,0
local storage=Instance.new("Folder")
for _,r in cfg.rows do
    local root=workspace:FindFirstChild(r.sourceRoot);assert(root,"Source root")
    local folder=if r.sourceRoot=="RSManagedAssets" then root else root:FindFirstChild("Models")
    local m=folder and folder:FindFirstChild(r.sourceId)
    assert(m and m:IsA("Model") and m:GetAttribute("RSManagedId")==r.sourceId,"Source model")
    assert(m:GetAttribute("RSAssetId")==r.asset and math.abs(m:GetScale()-r.sourceScale)<.001 and near(m:GetPivot().Position,v({r.sourcePivot[1],r.sourcePivot[2],r.sourcePivot[3]})),"Source changed")
    if r.sourceDigest then assert(m:GetAttribute("RSModelDigest")==r.sourceDigest,"Source digest") end
    local c=m:Clone();assert(c and 1+#c:GetDescendants()==r.sourceRecords,"Clone hierarchy")
    c:ScaleTo(r.scale);c:PivotTo(CFrame.new(table.unpack(r.pivot)));c.Parent=storage
    assert(near(c:GetPivot().Position,v(r.position)) and math.abs(c:GetScale()-r.scale)<.001,"Target transform")
    local lo,top,radius=bounds(c)
    maxHeightError=math.max(maxHeightError,math.abs(top-r.groundY-r.physicalHeight))
    maxRadiusError=math.max(maxRadiusError,math.abs(radius-r.canopyRadius))
    if r.collider then
        local a,b=piece(r.collider.shaft),piece(r.collider.cap)
        assert(math.abs(a.CFrame.RightVector.Y-1)<.001 and math.abs(a.Position.Y+a.Size.X/2-b.Position.Y)<.005 and math.abs(b.Position.Y+b.Size.Y/2-top)<.03,"Collider top")
        a.Parent=storage;b.Parent=storage;trees+=1
    end
    n+=1
end
assert(maxHeightError<.03 and maxRadiusError<.03,"Geometry mismatch")
storage:Destroy()
return syncResult({checked=n,treeProfiles=trees,maxHeightError=maxHeightError,maxRadiusError=maxRadiusError,noPlaceWrites=true,runtimeVerified=false})
