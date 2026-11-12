-- Native clone/resize/pose verification; no writes to Place.
local root=workspace:FindFirstChild("RSResourcesP45");assert(root,"Resources")
local folder=root:FindFirstChild("Models");assert(folder,"Models")
local n=0;local maxError=0
for _,r in cfg.rows do
    local m=folder:FindFirstChild(r.id)
    assert(m and m:IsA("Model") and m:GetAttribute("RSModelDigest")==r.sourceDigest,"Resource identity")
    local p=m:GetPivot();assert((p.Position-Vector3.new(r.sourcePivot[1],r.sourcePivot[2],r.sourcePivot[3])).Magnitude<.002 and math.abs(m:GetScale()-r.sourceScale)<.001,"Source changed")
    local c=m:Clone();assert(c,"Clone");c:ScaleTo(r.targetScale)
    c:PivotTo(CFrame.new(table.unpack(r.position))*CFrame.Angles(0,math.rad(r.yaw),0))
    local cf,size=c:GetBoundingBox()
    local expected=Vector3.new(table.unpack(r.bounds))
    maxError=math.max(maxError,(size-expected).Magnitude)
    assert((size-expected).Magnitude<.02 and (cf.Position-Vector3.new(table.unpack(r.position))).Magnitude<.02,"Native resource dimensions")
    local mesh=c:FindFirstChildWhichIsA("MeshPart",true)
    assert(mesh and mesh.Anchored,"Resource visual")
    if r.category=="stone" then assert(mesh.MeshId=="rbxassetid://122505516420043","White rock identity")
    else assert(mesh.MeshId=="rbxassetid://123968188" and mesh.TextureID=="rbxassetid://123968836","Stick identity") end
    c:Destroy();n+=1
end
return syncResult({checked=n,maxBoundsError=maxError,noPlaceWrites=true})
