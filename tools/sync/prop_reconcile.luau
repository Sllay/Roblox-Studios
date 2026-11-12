-- __RS_SUPPORT__
-- Reconcile reviewed ground-mounted props in a registered native Terrain tile.
-- Painting is inspection-only; sculpting can apply vertical corrections.
local T=workspace.Terrain
local b=cfg.region.bounds
local lo=Vector3.new(b[1]-8,b[2],b[3]-8)
local hi=Vector3.new(b[4]+8,b[5],b[6]+8)
local nx,ny,nz=(hi.X-lo.X)/4,(hi.Y-lo.Y)/4,(hi.Z-lo.Z)/4
local ch={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local d=T:ReadVoxelChannels(Region3.new(lo,hi),4,ch)
local blob=buffer.create((nx-4)*ny*(nz-4)*6)
local at=0
for x=3,nx-2 do for y=1,ny do for z=3,nz-2 do
    buffer.writeu16(blob,at,math.round(d.SolidOccupancy[x][y][z]*65535))
    buffer.writeu16(blob,at+2,math.round(d.LiquidOccupancy[x][y][z]*65535))
    buffer.writeu16(blob,at+4,d.SolidMaterial[x][y][z].Value);at+=6
end end end
local terrainDigest=buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(blob,Enum.HashAlgorithm.Sha256)))
assert(terrainDigest==cfg.terrainDigest,"Terrain changed")
local grid={}
for x=1,nx do
    grid[x]={}
    for z=1,nz do
        local c={wet=false,height=nil,material="Air"}
        for y=1,ny do
            local o,w=d.SolidOccupancy[x][y][z],d.LiquidOccupancy[x][y][z]
            if w>0.02 then c.wet=true end
            if o>0.02 then c.height=lo.Y+(y-1+o)*4;c.material=d.SolidMaterial[x][y][z].Name end
        end
        grid[x][z]=c
    end
end
local function atCell(x,z)
    local i,j=math.floor((x-lo.X)/4)+1,math.floor((z-lo.Z)/4)+1
    return grid[i] and grid[i][j]
end
local function heightAt(x,z)
    local gx,gz=(x-lo.X)/4+0.5,(z-lo.Z)/4+0.5
    local i,j=math.floor(gx),math.floor(gz)
    if i<1 or j<1 or i>=nx or j>=nz then return nil end
    local a,c,f,g=grid[i][j],grid[i+1][j],grid[i][j+1],grid[i+1][j+1]
    for _,v in {a,c,f,g} do
        if v.wet or v.height==nil or (cfg.intent=="sculpt" and v.material~="Grass") then return nil end
    end
    local tx,tz=gx-i,gz-j
    return (a.height+(c.height-a.height)*tx)*(1-tz)+(f.height+(g.height-f.height)*tx)*tz
end
local function same(a,c)
    if typeof(a)~=typeof(c) then return false end
    if typeof(a)=="number" then return math.abs(a-c)<0.005 end
    if typeof(a)~="table" then return a==c end
    for k,v in a do if not same(v,c[k]) then return false end end
    for k in c do if a[k]==nil then return false end end
    return true
end
local function inTile(p)
    return p.X>=b[1] and p.X<b[4] and p.Z>=b[3] and p.Z<b[6]
