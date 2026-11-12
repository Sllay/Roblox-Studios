-- Read-only actual canopy permission and original geometry control.
-- __RS_DEFORM__
local A=game:GetService("AssetService")
local rows={}
for _,r in cfg.meshes do
    local ok,m=pcall(function()return A:CreateEditableMeshAsync(Content.fromUri(r.mesh),{FixedSize=true})end)
    local entry={species=r.species,mesh=r.mesh,status="denied"}
    if ok and m then
        local ids=m:GetVertices();local bones=0
        local boneOK,b=pcall(function() return m:GetBones() end)
        if boneOK then bones=#b end
        entry.status="editable";entry.vertices=#ids;entry.bones=bones;m:Destroy()
    else entry.reason=tostring(m):sub(1,250) end
    table.insert(rows,entry)
end
-- Original procedural geometry: a small branch fan, not a replacement for
-- imported trees. Test actual linked vertices and independent upper motion.
local original={status="unavailable"}
local ok,err=pcall(function()
    local m=A:CreateEditableMesh();assert(m,"Editable memory")
    local ids={}
    for _,p in {Vector3.new(0,0,0),Vector3.new(-1,4,0),Vector3.new(1,4,0),Vector3.new(0,8,0),Vector3.new(0,6,2)} do table.insert(ids,m:AddVertex(p)) end
    m:AddTriangle(ids[1],ids[2],ids[3]);m:AddTriangle(ids[2],ids[4],ids[3]);m:AddTriangle(ids[2],ids[5],ids[4])
    local part=A:CreateMeshPartAsync(Content.fromObject(m),{CollisionFidelity=Enum.CollisionFidelity.Box})
    assert(part and part:IsA("MeshPart"),"Linked mesh")
    local base=m:GetPosition(ids[1]);local upper=m:GetPosition(ids[4])
    local delta=D.displacement(upper,0,8,2,1,0,Vector3.xAxis,8)
    assert(delta.Magnitude>0 and D.displacement(base,0,8,2,1,0,Vector3.xAxis,8)==Vector3.zero,"Height weighting")
    m:SetPosition(ids[4],upper+delta);assert((m:GetPosition(ids[4])-upper-delta).Magnitude<.0001,"Native position")
    original={status="linked_mesh_verified",vertices=5,upperDisplacement=delta.Magnitude,baseDisplacement=0}
    part:Destroy();m:Destroy()
end)
if not ok then original.reason=tostring(err):sub(1,250) end
return syncResult({canopies=rows,originalControl=original,noPlaceWrites=true,clientVerified=false})
