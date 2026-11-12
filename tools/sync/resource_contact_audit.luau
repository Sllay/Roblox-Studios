-- Disposable v17 readback: actual resource geometry, visual flags, terrain support and query controls.
local W=workspace
local T=W.Terrain
local A=game:GetService("AssetService")
local CP=game:GetService("ContentProvider")
local root=W:FindFirstChild("RSResourcesP45");assert(root and root:GetAttribute("RSOwner")=="RSResourcesP45V1","Resource root")
local folder=root:FindFirstChild("Models");assert(folder and #folder:GetChildren()==216,"Resource count")
local function v(a)return Vector3.new(table.unpack(a)) end
local function xyz(a)return {a.X,a.Y,a.Z} end
local function rayParams(obj,physical)
    local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Include;p.FilterDescendantsInstances={obj};p.IgnoreWater=false;p.RespectCanCollide=physical
    return p
end
local ray=rayParams(T,false);local physical=rayParams(T,true)
local function groundRay(x,z,top)
    for _,p in {ray,physical} do
        local h=W:Raycast(Vector3.new(x,top,z),Vector3.new(0,-240,0),p)
        if h and h.Instance==T then return {y=h.Position.Y,material=h.Material.Name,normal=xyz(h.Normal)} end
    end
    return false
end
local control=Instance.new("Part");control.Size=Vector3.new(4,4,4);control.Anchored=true;control.CanQuery=true;control.CanCollide=true;control.Position=Vector3.new(10000,200,10000);control.Parent=W
local controlHit=W:Raycast(control.Position+Vector3.yAxis*10,-Vector3.yAxis*20,rayParams(control,false))
local controlOK=controlHit~=nil and controlHit.Instance==control
control:Destroy()
local cache={}
local function column(i,j)
    local key=i..":"..j
    if cache[key] then return cache[key] end
    local b=Vector3.new(i*4,-32,j*4)
    local d=T:ReadVoxelChannels(Region3.new(b,b+Vector3.new(4,144,4)),4,{"SolidMaterial","SolidOccupancy","LiquidOccupancy"})
    local h,mat,occ,wet=nil,nil,nil,false
    for y=1,36 do
        local s=d.SolidOccupancy[1][y][1]
        if s>.02 then h=-32+(y-1+s)*4;mat=d.SolidMaterial[1][y][1].Name;occ=s end
        if d.LiquidOccupancy[1][y][1]>.02 then wet=true end
    end
    assert(h and mat,"Voxel support")
    local r={x=i*4,z=j*4,height=h,material=mat,occupancy=occ,wet=wet}
    cache[key]=r;return r
end
local function estimated(x,z)
    local gx,gz=x/4-.5,z/4-.5;local i,j=math.floor(gx),math.floor(gz)
    local a,b,c,d=column(i,j),column(i+1,j),column(i,j+1),column(i+1,j+1)
    local tx,tz=gx-i,gz-j
    return (a.height+(b.height-a.height)*tx)*(1-tz)+(c.height+(d.height-c.height)*tx)*tz
end
local function extent(cf,size)
    return (math.abs(cf.RightVector.Y)*size.X+math.abs(cf.UpVector.Y)*size.Y+math.abs(cf.LookVector.Y)*size.Z)/2
end
local rows={};local representatives={}
local seen={}
for _,r in cfg.rows do
    local m=folder:FindFirstChild(r.id);assert(m and m:IsA("Model") and m:GetAttribute("RSManagedId")==r.id,"Resource identity")
    assert(not seen[r.id],"Duplicate");seen[r.id]=true
    local p=m:FindFirstChildWhichIsA("MeshPart",true);assert(p,"MeshPart")
    local pivot=m:GetPivot();local cf,size=m:GetBoundingBox()
    local half=extent(cf,size);local bottom=cf.Position.Y-half;local top=cf.Position.Y+half
    local e=estimated(cf.Position.X,cf.Position.Z)
    local col=column(math.floor(cf.Position.X/4),math.floor(cf.Position.Z/4))
    local hit=groundRay(cf.Position.X,cf.Position.Z,cf.Position.Y+40)
    local meshHit=W:Raycast(cf.Position+Vector3.yAxis*5,-Vector3.yAxis*10,rayParams(p,false))
    local contacts={}
    for _,a in {{0,0},{-.35,0},{.35,0},{0,-.35},{0,.35}} do
        local pos=cf:PointToWorldSpace(Vector3.new(a[1]*size.X,0,a[2]*size.Z))
        local h=groundRay(pos.X,pos.Z,cf.Position.Y+40)
        table.insert(contacts,{x=pos.X,z=pos.Z,estimatedY=estimated(pos.X,pos.Z),ray=h})
    end
    local record0={id=r.id,category=r.category,tile=m:GetAttribute("RSResourceChunk"),patch=r.patch,position=xyz(pivot.Position),bboxPosition=xyz(cf.Position),bboxSize=xyz(size),partSize=xyz(p.Size),meshSize=xyz(p.MeshSize),partPosition=xyz(p.Position),bottom=bottom,top=top,expectedGround=m:GetAttribute("RSExpectedGroundY"),burial=m:GetAttribute("RSBuriedDepth"),voxelGround=e,voxelBaseGap=bottom-e,voxelTopGap=top-e,nearestColumn=col,ray=hit,contacts=contacts,meshQueryHit=meshHit~=nil and meshHit.Instance==p,meshId=p.MeshId,textureId=p.TextureID,transparency=p.Transparency,localTransparency=p.LocalTransparencyModifier,color={p.Color.R,p.Color.G,p.Color.B},material=p.Material.Name,renderFidelity=p.RenderFidelity.Name,anchored=p.Anchored,canCollide=p.CanCollide,canQuery=p.CanQuery,collisionGroup=p.CollisionGroup,scale=m:GetScale(),descendants=#m:GetDescendants()}
    if hit then record0.rayBaseGap=bottom-hit.y;record0.rayTopGap=top-hit.y end
    table.insert(rows,record0)
    representatives[r.category]=representatives[r.category] or p
end
local assets={}
for category,p in representatives do
    local statuses={}
    local ok,err=pcall(function()CP:PreloadAsync({p},function(uri,status)statuses[uri]=status.Name end)end)
    local edit={status="unavailable"}
    local em=nil
    local editOK,editErr=pcall(function()
        em=A:CreateEditableMeshAsync(p.MeshContent,{FixedSize=true})
        assert(em,"Editable allocation")
        local ids=em:GetVertices();local lo=Vector3.new(math.huge,math.huge,math.huge);local hi=-lo
        for _,id in ids do local x=em:GetPosition(id);lo=Vector3.new(math.min(lo.X,x.X),math.min(lo.Y,x.Y),math.min(lo.Z,x.Z));hi=Vector3.new(math.max(hi.X,x.X),math.max(hi.Y,x.Y),math.max(hi.Z,x.Z)) end
        edit={status="editable",vertices=#ids,triangles=#em:GetFaces(),bounds=xyz(hi-lo)}
    end)
    if not editOK then edit.reason=tostring(editErr):sub(1,250) end
    if em then em:Destroy() end
    assets[category]={meshId=p.MeshId,textureId=p.TextureID,preload=ok,statuses=statuses,error=if ok then "" else tostring(err):sub(1,250),edit=edit}
end
return syncResult({rows=rows,assets=assets,controlPartRay=controlOK,noPlaceWrites=true,clientRenderVerified=false})
