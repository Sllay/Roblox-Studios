-- __RS_DEFORM__
-- Disposable probe of the already imported original canopy, never saves.
local A=game:GetService("AssetService")
local model=A:LoadAssetAsync(91515745821527)
assert(model and model:IsA("Model") and model.Parent==nil,"Owned model")
local part=model:FindFirstChildWhichIsA("MeshPart",true)
assert(part and part.MeshId=="rbxassetid://91110653005310","Owned geometry")
local e,linked
local report={assetId="91515745821527",meshId=part.MeshId,status="unavailable",noPlaceWrites=true,clientVerified=false}
local ok,err=pcall(function()
    e=A:CreateEditableMeshAsync(part.MeshContent,{FixedSize=true})
    assert(e,"Editable mesh memory")
    local ids=e:GetVertices()
    assert(#ids>0 and #ids<=D.maxVertices,"Vertex budget")
    local rest={};local low,high,minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge,math.huge,-math.huge
    for _,id in ids do
        local p=e:GetPosition(id);rest[id]=p
        low=math.min(low,p.Y);high=math.max(high,p.Y);minX=math.min(minX,p.X);maxX=math.max(maxX,p.X);minZ=math.min(minZ,p.Z);maxZ=math.max(maxZ,p.Z)
    end
    local width=math.max(maxX-minX,maxZ-minZ)
    assert(high>low and width>0,"Geometry extents")
    linked=A:CreateMeshPartAsync(Content.fromObject(e),{CollisionFidelity=Enum.CollisionFidelity.Box})
    assert(linked and linked:IsA("MeshPart"),"Linked mesh")
    linked.Anchored=true;linked.CanCollide=false;linked.CanTouch=false;linked.CanQuery=false
    local peak,fixed,active,frames,elapsed=0,0,0,0,0
    local phases={}
    for _,id in ids do
        if D.weight(rest[id].Y,low,high)==0 then fixed+=1 else active+=1 end
    end
    assert(fixed>0 and active>0,"Height mask")
    for frame=1,24 do
        local start=os.clock()
        for _,id in ids do
            local p=rest[id];local d=D.displacement(p,low,high,width,frame/12,.6,Vector3.xAxis,8)
            e:SetPosition(id,p+d);peak=math.max(peak,d.Magnitude)
        end
        elapsed+=os.clock()-start;frames+=1
        for _,id in ids do
            local p=rest[id];local actual=e:GetPosition(id)
            local d=D.displacement(p,low,high,width,frame/12,.6,Vector3.xAxis,8)
            assert((actual-p-d).Magnitude<.0001,"Vertex readback")
            if D.weight(p.Y,low,high)==0 then assert(actual==p,"Lower geometry moved") end
        end
    end
    assert(peak>0 and peak<=math.min(width*.035,(high-low)*.025)*1.3,"Amplitude bound")
    for _,id in ids do e:SetPosition(id,rest[id]) end
    for _,id in ids do assert(e:GetPosition(id)==rest[id],"Restoration") end
    report.status="native_vertices_verified";report.vertices=#ids;report.fixedVertices=fixed;report.activeVertices=active
    report.peakDisplacement=peak;report.height=high-low;report.width=width;report.frames=frames;report.meanUpdateMs=elapsed*1000/frames
    report.linkedMesh=true;report.restoredExact=true
end)
if not ok then report.reason=tostring(err):sub(1,500) end
if linked then linked:Destroy() end
if e then e:Destroy() end
model:Destroy()
return syncResult(report)