end
local rows,objects={},{}
local counts={unchanged=0,move=0,review=0,materialReview=0,unmanaged=0}
local known={}
for _,name in {"RSManagedAssets","RSSceneBuilder","RSWorldVegetation"} do
    local root=workspace:FindFirstChild(name)
    if root then
        known[root]=true
        local models=if name=="RSManagedAssets" then root else root:FindFirstChild("Models")
        local colliders=root:FindFirstChild("Collisions")
        assert(models,"Managed model folder missing")
        for _,m in models:GetChildren() do
            if not m:IsA("Model") or not inTile(m:GetPivot().Position) then continue end
            local p=m:GetPivot()
            local id=m:GetAttribute("RSManagedId")
            local burial=m:GetAttribute("RSBuriedDepth")
            local radius=m:GetAttribute("RSSupportRadius")
            local row={root=name,name=m.Name,id=if typeof(id)=="string" then id else "",before=vec(p.Position),status="review"}
            local c=atCell(p.Position.X,p.Position.Z)
            row.material=if c then c.material else "Air"
            if row.material~="Grass" then counts.materialReview+=1 end
            local pitch,yaw,roll=p:ToOrientation()
            if typeof(id)=="string" and typeof(burial)=="number" and typeof(radius)=="number" and radius<=6 and math.abs(pitch)<0.01 and math.abs(roll)<0.01 then
                local ok,target,ground=pcall(supportTarget,m,p.Position.X,p.Position.Z,math.deg(yaw),burial,radius,heightAt)
                if ok then
                    row.after=vec(target.Position);row.ground=ground;row.burial=burial;row.radius=radius
                    local delta=target.Position-p.Position
                    row.status=if math.abs(delta.Y)<=0.15 then "unchanged" elseif cfg.intent=="paint" then "review" else "move"
                    row.deltaY=delta.Y
                    local collider=colliders and colliders:FindFirstChild(m.Name)
                    if collider then
                        assert(collider:IsA("BasePart") and collider.Anchored and collider.CanCollide,"Invalid coupled collider")
                        row.colliderBefore=vec(collider.Position);row.colliderAfter=vec(collider.Position+delta)
                    end
                    objects[id]={model=m,collider=collider,cf=target,ground=ground,burial=burial,radius=radius}
                else row.reason=tostring(target) end
            else row.reason="Missing reviewed contact profile or unsupported orientation" end
            counts[row.status]+=1;table.insert(rows,row)
        end
    end
end
-- Manual external props are never silently moved. Ask for a contact profile.
for _,obj in workspace:GetChildren() do
    if not known[obj] and (obj:IsA("Model") or (obj:IsA("BasePart") and not obj:IsA("Terrain") and not obj:IsA("SpawnLocation"))) then
        local p=if obj:IsA("Model") then obj:GetPivot().Position else obj.Position
        if inTile(p) then counts.unmanaged+=1;table.insert(rows,{name=obj.Name,root="Workspace",id="",status="review",reason="External object needs adoption/contact profile",before=vec(p)}) end
    end
end
table.sort(rows,function(a,c) return a.root.."/"..a.name<c.root.."/"..c.name end)
local function output(v) v.universeId=tostring(game.GameId);v.placeId=tostring(game.PlaceId);return Http:JSONEncode(v) end
if cfg.mode=="preview" then return output({rows=rows,counts=counts,terrainDigest=terrainDigest,region=cfg.region.id,intent=cfg.intent}) end
if cfg.mode=="verify" then
    assert(counts.move==0 and counts.review==0 and counts.unmanaged==0,"Persisted supports not reconciled")
    for _,expected in cfg.expectedRows do
        if expected.status=="move" then
            local o=objects[expected.id]
            assert(o and (o.model:GetPivot().Position-Vector3.new(table.unpack(expected.after))).Magnitude<0.025,"Model move not persisted")
            if expected.colliderAfter then assert(o.collider and (o.collider.Position-Vector3.new(table.unpack(expected.colliderAfter))).Magnitude<0.025,"Collider not persisted") end
        end
    end
    return output({verified=true,counts=counts,terrainDigest=terrainDigest})
end
assert(cfg.mode=="apply" and cfg.environment=="staging" and game.PlaceVersion==cfg.expectedVersion and cfg.intent=="sculpt","Write not authorized")
assert(same(rows,cfg.expectedRows),"Reviewed placement plan changed")
assert(counts.review==0 and counts.unmanaged==0 and counts.move>0,"Resolve invalid supports before saving")
for _,row in rows do
    if row.status=="move" then
        local o=objects[row.id]
        moveSupported(o.model,o.collider,o.cf,o.ground,o.burial,o.radius)
    end
end
game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false})
return output({saved=true,moved=counts.move,terrainDigest=terrainDigest})
