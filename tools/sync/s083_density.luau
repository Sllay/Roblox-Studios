-- S08.3 additive density generation; preserve every existing model and terrain.
local W=workspace
local T=W.Terrain
local A=game:GetService("AssetService")
local V=W.RSVegetationS06.Models
local C=W.RSVegetationS06.Collisions
local D=W.RSEnvironmentP4Detail.Models
local F=W.RSResourcesP45.Models
local L=W.RSFallenLogsS082
local E=W.RSEggydrasilS08
local verifying=cfg.mode=="verify"
assert(game.PlaceId==93428341652658 and game.GameId==10769712441 and game.PlaceVersion==(if verifying then 22 else 21),"Staging version")
assert(cfg.mode=="preview" or cfg.mode=="apply" or verifying,"Mode")
assert(#F:GetChildren()==1000 and #L:GetChildren()==250 and E:GetAttribute("RSManagedId")=="s08:Eggydrasil:central","Resource baseline")
local prefix="s083-"
local function new(o)return string.sub(o.Name,1,#prefix)==prefix end
local function isNew(o)
 local p=o
 while p and p~=W do
  if (p.Parent==V or p.Parent==C or p.Parent==D) and new(p) then return true end
  p=p.Parent
 end
 return false
end
local function canon(x)
 if typeof(x)~="table" then return Http:JSONEncode(x) end
 local keys={};for k in x do table.insert(keys,k) end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in keys do table.insert(out,Http:JSONEncode(tostring(k))..":"..canon(x[k])) end
 return "{"..table.concat(out,",").."}"
end
local function fingerprint()
 local rows={}
 for _,name in cfg.services do
  local svc=game:GetService(name)
  for _,o in svc:GetDescendants() do
   if not isNew(o) then
    local rec=record(svc,o)
    -- Existing folder records contain a direct child count; normalize only
    -- the explicitly authorized additions, not any other existing property.
    if o==V or o==C or o==D then
     for _,child in o:GetChildren() do if new(child) then rec.childCount-=1 end end
    end
    table.insert(rows,hash(canon(rec)))
   end
  end
 end
 table.sort(rows);return hash(table.concat(rows,";"))
end
local function q(n)return math.round(n*1000)/1000 end
local function v(p)return {q(p.X),q(p.Y),q(p.Z)} end
local function pose(cf)local a={cf:GetComponents()};for i,n in a do a[i]=q(n) end;return a end
local function kind(m)
 local s=m:GetAttribute("RSSpecies") or ""
 if string.sub(s,1,5)=="Pine_" then return "pine" end
 if string.sub(s,1,5)=="Tree_" then return "tree" end
 if string.sub(s,1,5)=="Bush_" then return "bush" end
 if s=="Mossy_Rock1_M_Mossy_Rock_0_Node" then return "rock" end
end
local function count()
 local c={tree=0,pine=0,bush=0,rock=0}
 local tiles={};local ids={};local rows={};local nc=0;local colliderCount=0
 for _,folder in {V,D} do
  for _,m in folder:GetChildren() do
   local k=kind(m)
   if k then
    assert(m:IsA("Model") and (folder==V or k=="rock"),"Managed type")
    c[k]+=1
    local id=m:GetAttribute("RSManagedId");assert(id==m.Name and not ids[id],"Identity "..m.Name);ids[id]=true
    local p=m:GetPivot().Position
    local tile="chunk-"..math.floor((p.X+128)/256).."-"..math.floor((p.Z+128)/256)
    tiles[tile]=tiles[tile] or {tree=0,pine=0,bush=0,rock=0};tiles[tile][k]+=1
    if new(m) then
     nc+=1
     assert(m:GetAttribute("RSChunk")==tile and m:GetAttribute("RSExpectedGroundY")~=nil,"New placement metadata")
     local parts={};local n=0
     for _,o in m:GetDescendants() do
      assert(not o:IsA("LuaSourceContainer"),"Clone script")
      if o:IsA("MeshPart") then
       assert(o.Anchored,"Clone anchored")
       if k=="rock" then assert(o.CanCollide and o.CanQuery and o.CollisionGroup=="Default","Rock policy") end
       n+=1;table.insert(parts,Http:JSONEncode({o.Name,o.MeshId,o.TextureID,v(o.Size),pose(o.CFrame),o.CanCollide,o.CanQuery}))
      end
     end
     assert(n>0)
     table.sort(parts)
     local cols={}
     if k=="tree" or k=="pine" then
      for _,name in {id,id.."-cap"} do
       local p=C:FindFirstChild(name);assert(p and p:IsA("Part") and p:GetAttribute("RSTreeId")==id and p.CanCollide and p.CanQuery and p.Anchored and p.Transparency==1,"Tree collider")
       table.insert(cols,{p.Name,v(p.Size),pose(p.CFrame),p.Shape.Name});colliderCount+=1
      end
     end
     table.insert(rows,Http:JSONEncode({id,k,m:GetAttribute("RSSpecies"),tile,pose(m:GetPivot()),q(m:GetScale()),parts,cols}))
    end
   end
  end
 end
 table.sort(rows);return c,tiles,nc,colliderCount,hash(table.concat(rows,";"))
end
local before=terrainState();assert(#before==49)
local originalFp=fingerprint()
if verifying then
 local c,tiles,n,cols,digest=count()
 assert(c.tree==250 and c.pine==16 and c.bush==200 and c.rock==150 and n==398 and cols==268,"Persisted totals")
 assert(digest==cfg.expectedDigest,"Persisted placement digest")
 for _,r in before do assert(cfg.expectedTerrain[r.id]==r.digest,"Terrain drift") end
 assert(originalFp==cfg.expectedFingerprint or originalFp==cfg.originalFingerprint,"Unrelated persisted changes")
 return syncResult({verified=true,noPlaceWrites=true,counts=c,tiles=tiles,newModels=n,newColliders=cols,digest=digest,terrain=before,clientRenderVerified=false})
end
local c0,tiles0,n0=count()
assert(c0.tree==120 and c0.pine==12 and c0.bush==80 and c0.rock==6 and n0==0,"Expected v21 population")
-- Preserve only the known controller auto-clone normalization already proven by S08.2.
-- Full scene hashes are compared before save and again on independent readback.
local sp=game:GetService("StarterPlayer")
local roots={};for _,o in sp:GetChildren() do if o.Name=="PlayerModule" and o:IsA("ModuleScript") then table.insert(roots,o) end end
local sounds=sp.StarterPlayerScripts:FindFirstChild("RbxCharacterSounds")
local binding=sounds and sounds:FindFirstChild("AtomicBinding");local leaves={}
if binding then for _,o in binding:GetChildren() do if o.Name=="AtomicBinding" and o:IsA("ModuleScript") then table.insert(leaves,o) end end end
local controllerNormalized=false
-- Roblox's save pipeline has repeatedly materialized the same two default
-- controller clones. Normalize only the exact known shape before a save,
-- as in S08.2; verify both accepted representations on reopen.
if #roots==19 and #leaves==18 then
 assert(#roots[19]:GetDescendants()==161 and #leaves[18]:GetChildren()==0 and leaves[18].Source==binding.Source,"Unexpected controller clone")
 roots[19].Parent=nil;leaves[18].Parent=nil;controllerNormalized=true
elseif #roots~=18 or #leaves~=17 then
 error("Unrecognized controller baseline "..#roots.."/"..#leaves)
end
local fp=fingerprint()
if cfg.mode=="apply" then
 assert(cfg.confirmStaging and fp==cfg.expectedFingerprint and originalFp==cfg.originalFingerprint,"Reviewed baseline")
 for _,r in before do assert(cfg.expectedTerrain[r.id]==r.digest,"Reviewed terrain") end
end
local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.FilterDescendantsInstances={T};ray.IgnoreWater=false;ray.RespectCanCollide=true
local function ground(x,z)
 local h=W:Raycast(Vector3.new(x,512,z),Vector3.new(0,-1024,0),ray)
 if h and (h.Material==Enum.Material.Grass or h.Material==Enum.Material.Ground) then return h end
end
-- Historical Open Cloud sessions load voxels without a usable terrain collision mesh.
-- Rehydrate exact channels in playable regions only, following the proven S06/S07 method.
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local function write(region,d) T:WriteVoxelChannels(region,4,{SolidMaterial=d.SolidMaterial,SolidOccupancy=d.SolidOccupancy,LiquidOccupancy=d.LiquidOccupancy}) end
local rehydrated=0
for _,r in cfg.regions do
 if r.playable then
  local b=r.bounds
  for x=b[1],b[4]-64,64 do
   for z=b[3],b[6]-64,64 do
    local region=Region3.new(Vector3.new(x,b[2],z),Vector3.new(x+64,b[5],z+64))
    local original=T:ReadVoxelChannels(region,4,channels)
    local empty=T:ReadVoxelChannels(region,4,channels)
    for i=1,16 do for j=1,(b[5]-b[2])/4 do for k=1,16 do
     empty.SolidMaterial[i][j][k]=Enum.Material.Air;empty.SolidOccupancy[i][j][k]=0;empty.LiquidOccupancy[i][j][k]=0
    end end end
    write(region,empty);write(region,original);rehydrated+=1
   end
  end
 end
end
task.wait(1)




local profiles={};for _,r in cfg.profiles do profiles[r.id]=r end
local function dist(x,z,a,b)return math.sqrt((x-a)^2+(z-b)^2) end
local buckets={};local canopy={};local bucketSize=16
local function add(x,z,r,id)
 local ix=math.floor(x/bucketSize);local iz=math.floor(z/bucketSize)
 for a=math.floor((x-r)/bucketSize),math.floor((x+r)/bucketSize) do
  for b=math.floor((z-r)/bucketSize),math.floor((z+r)/bucketSize) do
   local k=a..":"..b;buckets[k]=buckets[k] or {};table.insert(buckets[k],{x=x,z=z,r=r,id=id})
  end
 end
end
local function free(x,z,r)
 for a=math.floor((x-r)/bucketSize),math.floor((x+r)/bucketSize) do
  for b=math.floor((z-r)/bucketSize),math.floor((z+r)/bucketSize) do
   for _,p in buckets[a..":"..b] or {} do
    if dist(x,z,p.x,p.z)<r+p.r then return false end
   end
  end
 end
 return true
end
local function bb(m)local cf,s=m:GetBoundingBox();return cf,s end
local function bboxRadius(s)return math.sqrt(s.X*s.X+s.Z*s.Z)/2 end
local function fixedModel(m,padding)
 local p,s=bb(m);add(p.X,p.Z,bboxRadius(s)+padding,m.Name)
end
local sources={tree={},pine={},bush={},rock={}}
local function source(m,k)
 local pivot=m:GetPivot();local bc,sz=bb(m);local g=ground(pivot.X,pivot.Z)
 if not g then g=ground(bc.X,bc.Z) end
 assert(g,"Source ground "..m.Name)
 local profile=profiles[m.Name]
 local radius=if k=="rock" then bboxRadius(sz)+.7 else profile.groundRadius
 local support=if k=="rock" then math.min(8,bboxRadius(sz)) else profile.supportRadius
 local cr=if k=="tree" or k=="pine" then profile.canopyRadius else 0
 local cols={}
 if cr>0 then
  for _,name in {m.Name,m.Name.."-cap"} do local p=C:FindFirstChild(name);assert(p and p:IsA("Part"));table.insert(cols,{part=p,relative=pivot:ToObjectSpace(p.CFrame)}) end
 end
 local row={m=m,pivot=pivot,ground=g.Position.Y,radius=radius,support=support,canopy=cr,cols=cols,size=sz,bc=bc}
 table.insert(sources[k],row)
 add(pivot.X,pivot.Z,radius+.5,m.Name)
 if cr>0 then table.insert(canopy,{x=pivot.X,z=pivot.Z,r=cr,k=k}) end
end
for _,m in V:GetChildren() do local k=kind(m);assert(k and k~="rock");source(m,k) end
for _,m in D:GetChildren() do if kind(m)=="rock" then source(m,"rock") elseif m:IsA("Model") then fixedModel(m,1) end end
for _,m in F:GetChildren() do local p=m:FindFirstChildWhichIsA("MeshPart",true);assert(p);add(p.Position.X,p.Position.Z,bboxRadius(p.Size)+.5,m.Name) end
for _,m in L:GetChildren() do fixedModel(m,1) end
local ep=E:GetPivot().Position;add(ep.X,ep.Z,32,"Eggydrasil");table.insert(canopy,{x=ep.X,z=ep.Z,r=58.5,k="egg"})
for _,p in W:GetDescendants() do
 if p:IsA("SpawnLocation") and p.Enabled then add(p.Position.X,p.Position.Z,bboxRadius(p.Size)+5,p.Name) end
end
for k,list in sources do table.sort(list,function(a,b)return a.m.Name<b.m.Name end);assert(#list==c0[k]) end
local regions={};for _,r in cfg.regions do if r.playable then table.insert(regions,r) end end
table.sort(regions,function(a,b)return a.id<b.id end);assert(#regions==9)
local rng=Random.new(830316)
local pools={};local candidateCount=0
-- Search whole map, not a fixed number of random attempts.
-- Two interleaved lattices: 8-stud coarse and remaining 4-stud points.
for _,r in regions do
 local b=r.bounds;local list={}
 for x=b[1]+8,b[4]-8,4 do for z=b[3]+8,b[6]-8,4 do
  local h=ground(x,z)
  if h and h.Material==Enum.Material.Grass and h.Normal.Y>=math.cos(math.rad(22)) then
   table.insert(list,{x=x,z=z,y=h.Position.Y,coarse=(x%8==0 and z%8==0)})
  end
 end end
 for i=#list,2,-1 do local j=rng:NextInteger(1,i);list[i],list[j]=list[j],list[i] end
 pools[r.id]=list;candidateCount+=#list
end
local rejects={occupancy=0,canopy=0,support=0,altitude=0,boundary=0,used=0}
local function support(x,z,r,k,y)
 local maxRelief=0
 local radius=math.max(r,if k=="rock" then 2 else 2)
 for _,a in {{1,0},{-1,0},{0,1},{0,-1},{.707,.707},{-.707,.707},{.707,-.707},{-.707,-.707}} do
  local g=ground(x+a[1]*radius,z+a[2]*radius)
  if not g or g.Material~=Enum.Material.Grass or g.Normal.Y<math.cos(math.rad(22)) then return false end
  maxRelief=math.max(maxRelief,math.abs(g.Position.Y-y))
 end
 return maxRelief<= (if k=="rock" then 1.5 else 3)
end
local function canopyFree(x,z,r,k)
 if r==0 then return true end
 for _,p in canopy do
  -- Allow moderate canopy interleaving in a dense forest; trunks remain separated.
  local ratio=if p.k=="egg" or k=="pine" or p.k=="pine" then .62 else .46
  if dist(x,z,p.x,p.z)<(r+p.r)*ratio then return false end
 end
 return true
end
local target={pine=16,tree=250,bush=200,rock=150}
local added={pine=0,tree=0,bush=0,rock=0}
local tileAdded={};for _,r in regions do tileAdded[r.id]={pine=0,tree=0,bush=0,rock=0} end
local searchAttempts=0;local fineUsed=0;local maxRecords=0
local function clone(src,k,tile,p,index)
 local m=src.m:Clone();local id=prefix..k.."-"..string.format("%03d",index)
 m.Name=id;m:SetAttribute("RSManagedId",id);m:SetAttribute("RSChunk",tile)
 m:SetAttribute("RSExpectedGroundY",p.y);m:SetAttribute("RSSupportRadius",src.support)
 m:SetAttribute("RSGeneration","S08.3")
 local pos=Vector3.new(p.x,p.y+(src.pivot.Y-src.ground),p.z)
 local yaw=math.rad((index*137+17)%360)
 local dest=CFrame.new(pos)*CFrame.Angles(0,yaw,0)
 -- Clones retain exact source scale, geometry, textures, wind rig and physical flags.
 m:PivotTo(dest)
 for _,o in m:GetDescendants() do
  assert(not o:IsA("LuaSourceContainer"),"Clone script")
  if o:GetAttribute("RSManagedId") then o:SetAttribute("RSManagedId",id..":"..o:GetAttribute("RSManagedId")) end
 end
 m.Parent=if k=="rock" then D else V
 for i,a in src.cols do
  local col=a.part:Clone();col.Name=if i==1 then id else id.."-cap";col:SetAttribute("RSTreeId",id)
  col.CFrame=dest*a.relative;col.Parent=C
 end
 assert((m:GetPivot().Position-pos).Magnitude<.01,"Placement")
 return m
end
for _,k in {"pine","tree","bush","rock"} do
 local list=sources[k]
 for index=1,target[k]-c0[k] do
  local src=list[(index-1)%#list+1]
  -- Prefer underrepresented chunks. Search every other chunk when one is full.
  local order=table.clone(regions)
  table.sort(order,function(a,b)
   local aa=(tiles0[a.id] and tiles0[a.id][k] or 0)+tileAdded[a.id][k]
   local bb=(tiles0[b.id] and tiles0[b.id][k] or 0)+tileAdded[b.id][k]
   if aa~=bb then return aa<bb end
   return a.id<b.id
  end)
  local chosen=nil;local chosenTile=nil
  for pass=1,2 do
   for _,r in order do
    for _,p in pools[r.id] do
     if pass==1 and not p.coarse or pass==2 and p.coarse then continue end
     searchAttempts+=1
     if p.used then rejects.used+=1;continue end
     if k=="pine" and p.y<29.741 or k=="tree" and p.y>=29.741 then rejects.altitude+=1;continue end
     if math.max(math.abs(p.x),math.abs(p.z))+math.max(src.radius,src.canopy*.62)+3>=384 then rejects.boundary+=1;continue end
     if not free(p.x,p.z,src.radius+1) then rejects.occupancy+=1;continue end
     if not canopyFree(p.x,p.z,src.canopy,k) then rejects.canopy+=1;continue end
     if not support(p.x,p.z,src.support,k,p.y) then rejects.support+=1;continue end
     chosen=p;chosenTile=r.id;if pass==2 then fineUsed+=1 end;break
    end
    if chosen then break end
   end
   if chosen then break end
  end
  assert(chosen,"Exhausted valid sites for "..k.." "..index)
  local m=clone(src,k,chosenTile,chosen,index)
  chosen.used=true;add(chosen.x,chosen.z,src.radius+.5,m.Name)
  if src.canopy>0 then table.insert(canopy,{x=chosen.x,z=chosen.z,r=src.canopy,k=k}) end
  tileAdded[chosenTile][k]+=1;added[k]+=1
 end
end
local c,tiles,n,cols,digest=count()
assert(c.tree==250 and c.pine==16 and c.bush==200 and c.rock==150 and n==398 and cols==268,"Exact totals")
local after=terrainState();assert(#after==49)
for i,r in after do assert(r.digest==before[i].digest,"Terrain modified") end
assert(fingerprint()==fp,"Existing objects changed")
local meshes=0;local instances=0
for _,folder in {V,D,C} do for _,o in folder:GetChildren() do if new(o) then instances+=1+#o:GetDescendants();for _,p in o:GetDescendants() do if p:IsA("MeshPart") then meshes+=1 end end end end end
local result={counts=c,tiles=tiles,added=added,newModels=n,newColliders=cols,newMeshParts=meshes,newInstances=instances,digest=digest,terrain=after,fingerprint=fp,originalFingerprint=originalFp,controllerNormalized=controllerNormalized,candidates=candidateCount,searchAttempts=searchAttempts,fineUsed=fineUsed,rejected=rejects,readyForStaging=true,clientRenderVerified=false}
if cfg.mode=="apply" then
 assert(digest==cfg.expectedDigest and game.PlaceVersion==21,"Reviewed plan/version")
 A:SavePlaceAsync({SaveWithoutPublish=false});result.saved=true
else result.noPlaceWrites=true end
return syncResult(result)
