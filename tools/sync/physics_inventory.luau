-- Read-only inventory and detached geometry probes; no SavePlaceAsync.
local W=workspace
local roots={RSSceneBuilder="RSSceneBuilderV1",RSWorldVegetation="RSWorldV1",RSEnvironmentP4="RSEnvironmentP4V1",RSEnvironmentP4Detail="RSEnvironmentP4DetailV1",RSManagedAssets="RobloxStudiosStaticV1"}
local function vec(v) return {v.X,v.Y,v.Z} end
local function bounds(part)
    local cf,s=part.CFrame,part.Size/2
    local y=math.abs(cf.RightVector.Y)*s.X+math.abs(cf.UpVector.Y)*s.Y+math.abs(cf.LookVector.Y)*s.Z
    return part.Position.Y-y,part.Position.Y+y
end
local function species(m)
    local s=m:GetAttribute("RSSpecies")
    if typeof(s)=="string" then return s end
    local id=m:GetAttribute("RSManagedId")
    if id=="yasu-tree-01" then return "Tree_01" end
    if typeof(id)=="string" then
        local a=string.match(id,"^forest%-([a-z]+_%d+)%-%d+$")
        if a then return string.upper(string.sub(a,1,1))..string.sub(a,2) end
    end
    return ""
end
local rows={}
local specimens={}
for name,owner in roots do
    local root=W:FindFirstChild(name)
    assert(root and root:GetAttribute("RSOwner")==owner,"Managed root")
    local models=if name=="RSManagedAssets" then root else root:FindFirstChild("Models")
    local collisions=root:FindFirstChild("Collisions")
    assert(models,"Models")
    for _,m in models:GetChildren() do
        if not m:IsA("Model") then continue end
        local id=m:GetAttribute("RSManagedId")
        assert(typeof(id)=="string","Model identity")
        local sp=species(m)
        local p=m:GetPivot().Position
        local low,high=math.huge,-math.huge
        local meshRows={}
        local trunk=nil
        for _,v in m:GetDescendants() do
            if v:IsA("MeshPart") then
                local lo,hi=bounds(v);low=math.min(low,lo);high=math.max(high,hi)
                local row={name=v.Name,mesh=v.MeshId,size=vec(v.Size),meshSize=vec(v.MeshSize),position=vec(v.Position),cframe={v.CFrame:GetComponents()},material=v.Material.Name,anchored=v.Anchored,collide=v.CanCollide,touch=v.CanTouch,query=v.CanQuery,low=lo,high=hi}
                table.insert(meshRows,row)
                if string.sub(v.Name,1,5)=="Trunk" then trunk=v end
            end
        end
        assert(#meshRows>0,"Visual model empty")
        local c=collisions and collisions:FindFirstChild(m.Name)
        local old=nil
        if c then
            assert(c:IsA("Part") and c.Shape==Enum.PartType.Cylinder and c.Anchored and c.CanCollide,"Unexpected collider")
            old={name=c.Name,size=vec(c.Size),position=vec(c.Position),cframe={c.CFrame:GetComponents()},group=c.CollisionGroup,owner=c:GetAttribute("RSOwner"),query=c.CanQuery,touch=c.CanTouch}
        end
        if trunk and (string.sub(sp,1,5)=="Tree_" or string.sub(sp,1,5)=="Pine_") and not specimens[sp] then specimens[sp]=trunk end
        table.insert(rows,{root=name,id=id,species=sp,asset=m:GetAttribute("RSAssetId"),position=vec(p),scale=m:GetScale(),ground=m:GetAttribute("RSExpectedGroundY"),low=low,top=high,meshes=meshRows,collider=old,playable=math.abs(p.X)<384 and math.abs(p.Z)<384})
    end
end
table.sort(rows,function(a,b)return a.id<b.id end)
local geometry={}
local AS=game:GetService("AssetService")
for sp,trunk in specimens do
    local ok,mesh=pcall(function()return AS:CreateEditableMeshAsync(Content.fromUri(trunk.MeshId),{FixedSize=true})end)
    local r={mesh=trunk.MeshId,status="unavailable"}
    if ok and mesh then
        local worked,data=pcall(function()
            local ids=mesh:GetVertices()
            local faces=mesh:GetFaces()
            assert(#ids<=30000 and #faces<=60000,"Geometry budget")
            local minV,maxV=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
            for _,id in ids do
                local p=mesh:GetPosition(id)
                minV=Vector3.new(math.min(minV.X,p.X),math.min(minV.Y,p.Y),math.min(minV.Z,p.Z))
                maxV=Vector3.new(math.max(maxV.X,p.X),math.max(maxV.Y,p.Y),math.max(maxV.Z,p.Z))
            end
            -- Slice at multiple heights of the source trunk, not at branch extents.
            local sections={}
            for _,q in {0.12,0.2,0.28,0.36} do
                local y=minV.Y+(maxV.Y-minV.Y)*q
                local xs,zs={},{}
                for _,fid in faces do
                    local v=mesh:GetFaceVertices(fid)
                    if #v==3 then
                        for i=1,3 do
                            local a,b=mesh:GetPosition(v[i]),mesh:GetPosition(v[i%3+1])
                            if (a.Y<=y and b.Y>y) or (b.Y<=y and a.Y>y) then
                                local p=a:Lerp(b,(y-a.Y)/(b.Y-a.Y))
                                table.insert(xs,p.X);table.insert(zs,p.Z)
                            end
                        end
                    end
                end
                if #xs>0 then
                    local x0,x1=math.huge,-math.huge;local z0,z1=math.huge,-math.huge
                    for i,x in xs do x0=math.min(x0,x);x1=math.max(x1,x);z0=math.min(z0,zs[i]);z1=math.max(z1,zs[i]) end
                    table.insert(sections,{q=q,widthX=x1-x0,widthZ=z1-z0,centerX=(x0+x1)/2,centerZ=(z0+z1)/2,hits=#xs})
                end
            end
            return {vertices=#ids,faces=#faces,min=vec(minV),max=vec(maxV),sections=sections}
        end)
        mesh:Destroy()
        if worked then r.status="mesh_sections";r.data=data else r.reason=tostring(data):sub(1,250) end
    else r.reason=tostring(mesh):sub(1,250) end
    geometry[sp]=r
end
-- Test actual query capability with a known detached control.
local wm=Instance.new("WorldModel")
local control=Instance.new("Part");control.Size=Vector3.new(4,4,4);control.CFrame=CFrame.new();control.Anchored=true;control.Parent=wm
local ok,hit=pcall(function()return wm:Raycast(Vector3.new(0,10,0),Vector3.new(0,-20,0))end)
local worldModel={executed=ok,controlHit=ok and hit~=nil}
wm:Destroy()
return syncResult({schemaVersion=1,rows=rows,geometry=geometry,worldModel=worldModel,noPlaceWrites=true})
