-- Preview v18 resource contact plus 2x sticks in disposable v17. No Place save.
local W=workspace
local T=W.Terrain
local F=W.RSResourcesP45.Models
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local function canonical(x)
    if typeof(x)~="table" then return Http:JSONEncode(x) end
    local keys={};for k in x do table.insert(keys,k) end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    local out={};for _,k in keys do table.insert(out,Http:JSONEncode(tostring(k))..":"..canonical(x[k])) end
    return "{"..table.concat(out,",").."}"
end
local function rootHash()
    local rows={}
    for _,o in {F,table.unpack(F:GetDescendants())} do table.insert(rows,hash(canonical(record(W,o)))) end
    table.sort(rows);return hash(table.concat(rows,";"))
end
local before=terrainState();local originalRoot=rootHash()
for _,r in before do assert(cfg.terrainExpected[r.id]==r.digest,"Stale terrain") end
local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances={T};ray.RespectCanCollide=true;ray.IgnoreWater=false
local function cast(pos)
    local h=W:Raycast(pos+Vector3.yAxis*40,-Vector3.yAxis*100,ray)
    assert(h and h.Instance==T and h.Material~=Enum.Material.Water,"Real dry support required")
    return {y=h.Position.Y,material=h.Material.Name,normal={h.Normal.X,h.Normal.Y,h.Normal.Z}}
end
local function measure(m)
    local cf,s=m:GetBoundingBox();local e=(math.abs(cf.RightVector.Y)*s.X+math.abs(cf.UpVector.Y)*s.Y+math.abs(cf.LookVector.Y)*s.Z)/2
    local low,high=math.huge,-math.huge;local grass=0;local hits={}
    for _,a in {{0,0},{-.42,0},{.42,0},{0,-.42},{0,.42}} do
        local p=cf:PointToWorldSpace(Vector3.new(a[1]*s.X,0,a[2]*s.Z));local h=cast(p)
        low=math.min(low,h.y);high=math.max(high,h.y);if h.material=="Grass" then grass+=1 end
        table.insert(hits,h)
    end
    return {bottom=cf.Position.Y-e,top=cf.Position.Y+e,center=hits[1],low=low,high=high,grass=grass,hits=hits}
end
local function write(region,d)
    T:WriteVoxelChannels(region,4,{SolidMaterial=d.SolidMaterial,SolidOccupancy=d.SolidOccupancy,LiquidOccupancy=d.LiquidOccupancy})
end
local function clearRestore(region,d)
    local empty=T:ReadVoxelChannels(region,4,channels)
    for i=1,6 do for j=1,36 do for k=1,6 do
        empty.SolidMaterial[i][j][k]=Enum.Material.Air;empty.SolidOccupancy[i][j][k]=0;empty.LiquidOccupancy[i][j][k]=0
    end end end
    write(region,empty);write(region,d)
end
local function copy(region)
    return T:ReadVoxelChannels(region,4,channels)
end
local regions0={}
for _,p in cfg.patches do
    local x,z=p.center[1],p.center[2]
    local region=Region3.new(Vector3.new(x-12,-32,z-12),Vector3.new(x+12,112,z+12))
    local original=copy(region)
    table.insert(regions0,{id=p.id,x=x,z=z,region=region,original=original,painted=copy(region)})
    clearRestore(region,original)
end
task.wait(1)
local source={}
for _,r in cfg.rows do
    local m=F:FindFirstChild(r.id);assert(m and m:IsA("Model"),"Resource")
    local s=measure(m);assert(s.top<s.center.y,"Expected reproduced buried resource")
    assert(math.abs(s.center.y-cfg.surface[r.id])<.01,"Surface evidence drift")
    source[r.id]=s
