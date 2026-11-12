-- Build detached physical components and check native geometry. No Place writes.
local serial=game:GetService("SerializationService")
local function v(a) return Vector3.new(table.unpack(a)) end
local function near(a,b) return (a-b).Magnitude<0.001 end
local function make(spec,row,name)
    local p=Instance.new("Part")
    p.Name=name;p.Shape=Enum.PartType[spec.shape];p.Size=v(spec.size)
    p.CFrame=CFrame.new(v(spec.position))*(if spec.rotation=="Z90" then CFrame.Angles(0,0,math.pi/2) else CFrame.identity)
    p.Anchored=true;p.CanCollide=true;p.CanTouch=false;p.CanQuery=true;p.Transparency=1;p.CastShadow=false
    p.CollisionGroup=row.collisionGroup
    p.CustomPhysicalProperties=PhysicalProperties.new(1,0.05,0,100,1)
    return p
end
local checked=0
local samples={}
local seen={}
for _,row in cfg.profiles do
    local root=workspace:FindFirstChild(row.root);assert(root,"Managed root")
    local models=if row.root=="RSManagedAssets" then root else root:FindFirstChild("Models")
    local m=models and models:FindFirstChild(row.id)
    assert(m and m:IsA("Model") and m:GetAttribute("RSManagedId")==row.id and near(m:GetPivot().Position,v(row.modelPosition)) and math.abs(m:GetScale()-row.modelScale)<0.00001,"Model changed")
    local old=root:FindFirstChild("Collisions")
    old=old and old:FindFirstChild(row.id)
    if row.oldCollider then assert(old and old:IsA("Part") and near(old.Size,v(row.oldCollider.size)) and near(old.Position,v(row.oldCollider.position)),"Collider changed") else assert(not old,"Unexpected existing collider") end
    local shaft=make(row.shaft,row,"Shaft")
    local cap=make(row.cap,row,"Cap")
    assert(shaft.Shape==Enum.PartType.Cylinder and cap.Shape==Enum.PartType.Ball,"Shape")
    assert(math.abs(shaft.CFrame.RightVector.Y-1)<0.00001,"Cylinder axis")
    assert(near(shaft.Size,v(row.shaft.size)) and near(cap.Size,v(row.cap.size)),"Native size clamp")
    assert(math.abs(shaft.Position.Y-shaft.Size.X/2-row.bottom)<0.001,"Bottom")
    assert(math.abs(cap.Position.Y+cap.Size.Y/2-row.top)<0.001,"Top")
    assert(math.abs(shaft.Position.Y+shaft.Size.X/2-cap.Position.Y)<0.001,"Cap seam")
    assert(math.abs(shaft.Position.X-cap.Position.X)<0.001 and math.abs(shaft.Position.Z-cap.Position.Z)<0.001 and math.abs(shaft.Size.Y-cap.Size.X)<0.001,"Cap alignment")
    local model=Instance.new("Model");shaft.Parent=model;cap.Parent=model
    if not seen[row.species] then
        seen[row.species]=true
        local blob=serial:SerializeInstancesAsync({model})
        local copies=serial:DeserializeInstancesAsync(blob);assert(#copies==1,"Roundtrip root")
        local a,b=copies[1]:FindFirstChild("Shaft"),copies[1]:FindFirstChild("Cap")
        assert(a and a:IsA("Part") and b and b:IsA("Part") and a.Shape==shaft.Shape and b.Shape==cap.Shape and near(a.Size,shaft.Size) and near(b.Size,cap.Size) and near(a.Position,shaft.Position) and near(b.Position,cap.Position),"Collider roundtrip")
        assert(a.CanCollide and b.CanCollide and a.Anchored and b.Anchored and a.CollisionGroup==row.collisionGroup and b.CollisionGroup==row.collisionGroup,"Roundtrip physics flags")
        table.insert(samples,{species=row.species,diameter=row.diameter,height=row.top-row.groundY,bytes=buffer.len(blob)})
        copies[1]:Destroy()
    end
    model:Destroy();checked+=1
end
return syncResult({schemaVersion=1,checked=checked,samples=samples,noPlaceWrites=true,runtimePhysicsVerified=false})
