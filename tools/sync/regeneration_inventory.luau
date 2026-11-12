-- Native read-only environmental inventory, including previously omitted resource root.
local W=workspace
local owners={RSSceneBuilder="RSSceneBuilderV1",RSWorldVegetation="RSWorldV1",RSEnvironmentP4="RSEnvironmentP4V1",RSEnvironmentP4Detail="RSEnvironmentP4DetailV1",RSManagedAssets="RobloxStudiosStaticV1",RSResourcesP45="RSResourcesP45V1"}
local rows={}
local function species(m)
    local s=m:GetAttribute("RSSpecies")
    if typeof(s)=="string" then return s end
    local id=m:GetAttribute("RSManagedId")
    if id=="yasu-tree-01" then return "Tree_01" end
    local a=typeof(id)=="string" and string.match(id,"^forest%-([a-z]+_%d+)%-%d+$")
    if a then return string.upper(string.sub(a,1,1))..string.sub(a,2) end
    return ""
end
for name,owner in owners do
    local root=W:FindFirstChild(name);assert(root and root:GetAttribute("RSOwner")==owner,"Managed root")
    local folder=if name=="RSManagedAssets" then root else root:FindFirstChild("Models")
    assert(folder,"Models")
    for _,m in folder:GetChildren() do
        if not m:IsA("Model") then continue end
        local id=m:GetAttribute("RSManagedId");assert(typeof(id)=="string","Managed identity")
        local p=m:GetPivot()
        local lo,hi=math.huge,-math.huge
        local radius=0;local meshes=0
        for _,v in m:GetDescendants() do
            if v:IsA("MeshPart") then
                meshes+=1
                local c,s=v.CFrame,v.Size/2
                local ex=math.abs(c.RightVector.X)*s.X+math.abs(c.UpVector.X)*s.Y+math.abs(c.LookVector.X)*s.Z
                local ey=math.abs(c.RightVector.Y)*s.X+math.abs(c.UpVector.Y)*s.Y+math.abs(c.LookVector.Y)*s.Z
                local ez=math.abs(c.RightVector.Z)*s.X+math.abs(c.UpVector.Z)*s.Y+math.abs(c.LookVector.Z)*s.Z
                lo=math.min(lo,c.Position.Y-ey);hi=math.max(hi,c.Position.Y+ey)
                radius=math.max(radius,math.sqrt((math.abs(c.Position.X-p.X)+ex)^2+(math.abs(c.Position.Z-p.Z)+ez)^2))
            end
        end
        assert(meshes>0,"Missing geometry")
        local collisions=root:FindFirstChild("Collisions")
        local shaft=collisions and collisions:FindFirstChild(id)
        local cap=collisions and collisions:FindFirstChild(id.."-cap")
        local collider=nil
        if shaft then
            assert(shaft:IsA("Part") and shaft.Shape==Enum.PartType.Cylinder and cap and cap:IsA("Part") and cap.Shape==Enum.PartType.Ball,"Coupled collider")
            collider={diameter=shaft.Size.Y,shaft={shaft.CFrame:GetComponents()},shaftSize=vec(shaft.Size),cap={cap.CFrame:GetComponents()},capSize=vec(cap.Size),group=shaft.CollisionGroup,owner=shaft:GetAttribute("RSOwner")}
        end
        table.insert(rows,{id=id,root=name,species=species(m),asset=m:GetAttribute("RSAssetId"),sourceDigest=m:GetAttribute("RSModelDigest"),pivot={p:GetComponents()},scale=m:GetScale(),ground=m:GetAttribute("RSExpectedGroundY"),support=m:GetAttribute("RSSupportRadius"),radius=radius,low=lo,top=hi,records=1+#m:GetDescendants(),meshes=meshes,collider=collider,resourceType=m:GetAttribute("RSResourceType"),playable=math.abs(p.X)<384 and math.abs(p.Z)<384})
    end
end
table.sort(rows,function(a,b)return a.id<b.id end)
return syncResult({schemaVersion=1,rows=rows,noPlaceWrites=true})