end
local changedCells={}
local function paint(r,corners)
    local d=r.painted
    for i=2,5 do for k=2,5 do
        local corner=(i==2 or i==5) and (k==2 or k==5)
        if corner~=corners then continue end
        local top=0;local wet=false
        for j=1,36 do
            if d.SolidOccupancy[i][j][k]>.02 then top=j end
            if d.LiquidOccupancy[i][j][k]>.02 then wet=true end
        end
        if wet or top==0 then continue end
        local mat=d.SolidMaterial[i][top][k]
        if mat~=Enum.Material.Grass and mat~=Enum.Material.Ground then continue end
        local ys={}
        for j=math.max(1,top-1),top do
            if d.SolidMaterial[i][j][k]==Enum.Material.Grass then d.SolidMaterial[i][j][k]=Enum.Material.Ground;table.insert(ys,j) end
        end
        if #ys>0 then
            local x,z=r.x-12+(i-1)*4,r.z-12+(k-1)*4
            local key=x..":"..z;assert(not changedCells[key],"Duplicate paint column")
            changedCells[key]={x=x,z=z,patch=r.id,indices=ys,from="Grass",to="Ground"}
        end
    end end
    clearRestore(r.region,d)
end
for _,r in regions0 do paint(r,false) end
task.wait(1)
local function grassCount()
    local centers,foot=0,0
    for _,r in cfg.rows do
        local original=F:FindFirstChild(r.id)
        local m=original:Clone();assert(m,"Scale preview clone")
        if r.category=="stick" then m:ScaleTo(original:GetScale()*2) end
        local s=measure(m);m:Destroy()
        if s.center.material=="Grass" then centers+=1 end;foot+=s.grass
    end
    return centers,foot
end
local crossCenters,crossFoot=grassCount()
local mode="cross_ring"
if crossFoot>0 then
    for _,r in regions0 do paint(r,true) end
    task.wait(1)
    mode="full_ring"
end
local finalCenters,finalFoot=grassCount()
local modifiedTerrain=terrainState()
local changedTiles=0
for i,r in modifiedTerrain do
    assert(r.solidVoxels==before[i].solidVoxels and r.waterVoxels==before[i].waterVoxels,"Volume changed")
    if r.digest~=before[i].digest then changedTiles+=1 end
end
local originals,clones,out={},{},{}
-- Place stones first; then choose a deterministic dry, low-relief, non-overlapping support for sticks.
local ordered=table.clone(cfg.rows)
table.sort(ordered,function(a,b) if a.category~=b.category then return a.category=="stone" end return a.id<b.id end)
local candidateParams=OverlapParams.new();candidateParams.FilterType=Enum.RaycastFilterType.Include;candidateParams.FilterDescendantsInstances={F}
local function fits(m)
    local cf,size=m:GetBoundingBox()
    for _,part in W:GetPartBoundsInBox(cf,size,candidateParams) do
        local other=part:FindFirstAncestorOfClass("Model")
        if other and other~=m and other.Parent==F then return false end
    end
    return true
