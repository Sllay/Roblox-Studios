-- Detached read-only component extraction. Never parent external assets to DataModel.
local Assets=game:GetService("AssetService")
local Serial=game:GetService("SerializationService")
local root=Assets:LoadAssetAsync(tonumber(cfg.assetId))
assert(root:IsA("Model") and root.Parent==nil,"Detached pack required")
local function vec(v) return {v.X,v.Y,v.Z} end
local function path(obj)
    local p={}
    while obj~=root do
        local parent=obj.Parent;assert(parent,"Outside source")
        table.insert(p,1,{name=obj.Name,class=obj.ClassName,index=table.find(parent:GetChildren(),obj)})
        obj=parent
    end
    return p
end
local function uri(v)
    assert(v=="" or string.match(v,"^rbxassetid://[1-9]%d*$"),"Unsupported URI: "..v)
    return v
end
local function inspect(part)
    local meshes={}
    for _,c in part:GetChildren() do
        if c:IsA("SpecialMesh") then
            table.insert(meshes,{selector=path(c),meshType=c.MeshType.Name,meshId=c.MeshId,textureId=c.TextureId,scale=vec(c.Scale),offset=vec(c.Offset),vertexColor=vec(c.VertexColor)})
        end
    end
    return {selector=path(part),class=part.ClassName,name=part.Name,size=vec(part.Size),cframe={part.CFrame:GetComponents()},color={part.Color.R,part.Color.G,part.Color.B},material=part.Material.Name,transparency=part.Transparency,meshes=meshes}
end
local parts={}
local scripts=0
for _,obj in root:GetDescendants() do
    if obj:IsA("LuaSourceContainer") then scripts+=1 end
    if obj:IsA("BasePart") then table.insert(parts,inspect(obj)) end
end
assert(#parts<=100,"Component inventory budget")
if cfg.componentMode=="inventory" then
    root:Destroy()
    return syncResult({schemaVersion=1,assetId=cfg.assetId,parts=parts,sourceScripts=scripts,noPlaceWrites=true,codeExecuted=false})
end
assert(cfg.componentMode=="extract" and #cfg.selector>0,"Exact extraction required")
local selected=root
for _,seg in cfg.selector do
    local child=selected:GetChildren()[seg.index]
    assert(child and child.ClassName==seg.class and child.Name==seg.name,"Selector mismatch")
    selected=child
end
assert(selected:IsA("Part") or selected:IsA("MeshPart"),"Only visual parts")
local source=inspect(selected)
assert(selected.Transparency<1 and selected.MaterialVariant=="","Unsupported invisible or variant part")
local result=Instance.new("Model")
result.Name="RSExtractedVisual"
local visual
local geometryStatus
if selected:IsA("MeshPart") then
    -- Clone geometry only, remove every child before adding approved surfaces.
    visual=selected:Clone();assert(visual,"Clone failed")
    for _,c in visual:GetChildren() do c:Destroy() end
    for _,c in selected:GetChildren() do
        if c:IsA("SurfaceAppearance") then
            local copy=c:Clone();assert(copy and #copy:GetDescendants()==0,"Invalid surface");copy.Parent=visual
        end
    end
    geometryStatus="meshpart_bounds"
else
    assert(#source.meshes==1,"Exact single SpecialMesh required")
    local mesh=selected:FindFirstChildOfClass("SpecialMesh")
    assert(mesh and mesh.MeshType==Enum.MeshType.FileMesh,"FileMesh required")
    local meshId=uri(mesh.MeshId);local textureId=uri(mesh.TextureId)
    assert(meshId~="","Missing mesh")
    -- Use actual native MeshPart geometry if permitted; legacy SpecialMesh scale
    -- is not a stud-space bound and must never be treated as one.
    local ok,m=pcall(function() return Assets:CreateMeshPartAsync(Content.fromUri(meshId)) end)
    if not ok or not m then
        root:Destroy();result:Destroy()
        return syncResult({schemaVersion=1,assetId=cfg.assetId,source=source,status="geometry_blocked",reason=tostring(m):sub(1,300),sourceScripts=scripts,noPlaceWrites=true,codeExecuted=false})
    end
    visual=m
    visual.TextureID=textureId
    visual.Color=selected.Color
    visual.Material=selected.Material
    visual.Transparency=selected.Transparency
    visual.Reflectance=selected.Reflectance
    geometryStatus="converted_file_mesh_native_bounds"
end
assert(visual:IsA("MeshPart"),"MeshPart required")
visual.Name="Visual";visual.Anchored=true;visual.CanCollide=false;visual.CanTouch=false;visual.CanQuery=false
visual.CastShadow=false;visual.CFrame=CFrame.new();visual.Parent=result
-- Strip provenance and behavior metadata from new component.
local Tags=game:GetService("CollectionService")
for _,o in result:GetDescendants() do
    assert(o:IsA("MeshPart") or o:IsA("SurfaceAppearance"),"Unsafe output class")
    for k in o:GetAttributes() do o:SetAttribute(k,nil) end
    for _,tag in Tags:GetTags(o) do Tags:RemoveTag(o,tag) end
end
result.PrimaryPart=visual
local cp=game:GetService("ContentProvider")
local deps={}
local meshId=uri(visual.MeshId);local textureId=uri(visual.TextureID)
assert(meshId~="","Missing output mesh")
local ids={meshId};if textureId~="" then table.insert(ids,textureId) end
for _,o in visual:GetChildren() do
    if o:IsA("SurfaceAppearance") then
        for _,k in {"ColorMapContent","NormalMapContent","RoughnessMapContent","MetalnessMapContent","EmissiveMaskContent"} do
            local c=o[k]
            assert(c.SourceType==Enum.ContentSourceType.None or c.SourceType==Enum.ContentSourceType.Uri,"Unsupported surface content")
            if c.SourceType==Enum.ContentSourceType.Uri then table.insert(ids,uri(c.Uri)) end
        end
    end
end
cp:PreloadAsync(ids,function(id,status) deps[id]=status.Name end)
for _,id in ids do assert(deps[id]=="Success","Dependency fetch failed: "..id) end
local blob=Serial:SerializeInstancesAsync({result})
assert(buffer.len(blob)<=512000,"Component budget")
local digest=buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(blob,Enum.HashAlgorithm.Sha256)))
local clones=Serial:DeserializeInstancesAsync(blob)
assert(#clones==1 and clones[1]:IsA("Model"),"Roundtrip root")
local restored=clones[1]:FindFirstChild("Visual")
assert(restored and restored:IsA("MeshPart") and restored.MeshId==visual.MeshId and restored.TextureID==visual.TextureID and restored.Size==visual.Size,"Roundtrip visual")
assert(not restored.CanCollide and not restored.CanTouch and not restored.CanQuery and restored.Anchored,"Roundtrip flags")
for _,o in clones[1]:GetDescendants() do assert(o:IsA("MeshPart") or o:IsA("SurfaceAppearance"),"Unsafe roundtrip") end
local report={schemaVersion=1,assetId=cfg.assetId,source=source,status="extracted",geometryStatus=geometryStatus,sourceScripts=scripts,outputClasses={},meshId=meshId,textureId=textureId,size=vec(visual.Size),meshSize=vec(visual.MeshSize),dependencies=deps,digest=digest,serializedBase64=buffer.tostring(Encoding:Base64Encode(blob)),roundtripVerified=true,noPlaceWrites=true,codeExecuted=false,importAuthorized=false}
for _,o in result:GetDescendants() do table.insert(report.outputClasses,o.ClassName) end
clones[1]:Destroy();result:Destroy();root:Destroy()
return syncResult(report)
