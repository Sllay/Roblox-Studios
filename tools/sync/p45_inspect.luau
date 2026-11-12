-- Detached read-only inventory of actual foliage and coupled tree colliders.
local roots={RSSceneBuilder="RSSceneBuilderV1",RSWorldVegetation="RSWorldV1",RSEnvironmentP4="RSEnvironmentP4V1",RSEnvironmentP4Detail="RSEnvironmentP4DetailV1",RSManagedAssets="RobloxStudiosStaticV1"}
local rows={}
for name,owner in roots do
    local r=workspace:FindFirstChild(name)
    assert(r and r:GetAttribute("RSOwner")==owner,"Unexpected managed root "..name)
    local models=if name=="RSManagedAssets" then r else r:FindFirstChild("Models")
    local collisions=r:FindFirstChild("Collisions")
    assert(models,"Models missing")
    for _,m in models:GetChildren() do
        if not m:IsA("Model") then continue end
        local bb,size=m:GetBoundingBox()
        local p=m:GetPivot().Position
        local row={root=name,id=m:GetAttribute("RSManagedId"),species=m:GetAttribute("RSSpecies"),asset=m:GetAttribute("RSAssetId"),position={p.X,p.Y,p.Z},ground=m:GetAttribute("RSExpectedGroundY"),bounds={size.X,size.Y,size.Z},top=bb.Position.Y+size.Y/2,meshes={}}
        for _,v in m:GetDescendants() do
            if v:IsA("MeshPart") then
                table.insert(row.meshes,{name=v.Name,mesh=v.MeshId,material=v.Material.Name,anchored=v.Anchored,collide=v.CanCollide,touch=v.CanTouch,query=v.CanQuery,size={v.Size.X,v.Size.Y,v.Size.Z},position={v.Position.X,v.Position.Y,v.Position.Z}})
            end
        end
        local c=collisions and collisions:FindFirstChild(m.Name)
        if c and c:IsA("Part") then row.collider={shape=c.Shape.Name,size={c.Size.X,c.Size.Y,c.Size.Z},position={c.Position.X,c.Position.Y,c.Position.Z},collide=c.CanCollide} end
        table.insert(rows,row)
    end
end
return syncResult({rows=rows,noPlaceWrites=true})
