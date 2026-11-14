do
local A=game:GetService("AssetService")
local CP=game:GetService("ContentProvider")
local model=A:LoadAssetAsync(tonumber(cfg.assetId))
assert(model:IsA("Model") and model.Parent==nil,"Detached model required")
local parts,bones,classes,animations={},{},{},{}
local scripts=0
for _,o in model:GetDescendants() do
    classes[o.ClassName]=(classes[o.ClassName] or 0)+1
    if o:IsA("MeshPart") then table.insert(parts,o) end
    if o:IsA("Bone") then bones[o.Name]=o end
    if o:IsA("LuaSourceContainer") then scripts+=1 end
    if o:IsA("Animation") or o:IsA("KeyframeSequence") or o:IsA("CurveAnimation") then
        local uri=""
        if o:IsA("Animation") then uri=o.AnimationId end
        table.insert(animations,{name=o.Name,class=o.ClassName,uri=uri})
    end
end
local expected={"Root","Body","Neck","Head","Jaw","Wing_L","Wing_R","Tail","Hip_L","Shin_L","Foot_L","Hip_R","Shin_R","Foot_R"}
local namesOK=true
local boneCount=classes.Bone or 0
local boneNames={}
for name,_ in pairs(bones) do table.insert(boneNames,name) end
table.sort(boneNames)
for _,name in expected do if not bones[name] then namesOK=false end end
local meshLoaded=false
local textureLoaded=false
local textureURIs={}
local meshId=""
local poseRoundtrip=false
local maxRestore=0
local probe={}
local _,size=model:GetBoundingBox()
local function err(a:CFrame,b:CFrame):number
    local av={a:GetComponents()};local bv={b:GetComponents()};local e=0
    for i=1,12 do e=math.max(e,math.abs(av[i]-bv[i])) end
    return e
end
if #parts==1 then
    local mesh=parts[1];meshId=mesh.MeshId
    local ok=pcall(function()
        CP:PreloadAsync({mesh},function(uri,status)
            if uri==mesh.MeshId then meshLoaded=status==Enum.AssetFetchStatus.Success end
        end)
    end)
    meshLoaded=ok and meshLoaded
    if mesh.TextureID~="" then table.insert(textureURIs,mesh.TextureID) end
    for _,o in mesh:GetDescendants() do
        if o:IsA("SurfaceAppearance") then
            local getOK,uri=pcall(function()return o.ColorMap end)
            if getOK and uri~="" then table.insert(textureURIs,uri) end
        end
    end
    for _,uri in textureURIs do
        local success=false
        local preloadOK=pcall(function() CP:PreloadAsync({uri},function(_,s) if s==Enum.AssetFetchStatus.Success then success=true end end) end)
        textureLoaded=textureLoaded or (preloadOK and success)
    end
    if namesOK then
        poseRoundtrip=true
        for _,name in {"Head","Jaw","Wing_L","Wing_R","Hip_L","Hip_R","Tail"} do
            local bone=bones[name]
            local original=bone.Transform
            local target=original*CFrame.Angles(math.rad(13),0,0)
            local before=bone.TransformedWorldCFrame
            bone.Transform=target
            local changed=err(bone.Transform,target)<1e-5
            local worldDelta=err(before,bone.TransformedWorldCFrame)
            bone.Transform=original
            local restore=err(bone.Transform,original)
            maxRestore=math.max(maxRestore,restore)
            poseRoundtrip=poseRoundtrip and changed and restore<1e-5 and worldDelta>1e-5
            table.insert(probe,{name=name,transformChanged=changed,worldDelta=worldDelta,restoreError=restore})
        end
    end
end
model:Destroy()
return syncResult({assetId=cfg.assetId,meshes=#parts,bones=boneCount,boneNames=boneNames,expectedBoneNames=namesOK,scripts=scripts,classes=classes,animations=animations,meshId=meshId,meshLoaded=meshLoaded,textureURIs=textureURIs,textureLoaded=textureLoaded,poseRoundtrip=poseRoundtrip,poseProbe=probe,maxRestoreError=maxRestore,size={size.X,size.Y,size.Z},noPlaceWrites=true})
end