end
for _,r in ordered do
    local old=F:FindFirstChild(r.id);local s=measure(old);local pivot=old:GetPivot()
    local surfaceDelta=s.center.y-source[r.id].center.y
    -- Material interpolation can shift the physical mesh slightly even with identical occupancy.
    -- Measure after paint; reject large shifts instead of assuming the ray surface is unchanged.
    assert(math.abs(surfaceDelta)<.25,string.format("Material surface delta %s %.5f",r.id,surfaceDelta))
    local originalDy=s.high+.01-s.bottom
    assert(originalDy>1.8 and originalDy<2.3,"Correction outside measured support")
    local m=old:Clone();assert(m,"Clone")
    local oldScale=old:GetScale()
    local targetScale=oldScale*(r.category=="stick" and 2 or 1)
    m:ScaleTo(targetScale)
    table.insert(originals,old);old.Parent=nil
    local scaled,dy,chosen,chosenYaw,chosenOffset
    local bestGap=math.huge
    local offsets={Vector3.zero}
    local yaws={0}
    if r.category=="stick" then
        for _,deg in {15,-15,30,-30,45,-45,60,-60,75,-75,90} do table.insert(yaws,deg) end
        for _,dist in {.5,1,1.5,2} do
            for _,angle in {0,45,90,135,180,225,270,315} do
                local rad=math.rad(angle);table.insert(offsets,Vector3.new(math.cos(rad)*dist,0,math.sin(rad)*dist))
            end
        end
    end
    for _,offset in offsets do
        for _,yaw in yaws do
            local candidate=CFrame.new(pivot.Position+offset)*CFrame.Angles(0,math.rad(yaw),0)*pivot.Rotation
            m:PivotTo(candidate)
            local support=measure(m)
            local gap=support.high-support.low+.01
            bestGap=math.min(bestGap,gap)
            if gap>=.22 or support.grass>0 then continue end
            local lift=support.high+.01-support.bottom
            m:PivotTo(candidate+Vector3.new(0,lift,0))
            if not fits(m) then continue end
            scaled,dy,chosen,chosenYaw,chosenOffset=support,lift,candidate,yaw,offset
            break
        end
        if chosen then break end
    end
    assert(chosen,string.format("No valid support for %s; minimum sampled gap %.4f",r.id,bestGap))
    m:PivotTo(chosen+Vector3.new(0,dy,0))
    m:SetAttribute("RSVoxelGroundY",r.groundY);m:SetAttribute("RSExpectedGroundY",scaled.center.y)
    m:SetAttribute("RSBuriedDepth",0);m:SetAttribute("RSContactMethod","native_terrain_ray")
    m.Parent=F;table.insert(clones,m)
    local placed=measure(m);local p=m:GetPivot().Position
    assert(placed.bottom-placed.high>=.005 and placed.bottom-placed.high<=.025,"Support contact")
    assert(placed.bottom-placed.low<.22 and placed.grass==0,"Excessive floating or grass support")
    assert((Vector3.new(p.X,0,p.Z)-Vector3.new(pivot.X,0,pivot.Z)).Magnitude<=(r.category=="stick" and 2.001 or .001) and math.abs(m:GetScale()-targetScale)<.00001,"Unexpected position or scale change")
    local part=m:FindFirstChildWhichIsA("MeshPart",true);assert(part and part.Anchored and part.CanCollide and part.CanQuery and part.CollisionGroup=="RSNaturalResource","Resource policy")
    table.insert(out,{id=r.id,category=r.category,from={pivot.X,pivot.Y,pivot.Z},to={p.X,p.Y,p.Z},deltaY=dy,offset={chosenOffset.X,chosenOffset.Z},yawAdjustment=chosenYaw,oldScale=oldScale,targetScale=targetScale,actualScale=m:GetScale(),scaleRatio=m:GetScale()/oldScale,paintSurfaceDelta=surfaceDelta,groundY=placed.center.y,highY=placed.high,lowY=placed.low,baseGap=placed.bottom-placed.high,maxGap=placed.bottom-placed.low,topGap=placed.top-placed.high,material=placed.center.material,grassSamples=placed.grass,burial=0})
end
-- Verify grass and conservative bounding-box overlap after all clones exist.
local overlapPairs={}
local overlapSeen={}
local params=OverlapParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={F}
for _,m in clones do
    local cf,size=m:GetBoundingBox()
    for _,part in W:GetPartBoundsInBox(cf,size,params) do
        local other=part:FindFirstAncestorOfClass("Model")
        if other and other~=m and other.Parent==F then
            local a,b=m.Name,other.Name;if a>b then a,b=b,a end
            local k=a.."|"..b
            if not overlapSeen[k] then overlapSeen[k]=true;table.insert(overlapPairs,{a=a,b=b}) end
        end
    end
end
assert(#overlapPairs==0,"Resource overlap after placement")
local count=0;local paintRows={}
for _,r in changedCells do count+=1;table.insert(paintRows,r) end
table.sort(paintRows,function(a,b)return a.x==b.x and a.z<b.z or a.x<b.x end)
for _,m in clones do m:Destroy() end
for _,m in originals do m.Parent=F end
for _,r in regions0 do write(r.region,r.original) end
task.wait(1)
local restored=terrainState()
for i,r in restored do assert(r.digest==before[i].digest and r.solidVoxels==before[i].solidVoxels and r.waterVoxels==before[i].waterVoxels,"Terrain inverse") end
assert(rootHash()==originalRoot,"Resource inverse")
return syncResult({rows=out,overlapPairs=overlapPairs,extraPaint=paintRows,extraPaintColumns=count,paintMode=mode,crossGrassCenters=crossCenters,crossGrassSamples=crossFoot,finalGrassCenters=finalCenters,finalGrassSamples=finalFoot,changedTiles=changedTiles,expectedTerrain=modifiedTerrain,all49Restored=#restored==49,resourceInverse=true,noPlaceWrites=true,clientRenderVerified=false})
