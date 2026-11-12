-- Inspect the already-created original asset independently of EditableMesh.
-- No reupload, no Place save and no imported script execution.
local A=game:GetService("AssetService")
local m=A:LoadAssetAsync(tonumber(cfg.assetId))
assert(m and m:IsA("Model") and m.Parent==nil,"Detached Model")
local meshes,bones,scripts={},{},0
local classes={}
local function vec(v) return {v.X,v.Y,v.Z} end
for _,o in m:GetDescendants() do
    classes[o.ClassName]=(classes[o.ClassName] or 0)+1
    if o:IsA("LuaSourceContainer") then scripts+=1 end
    if o:IsA("MeshPart") then table.insert(meshes,o) end
    if o:IsA("Bone") then table.insert(bones,o) end
end
assert(scripts==0 and #meshes>0,"Original model safety")
local _,size=m:GetBoundingBox()
local dependencies={}
local allLoaded=true
for _,mesh in meshes do
    local status={}
    local ok,err=pcall(function()
        game:GetService("ContentProvider"):PreloadAsync({mesh},function(uri,st)status[uri]=st.Name end)
    end)
    local loaded=ok and status[mesh.MeshId]=="Success"
    allLoaded=allLoaded and loaded
    table.insert(dependencies,{name=mesh.Name,meshId=mesh.MeshId,size=vec(mesh.Size),loaded=loaded,callback=status,error=if ok then "" else tostring(err):sub(1,200)})
end
local boughs,roots,crowns=0,0,0
local names={}
local transforms=0
for _,b in bones do
    table.insert(names,{name=b.Name,parent=b.Parent.Name,position=vec(b.Position)})
    if b.Name=="Root" then roots+=1 end
    if b.Name=="Crown" then crowns+=1 end
    if string.sub(b.Name,1,6)=="Bough_" then
        boughs+=1
        local rest=b.Transform
        local next=CFrame.Angles(0,0,math.rad(3))
        b.Transform=next
        local _,a=b.Transform:ToAxisAngle()
        if math.abs(a-math.rad(3))<.001 then transforms+=1 end
        b.Transform=rest
    end
end
table.sort(names,function(a,b)return a.name<b.name end)
local proof={assetId=cfg.assetId,classes=classes,meshes=#meshes,bones=#bones,boughs=boughs,roots=roots,crowns=crowns,scripts=scripts,boneNames=names,transforms=transforms,dependencies=dependencies,meshLoaded=allLoaded,size=vec(size),noPlaceWrites=true,clientRenderVerified=false,skinningVerified=false,editableTested=false}
m:Destroy()
return syncResult(proof)
