-- World test migration: shared continuous field, native voxel channels.
-- __RS_SUPPORT__
local W=workspace
local T=W.Terrain
local SS=game:GetService("ServerStorage")
local SSS=game:GetService("ServerScriptService")
local Lighting=game:GetService("Lighting")
local plan=cfg.plan
local ch={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local function readRegion(b)
    return T:ReadVoxelChannels(Region3.new(Vector3.new(b[1],b[2],b[3]),Vector3.new(b[4],b[5],b[6])),4,ch)
end
local function digest(d,nx,ny,nz)
    local blob=buffer.create(nx*ny*nz*6);local at=0
    for x=1,nx do for y=1,ny do for z=1,nz do
        buffer.writeu16(blob,at,math.round(d.SolidOccupancy[x][y][z]*65535))
        buffer.writeu16(blob,at+2,math.round(d.LiquidOccupancy[x][y][z]*65535))
        buffer.writeu16(blob,at+4,d.SolidMaterial[x][y][z].Value);at+=6
    end end end
    return buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(blob,Enum.HashAlgorithm.Sha256)))
end
local function output(r) r.universeId=tostring(game.GameId);r.placeId=tostring(game.PlaceId);return Http:JSONEncode(r) end
local size=256
local n=320
local origin=-640
local ymin,ymax=plan.yMin,plan.yMax
local ny=(ymax-ymin)/4
local tiles={}
for tz=-2,2 do for tx=-2,2 do
    local x,z=tx*size-size/2,tz*size-size/2
    table.insert(tiles,{id=string.format("chunk-%d-%d",tx,tz),tx=tx,tz=tz,bounds={x,ymin,z,x+size,ymax,z+size},playable=math.abs(tx)<=1 and math.abs(tz)<=1})
end end
local function same(a,b)
    if typeof(a)~=typeof(b) then return false end
    if typeof(a)=="number" then return math.abs(a-b)<0.035 end
    if typeof(a)~="table" then return a==b end
    for k,v in a do if not same(v,b[k]) then return false end end
    for k in b do if a[k]==nil then return false end end
    return true
end
local function shape(m)
    local rows={}
    local scale=m:GetScale()
    for _,p in m:GetDescendants() do
        if p:IsA("MeshPart") then
            local relative={m:GetPivot():ToObjectSpace(p.CFrame):GetComponents()}
            for i=1,3 do relative[i]/=scale end
            local surfaces={}
            for _,c in p:GetChildren() do
                if c:IsA("SurfaceAppearance") then
                    local a={name=c.Name,color=rgb(c.Color),alpha=c.AlphaMode.Name,emissive=c.EmissiveStrength,maps={}}
                    for _,k in {"ColorMapContent","NormalMapContent","RoughnessMapContent","MetalnessMapContent","EmissiveMaskContent"} do
                        local ok,v=pcall(function() return c[k] end)
                        a.maps[k]=if ok then {source=v.SourceType.Name,uri=v.Uri or ""} else {unreadable=true}
                    end
                    table.insert(surfaces,a)
                end
            end
            table.sort(surfaces,function(a,b) return a.name<b.name end)
            table.insert(rows,{name=p.Name,mesh=p.MeshId,texture=p.TextureID,color=rgb(p.Color),material=p.Material.Name,relative=relative,size=vec(p.Size/scale),surfaces=surfaces})
        end
    end
    table.sort(rows,function(a,b) return a.name<b.name end)
    assert(#rows==2,"Unexpected mesh count")
    return rows
end
local function verifyWorld()
    local observed={}
    for _,tile in tiles do
        local d=readRegion(tile.bounds)
        local hashValue=digest(d,64,ny,64)
        assert(hashValue==cfg.expectedTiles[tile.id],"Tile digest changed: "..tile.id)
        observed[tile.id]=hashValue
    end
    local root=W:FindFirstChild("RSWorldVegetation")
    local sp=W:FindFirstChild("RSCentralSpawns")
    local scriptObj=SSS:FindFirstChild("RSCentralSpawnSafety")
    local ui=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):FindFirstChild("RSQualityPanel")
    assert(root and root:GetAttribute("RSOwner")=="RSWorldV1" and sp and #sp:GetChildren()==cfg.expectedSpawns,"World roots missing")
    local policy=SSS:FindFirstChild("RSGameplayPolicy")
    assert(scriptObj and scriptObj.Source==cfg.runtimeSource and ui and ui.Source==cfg.clientSource and policy and policy:IsA("ModuleScript") and policy.Source==cfg.policySource,"Runtime source mismatch")
    local clouds=T:FindFirstChild("RSWorldClouds")
    assert(clouds and clouds:IsA("Clouds") and clouds.Enabled,"Clouds missing")
    local models=root:FindFirstChild("Models");local colliders=root:FindFirstChild("Collisions")
    assert(#models:GetChildren()==cfg.expectedPlants and #colliders:GetChildren()==cfg.expectedColliders,"Plant count mismatch")
    local roots={W.RSManagedAssets,W.RSSceneBuilder.Models,models}
    for _,r in cfg.expectedProps do
        local m=roots[r.group]:FindFirstChild(r.name)
        assert(m and m:IsA("Model") and (m:GetPivot().Position-Vector3.new(table.unpack(r.position))).Magnitude<0.025,"Prop placement mismatch: "..r.name)
        assert(math.abs(m:GetScale()-r.scale)<0.001 and math.abs(m:GetAttribute("RSBuriedDepth")-r.burial)<0.01,"Prop profile mismatch")
        local mesh=0
        for _,p in m:GetDescendants() do if p:IsA("MeshPart") then mesh+=1;assert(p.Anchored and not p.CanCollide and not p.CanTouch,"Visual physics changed") end end
        assert(mesh==2 and same(shape(m),r.shape),"Model geometry/PBR mismatch")
        if r.collider then
            local folder=if r.group==2 then W.RSSceneBuilder.Collisions else colliders
            local c=folder:FindFirstChild(r.name)
            assert(c and c.CanCollide and c.Anchored and (c.Position-Vector3.new(table.unpack(r.collider))).Magnitude<0.03,"Collider mismatch")
        end
    end
    assert(not W:FindFirstChild("Baseplate") and not W:FindFirstChild("SpawnLocation"),"Old defaults reappeared")
    return output({verified=true,tiles=observed,plants=#models:GetChildren(),spawns=#sp:GetChildren(),colliders=#colliders:GetChildren(),props=#cfg.expectedProps})
end
if cfg.mode=="verify" then return verifyWorld() end
assert(cfg.environment=="staging" and game.PlaceVersion==plan.expectedVersion,"Version changed")
assert(not W:FindFirstChild("RSWorldVegetation") and not T:FindFirstChild("RSWorldClouds"),"World name collision")
local oldPilot=readRegion({96,0,-128,352,64,128})
local oldCenter=readRegion({-352,-16,-128,96,64,128})
assert(digest(oldPilot,64,16,64)==plan.pilotDigest and digest(oldCenter,112,20,64)==plan.centerDigest,"Old terrain changed")
-- Known previous roots only; don't silently replace new manual objects.
for _,obj in W:GetChildren() do
    assert(obj:IsA("Camera") or obj==T or obj.Name=="RSManagedAssets" or obj.Name=="RSSceneBuilder" or obj.Name=="RSCentralSpawns","Unexpected Workspace root "..obj.Name)
end
local function smooth(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function mix(a,b,t) return a+(b-a)*t end
local function dist(x,z,a,c)
    local dx,dz=c[1]-a[1],c[2]-a[2]
    local t=math.clamp(((x-a[1])*dx+(z-a[2])*dz)/(dx*dx+dz*dz),0,1)
    return math.sqrt((x-a[1]-dx*t)^2+(z-a[2]-dz*t)^2)
end
local function pathDist(x,z,points)
    local d=math.huge
    for i=1,#points-1 do d=math.min(d,dist(x,z,points[i],points[i+1])) end
    return d
end
local function oldColumn(x,z)
    if z< -128 or z>=128 or x<96 or x>=352 then return nil end
    local ix,iz=math.floor((x-96)/4)+1,math.floor((z+128)/4)+1
    local h,w,mat=0,nil,Enum.Material.Grass
    for y=1,16 do
        local s,l=oldPilot.SolidOccupancy[ix][y][iz],oldPilot.LiquidOccupancy[ix][y][iz]
        if s>0.02 then h=(y-1+s)*4;mat=oldPilot.SolidMaterial[ix][y][iz] end
        if l>0.02 then w=math.max(w or 0,(y-1+s+l)*4) end
    end
    return {height=h,water=w,material=mat,ix=ix,iz=iz}
end
local function baseHeight(x,z)
    local noise=math.noise(x/160,z/160,plan.seed*0.001)*14+math.noise(x/55,z/55,plan.seed*0.002)*5
    local valley=18+noise+math.clamp((z+100)/400,0,1)*7
    local far=math.max(math.abs(x),math.abs(z))
    local mountains=smooth((far-320)/220)*(36+math.noise(x/115,z/115,plan.seed*0.003)*42+math.noise(x/43,z/43,19)*10)
    return math.clamp(valley+mountains,5,95)
end
local river=plan.river
local field={}
local counts={water=0,river=0,preserved=0,grass=0,path=0,sand=0}
for i=1,n do
    field[i]={}
    for j=1,n do
        local x,z=origin+(i-0.5)*4,origin+(j-0.5)*4
        local h=baseHeight(x,z)
        local old=oldColumn(x,z)
        local mat=Enum.Material.Grass
        local water=nil
        local preserve=false
        if old then h=old.height;mat=old.material;water=old.water;preserve=true
        else
            -- Blend outward from the existing rectangular pilot, preserving the seam.
            local ox,oz=math.clamp(x,98,350),math.clamp(z,-126,126)
            local d=math.sqrt((x-ox)^2+(z-oz)^2)
            if d<48 then
                local edge=oldColumn(ox,oz)
                if edge then h=mix(edge.height,h,smooth((d-4)/44)) end
            end
        end
        local d=pathDist(x,z,river.points)
        local sourceD=math.sqrt((x-river.points[1][1])^2+(z-river.points[1][2])^2)
        local width=river.halfWidth+3*math.noise(x/50,z/50,9)
        if sourceD<river.sourceRadius then width=math.max(width,river.sourceRadius) end
        local level=mix(river.lakeLevel,river.sourceLevel,math.clamp((z-60)/240,0,1))
        -- Preserve actual original lake water. Only the incoming corridor modifies dry pilot.
        if not water and z>=44 and z<=316 and d<width+river.bankWidth+20 then
            local q=d-width
            if q<0 then
                h=level-river.depth*math.max(0.18,1-smooth(d/width))
                water=level;mat=Enum.Material.Sand;preserve=false;counts.river+=1
            elseif q<river.bankWidth then
                h=level+2+3*smooth(q/river.bankWidth);mat=if q<5 then Enum.Material.Sand else Enum.Material.Grass;preserve=false
            else
                h=mix(level+5,h,smooth((q-river.bankWidth)/20));preserve=false
            end
        end
        if not water then
            for _,p in plan.paths do
                if pathDist(x,z,p)<=6 and (z<44 or d>width+river.bankWidth) then mat=Enum.Material.Ground;break end
            end
        end
        field[i][j]={h=h,w=water,mat=mat,old=old,preserve=preserve}
    end
end
-- Containment: every adjacent dry column reaches the highest nearby water plane.
-- No holes underneath any column; levels are bounded and water is never floating.
for i=2,n-1 do for j=2,n-1 do
    local c=field[i][j]
    if c.w then
        for _,off in {{1,0},{-1,0},{0,1},{0,-1}} do
            local a=field[i+off[1]][j+off[2]]
            if not a.w and a.h<c.w then a.h=c.w+0.5;a.preserve=false;a.mat=Enum.Material.Sand end
        end
    end
end end
local seenWater={}
local queue={}
local lakeX,lakeZ=math.floor((224-origin)/4)+1,math.floor((28-origin)/4)+1
assert(field[lakeX][lakeZ].w,"Lake missing")
table.insert(queue,{lakeX,lakeZ});seenWater[lakeX*n+lakeZ]=true
local qi=1
while qi<=#queue do
    local a=queue[qi];qi+=1
    for _,off in {{1,0},{-1,0},{0,1},{0,-1}} do
        local i,j=a[1]+off[1],a[2]+off[2]
        local k=i*n+j
        if i>=1 and i<=n and j>=1 and j<=n and field[i][j].w and not seenWater[k] then seenWater[k]=true;table.insert(queue,{i,j}) end
    end
end
for i=1,n do for j=1,n do
    local c=field[i][j]
    assert(c.h>ymin+8 and c.h<ymax-4,"Height budget")
    if c.w then
        counts.water+=1;assert(seenWater[i*n+j] and c.h<c.w and i>1 and i<n and j>1 and j<n,"Disconnected/unsupported water")
    end
    if c.preserve then counts.preserved+=1 end
    if c.mat==Enum.Material.Grass then counts.grass+=1 elseif c.mat==Enum.Material.Ground then counts.path+=1 elseif c.mat==Enum.Material.Sand then counts.sand+=1 end
end end
assert(counts.river>100 and counts.water==#queue,"River not connected")
local function cell(x,z)
    local i,j=math.floor((x-origin)/4)+1,math.floor((z-origin)/4)+1
    return field[i] and field[i][j]
end
local function heightAt(x,z)
    local gx,gz=(x-origin)/4+0.5,(z-origin)/4+0.5
    local i,j=math.floor(gx),math.floor(gz)
    if i<1 or i>=n or j<1 or j>=n then return nil end
    local a,b,c,d=field[i][j],field[i+1][j],field[i][j+1],field[i+1][j+1]
    for _,v in {a,b,c,d} do if v.w or v.mat~=Enum.Material.Grass then return nil end end
    return mix(mix(a.h,b.h,gx-i),mix(c.h,d.h,gx-i),gz-j)
end
local function clear(x,z,r)
    for dx=-r,r,4 do for dz=-r,r,4 do
        if dx*dx+dz*dz<=r*r then
            local c=cell(x+dx,z+dz)
            if not c or c.w or c.mat~=Enum.Material.Grass then return false end
        end
    end end
    return heightAt(x,z)~=nil
end
local function knownOld(x,y,z)
    return z>=-128 and z<128 and ((x>=-352 and x<96 and y>=-16 and y<64) or (x>=96 and x<352 and y>=0 and y<64))
end
-- Full preflight of new voxels: refuse unknown terrain in the bounded world.
for _,tile in tiles do
    local b=tile.bounds;local d=readRegion(b)
    for x=1,64 do for y=1,ny do for z=1,64 do
        if d.SolidOccupancy[x][y][z]>0 or d.LiquidOccupancy[x][y][z]>0 then
            assert(knownOld(b[1]+(x-0.5)*4,ymin+(y-0.5)*4,b[3]+(z-0.5)*4),"Unknown existing terrain in "..tile.id)
        end
    end end end
end
local oldForest=W.RSSceneBuilder
assert(oldForest:GetAttribute("RSOwner")=="RSSceneBuilderV1","Forest owner")
local original=W.RSManagedAssets:FindFirstChild("yasu-tree-01")
assert(original and original:IsA("Model"),"Missing original tree")
local props={}
local occupied={}
local function yawOf(m)
    local _,yaw,_=m:GetPivot():ToOrientation();return math.deg(yaw)
end
local function addPlacement(m,group,x,z,yaw,burial,radius,collider)
    local cf,h=supportTarget(m,x,z,yaw,burial,radius,heightAt)
    local pos=vec(cf.Position)
    local row={name=m.Name,group=group,position=pos,yaw=yaw,scale=m:GetScale(),burial=burial,radius=radius,ground=h,shape=shape(m)}
    if collider then row.collider=vec(collider.Position+cf.Position-m:GetPivot().Position) end
    table.insert(props,row);table.insert(occupied,{x=x,z=z})
    return row
end
local function isSpaced(x,z,spacing)
    for _,p in occupied do if (x-p.x)^2+(z-p.z)^2<spacing^2 then return false end end
    return true
end
local function placeExisting(m,group,collider,burial,radius)
    local p=m:GetPivot().Position
    local x,z=p.X,p.Z
    local yaw=yawOf(m)
    local ok=clear(x,z,6) and pcall(supportTarget,m,x,z,yaw,burial,radius,heightAt)
    if not ok then
        local found=false
        for r=8,80,4 do
            for a=0,15 do
                local nx2,nz2=x+math.cos(a*math.pi/8)*r,z+math.sin(a*math.pi/8)*r
                if clear(nx2,nz2,7) and isSpaced(nx2,nz2,12) and pcall(supportTarget,m,nx2,nz2,yaw,burial,radius,heightAt) then x,z=nx2,nz2;found=true;break end
            end
            if found then break end
        end
        assert(found,"No valid relocation for "..m.Name)
    end
    return addPlacement(m,group,x,z,yaw,burial,radius,collider)
end
placeExisting(original,1,nil,plan.vegetation.isolatedTreeBurial,2)
local oldModels=oldForest.Models:GetChildren()
table.sort(oldModels,function(a,b) return a.Name<b.Name end)
for _,m in oldModels do
    assert(m:IsA("Model") and m:GetAttribute("RSManagedId"),"Unexpected old forest object")
    placeExisting(m,2,oldForest.Collisions:FindFirstChild(m.Name),m:GetAttribute("RSBuriedDepth"),m:GetAttribute("RSSupportRadius"))
end
local templates={oldForest.Models:FindFirstChild("forest-tree_01-01"),oldForest.Models:FindFirstChild("forest-tree_08-01"),oldForest.Models:FindFirstChild("forest-bush_01-01")}
for _,m in templates do assert(m and m:IsA("Model") and m:GetAttribute("RSModelDigest"),"Audited template missing") end
local rng=Random.new(plan.seed)
local newRoot=Instance.new("Folder");newRoot.Name="RSWorldVegetation";newRoot:SetAttribute("RSOwner","RSWorldV1")
local models=Instance.new("Folder");models.Name="Models";models.Parent=newRoot
local colliders=Instance.new("Folder");colliders.Name="Collisions";colliders.Parent=newRoot
local newCount,horizonCount,colliderCount=0,0,0
for _,tile in tiles do
    local b=tile.bounds
    local target=if tile.playable then (if tile.tx==0 and tile.tz==0 then 6 else 10) else (if (tile.tx+tile.tz)%2==0 then 2 else 1)
    for attempt=1,250 do
        if target<=0 then break end
        local x,z=rng:NextNumber(b[1]+12,b[4]-12),rng:NextNumber(b[3]+12,b[6]-12)
        if x>=88 and x<=360 and z>=-136 and z<=136 then continue end
        if x*x+z*z<45*45 or not clear(x,z,10) or not isSpaced(x,z,plan.vegetation.minSpacing) then continue end
        local species=rng:NextInteger(1,3)
        local m=templates[species]:Clone()
        local scale=if species==3 then rng:NextNumber(0.8,1.1) else rng:NextNumber(0.6,0.95)
        m:ScaleTo(scale)
        local burial=({3.5,3,0.8})[species]*scale
        local yaw=rng:NextInteger(0,359)
        local ok,cf,h=pcall(supportTarget,m,x,z,yaw,burial,2*scale,heightAt)
        if not ok then m:Destroy();continue end
        newCount+=1;target-=1
        if not tile.playable then horizonCount+=1 end
        m.Name=string.format("world-%03d",newCount)
        for k in m:GetAttributes() do m:SetAttribute(k,nil) end
        m:SetAttribute("RSManagedId",m.Name);m:SetAttribute("RSAssetId","79689531752352");m:SetAttribute("RSModelDigest",templates[species]:GetAttribute("RSModelDigest"))
        m:SetAttribute("RSExpectedGroundY",h);m:SetAttribute("RSBuriedDepth",burial);m:SetAttribute("RSSupportRadius",2*scale);m:SetAttribute("RSSpecies",({"Tree_01","Tree_08","Bush_01"})[species])
        m:PivotTo(cf);m.Parent=models
        local c=nil
        if species~=3 and tile.playable then
            c=Instance.new("Part");c.Name=m.Name;c.Shape=Enum.PartType.Cylinder;c.Size=Vector3.new(8*scale,2.4*scale,2.4*scale)
            c.CFrame=CFrame.new(x,h+4*scale,z)*CFrame.Angles(0,0,math.pi/2);c.Anchored=true;c.Transparency=1;c.CanCollide=true;c.CanTouch=false;c.CastShadow=false;c.Parent=colliders
            c:SetAttribute("RSOwner","RSWorldV1");colliderCount+=1
        end
        local row={name=m.Name,group=3,position=vec(cf.Position),yaw=yaw,scale=scale,burial=burial,radius=2*scale,ground=h,shape=shape(m)}
        if c then row.collider=vec(c.Position) end
        table.insert(props,row);table.insert(occupied,{x=x,z=z})
        assert(#props<=plan.maxModels,"Vegetation budget")
    end
end
assert(newCount>=60 and horizonCount>=12,"Insufficient world vegetation")
local spawns={}
for z=-96,96,24 do for x=-96,96,24 do
    if x*x+z*z<=plan.spawnRadius^2 and clear(x,z,6) and isSpaced(x,z,9) then
        local h=heightAt(x,z)
        local good=true
        for _,off in {{4,0},{-4,0},{0,4},{0,-4}} do local y=heightAt(x+off[1],z+off[2]);if not y or math.abs(y-h)>1.5 then good=false end end
        if good then table.insert(spawns,{x,h+2,z}) end
    end
end end
assert(#spawns>=20,"Insufficient spawn candidates")
local function compileTile(tile)
    local b=tile.bounds
    local d={SolidMaterial={},SolidOccupancy={},LiquidOccupancy={}}
    for x=1,64 do
        for _,k in ch do d[k][x]={};for y=1,ny do d[k][x][y]={} end end
        for z=1,64 do
            local c=cell(b[1]+(x-0.5)*4,b[3]+(z-0.5)*4)
            for y=1,ny do
                local bottom=ymin+(y-1)*4
                local s=math.clamp((c.h-bottom)/4,0,1)
                local w=if c.w then math.min(1-s,math.clamp((c.w-bottom)/4,0,1)) else 0
                local mat=if s==0 then Enum.Material.Air elseif bottom+4>=c.h-8 then c.mat elseif bottom+4>=c.h-16 then Enum.Material.Ground else Enum.Material.Rock
                -- Keep existing pilot voxel values unless the corridor/bank really changes them.
                if c.preserve and bottom>=0 and bottom<64 then
                    local oy=bottom/4+1
                    s=oldPilot.SolidOccupancy[c.old.ix][oy][c.old.iz];w=oldPilot.LiquidOccupancy[c.old.ix][oy][c.old.iz]
                    mat=oldPilot.SolidMaterial[c.old.ix][oy][c.old.iz]
                    if s>0 and bottom+4>=c.h-8 and c.mat~=c.old.material then mat=c.mat end
                end
                d.SolidOccupancy[x][y][z]=s;d.LiquidOccupancy[x][y][z]=w;d.SolidMaterial[x][y][z]=mat
                assert(s+w<=1.01,"Invalid occupancy")
            end
            assert(d.SolidOccupancy[x][1][z]>=0.999,"Foundation gap")
        end
    end
    return d
end
local map={}
for i=1,n,2 do
    local col={}
    for j=1,n,2 do local c=field[i][j];table.insert(col,{math.round(c.h),c.w~=nil,c.mat.Name}) end
    table.insert(map,col)
end
if cfg.mode=="preview" then
    newRoot:Destroy()
    return output({preview=true,counts=counts,tiles=tiles,plants=newCount,horizonPlants=horizonCount,colliders=colliderCount,spawns=spawns,props=props,map=map})
end
assert(cfg.mode=="apply","Unknown mode")
-- Same deterministic preview must match the exact intended layout.
assert(cfg.expectedPlants==newCount and cfg.expectedSpawns==#spawns and cfg.expectedColliders==colliderCount,"Preview count changed")
for i,row in props do
    local a=cfg.expectedProps[i]
    assert(a and a.name==row.name and a.group==row.group and (Vector3.new(table.unpack(a.position))-Vector3.new(table.unpack(row.position))).Magnitude<0.025,"Preview placement changed")
end
local hashes={}
local maxError=0
local paintedVoxels=0
local paintTiles=0
for _,tile in tiles do
    local d=compileTile(tile)
    local b=tile.bounds
    local r=Region3.new(Vector3.new(b[1],b[2],b[3]),Vector3.new(b[4],b[5],b[6]))
    -- Sculpt continuous solid/liquid geometry first. For the new road
    -- footprint, start with Grass then apply the material-only paint.
    local initialMat={}
    local changed=0
    for x=1,64 do
        initialMat[x]={}
        for y=1,ny do
            initialMat[x][y]={}
            for z=1,64 do
                local c=cell(b[1]+(x-0.5)*4,b[3]+(z-0.5)*4)
                local mat=d.SolidMaterial[x][y][z]
                if c.mat==Enum.Material.Ground and (not c.old or c.old.material~=Enum.Material.Ground) and mat==Enum.Material.Ground and ymin+y*4>=c.h-8 and d.SolidOccupancy[x][y][z]>0.02 then
                    initialMat[x][y][z]=Enum.Material.Grass;changed+=1
                else initialMat[x][y][z]=mat end
            end
        end
    end
    T:WriteVoxelChannels(r,4,{SolidMaterial=initialMat,SolidOccupancy=d.SolidOccupancy,LiquidOccupancy=d.LiquidOccupancy})
    local beforePaint=readRegion(b)
    local a=beforePaint
    if changed>0 then
        T:WriteVoxelChannels(r,4,{SolidMaterial=d.SolidMaterial})
        a=readRegion(b)
        for x=1,64 do for y=1,ny do for z=1,64 do
            assert(a.SolidOccupancy[x][y][z]==beforePaint.SolidOccupancy[x][y][z] and a.LiquidOccupancy[x][y][z]==beforePaint.LiquidOccupancy[x][y][z],"Paint changed geometry or liquid")
        end end end
        paintedVoxels+=changed;paintTiles+=1
    end
    for x=1,64 do for y=1,ny do for z=1,64 do
        maxError=math.max(maxError,math.abs(a.SolidOccupancy[x][y][z]-d.SolidOccupancy[x][y][z]),math.abs(a.LiquidOccupancy[x][y][z]-d.LiquidOccupancy[x][y][z]))
        if d.SolidOccupancy[x][y][z]>0.02 then assert(a.SolidMaterial[x][y][z]==d.SolidMaterial[x][y][z],"Material mismatch") end
    end end end
    assert(maxError<=0.02,"Voxel quantization error")
    hashes[tile.id]=digest(a,64,ny,64)
end
assert(paintedVoxels>0,"No paint performed")
-- Reanchor old props, preserving geometry, rotation and scale. Colliders follow.
for _,row in props do
    if row.group<3 then
        local m=if row.group==1 then original else oldForest.Models:FindFirstChild(row.name)
        local c=if row.group==2 then oldForest.Collisions:FindFirstChild(row.name) else nil
        local cf=CFrame.new(table.unpack(row.position))*CFrame.Angles(0,math.rad(row.yaw),0)
        moveSupported(m,c,cf,row.ground,row.burial,row.radius)
        assert(same(shape(m),row.shape),"Reanchoring changed geometry")
    end
end
newRoot.Parent=W
local oldSpawns=W.RSCentralSpawns
assert(oldSpawns:GetAttribute("RSOwner")=="RSSceneSyncV1","Spawn owner")
local archive=SS:FindFirstChild("RSSceneSyncArchive")
assert(archive and not archive:FindFirstChild("RSCentralSpawns"),"Archive collision")
oldSpawns.Parent=archive
local root=Instance.new("Folder");root.Name="RSCentralSpawns";root:SetAttribute("RSOwner","RSWorldV1")
for i,p in spawns do
    local s=Instance.new("SpawnLocation");s.Name=string.format("Valley_%02d",i);s.Size=Vector3.new(4,1,4);s.Position=Vector3.new(table.unpack(p))
    s.Anchored=true;s.Transparency=1;s.CanCollide=false;s.CanTouch=false;s.CanQuery=false;s.CastShadow=false;s.Duration=0;s.Neutral=true
    s:SetAttribute("RSSceneSyncId","world-spawn-"..i);s.Parent=root
end
root.Parent=W
local sc=SSS:FindFirstChild("RSCentralSpawnSafety")
assert(sc and sc:GetAttribute("RSOwner")=="RSSceneSyncV1","Old spawn script owner")
sc.Source=cfg.runtimeSource
assert(not SSS:FindFirstChild("RSGameplayPolicy"),"Policy collision")
local policy=Instance.new("ModuleScript");policy.Name="RSGameplayPolicy";policy.Source=cfg.policySource;policy.Parent=SSS
local sps=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
assert(not sps:FindFirstChild("RSQualityPanel"),"Quality panel collision")
local ui=Instance.new("LocalScript");ui.Name="RSQualityPanel";ui.Source=cfg.clientSource;ui.Parent=sps
local clouds=Instance.new("Clouds");clouds.Name="RSWorldClouds";clouds.Cover=plan.clouds.cover;clouds.Density=plan.clouds.density;clouds.Color=Color3.fromRGB(245,247,255);clouds.Parent=T
local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
assert(atmosphere,"Existing atmosphere missing")
atmosphere.Density=0.30;atmosphere.Haze=1.6;atmosphere.Offset=0.05
local dof=Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then dof.Enabled=false end
T.WaterColor=Color3.fromRGB(55,126,155);T.WaterTransparency=0.3;T.WaterWaveSize=0.12;T.WaterWaveSpeed=8
-- Natural distant mountains + bounded gameplay. No floor plate/void shortcut.
game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false})
return output({saved=true,tiles=hashes,plants=newCount,horizonPlants=horizonCount,colliders=colliderCount,spawns=#spawns,props=props,maxError=maxError,counts=counts,paintedVoxels=paintedVoxels,paintTiles=paintTiles,paintGeometryChanges=0,paintLiquidChanges=0})
