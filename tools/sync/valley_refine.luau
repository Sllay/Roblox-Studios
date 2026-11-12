-- __RS_SUPPORT__
local W=workspace
local T=W.Terrain
local SSS=game:GetService("ServerScriptService")
local SPS=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local ch={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local function output(r) r.universeId=tostring(game.GameId);r.placeId=tostring(game.PlaceId);return Http:JSONEncode(r) end
local function region(b) return Region3.new(Vector3.new(b[1],b[2],b[3]),Vector3.new(b[4],b[5],b[6])) end
local function read(b) return T:ReadVoxelChannels(region(b),4,ch) end
local function digest(d,nx,ny,nz)
 local buf=buffer.create(nx*ny*nz*6);local at=0
 for x=1,nx do for y=1,ny do for z=1,nz do
  buffer.writeu16(buf,at,math.round(d.SolidOccupancy[x][y][z]*65535));buffer.writeu16(buf,at+2,math.round(d.LiquidOccupancy[x][y][z]*65535));buffer.writeu16(buf,at+4,d.SolidMaterial[x][y][z].Value);at+=6
 end end end
 return buffer.tostring(Encoding:Base64Encode(Encoding:ComputeBufferHash(buf,Enum.HashAlgorithm.Sha256)))
end
local function smooth(t) t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function mix(a,b,t) return a+(b-a)*t end
local function dimensions(b) return (b[4]-b[1])/4,(b[5]-b[2])/4,(b[6]-b[3])/4 end
local function column(d,i,j,ymin,ny)
 local h,w,mat=ymin,nil,Enum.Material.Grass
 for y=1,ny do
  local s,l=d.SolidOccupancy[i][y][j],d.LiquidOccupancy[i][y][j]
  if s>0.02 then h=ymin+(y-1+s)*4;mat=d.SolidMaterial[i][y][j] end
  if l>0.02 then w=math.max(w or ymin,ymin+(y-1+s+l)*4) end
 end
 return {h=h,w=w,mat=mat}
end
local function setColumn(d,i,j,ymin,ny,c)
 for y=1,ny do
  local bottom=ymin+(y-1)*4
  local s=math.clamp((c.h-bottom)/4,0,1)
  local w=if c.w then math.min(1-s,math.clamp((c.w-bottom)/4,0,1)) else 0
  d.SolidOccupancy[i][y][j]=s;d.LiquidOccupancy[i][y][j]=w
  d.SolidMaterial[i][y][j]=if s==0 then Enum.Material.Air elseif bottom+4>=c.h-8 then c.mat elseif bottom+4>=c.h-16 then Enum.Material.Ground else Enum.Material.Rock
  assert(s+w<=1.0001,"Occupancy")
 end
 assert(d.SolidOccupancy[i][1][j]==1,"Foundation gap")
end
local b={128,-32,-32,320,112,352}
local nx,ny,nz=dimensions(b)
local outer={}
for z=-3,3 do for x=-3,3 do
 if math.max(math.abs(x),math.abs(z))==3 then
  local a,c=x*256-128,z*256-128
  table.insert(outer,{id=string.format("chunk-%d-%d",x,z),bounds={a,-32,c,a+256,112,c+256}})
 end
end end
local function verify()
 local hashes={river=digest(read(b),nx,ny,nz)}
 assert(hashes.river==cfg.expected.hashes.river,"River digest")
 for _,tile in outer do
  local v=digest(read(tile.bounds),64,36,64);assert(v==cfg.expected.hashes[tile.id],"Horizon digest");hashes[tile.id]=v
 end
 local f=W:FindFirstChild("RSWorldBoundary");assert(f and #f:GetChildren()==5,"Boundary count")
 for _,part in f:GetChildren() do assert(part:IsA("Part") and part.Anchored and part.CanCollide and part.Transparency==1 and not part.CastShadow,"Boundary properties") end
 assert(SSS.RSCentralSpawnSafety.Source==cfg.runtime and SPS.RSQualityPanel.Source==cfg.client and SPS.RSBoundaryGrid.Source==cfg.grid and SSS.RSRagdoll.Source==cfg.ragdoll,"Source mismatch")
 for _,r in cfg.expected.moves do
  local m=W[r.root].Models:FindFirstChild(r.name)
  assert(m and (m:GetPivot().Position-Vector3.new(table.unpack(r.after))).Magnitude<0.03,"Prop move mismatch")
  if r.collider then assert((W[r.root].Collisions[r.name].Position-Vector3.new(table.unpack(r.collider))).Magnitude<0.03,"Collider move mismatch") end
 end
 return output({verified=true,hashes=hashes,moves=#cfg.expected.moves,boundaries=5})
end
if cfg.mode=="verify" then return verify() end
assert(game.PlaceVersion==9 and cfg.environment=="staging","Wrong version")
assert(not W:FindFirstChild("RSWorldBoundary") and not SPS:FindFirstChild("RSBoundaryGrid") and not SSS:FindFirstChild("RSRagdoll"),"Already installed")
-- Engine-side structural test on detached legacy and AJU rigs; no gameplay claim.
local Ragdoll=(function()
-- __RS_RAGDOLL__
end)()
local function testRig(advanced)
 local m=Instance.new("Model");local hum=Instance.new("Humanoid");hum.Parent=m
 local a=Instance.new("Part");a.Name="Torso";a.Parent=m
 local b=Instance.new("Part");b.Name="Head";b.Position=Vector3.new(0,2,0);b.Parent=m
 local joint
 if advanced then
  local a0=Instance.new("Attachment");a0.Parent=a;local a1=Instance.new("Attachment");a1.Parent=b
  local c=Instance.new("BallSocketConstraint");c.Attachment0=a0;c.Attachment1=a1;c.Parent=a
  joint=Instance.new("AnimationConstraint");joint.Attachment0=a0;joint.Attachment1=a1;joint.Parent=a
 else joint=Instance.new("Motor6D");joint.Name="Neck";joint.Part0=a;joint.Part1=b;joint.Parent=a end
 Ragdoll.prepare(hum);local result=Ragdoll.activate(m,hum,"Default")
 assert(result.sockets==1 and result.colliders==2 and not joint.Enabled and not hum.BreakJointsOnDeath,"Ragdoll test failed")
 assert(result.rig==(if advanced then "AJU" else "Motor6D"),"Rig detection failed")
 assert(Ragdoll.activate(m,hum,"Default")==nil,"Ragdoll idempotency")
 m:Destroy();return true
end
assert(testRig(false) and testRig(true),"Ragdoll topology tests")
local d=read(b)
local oldHash=digest(d,nx,ny,nz)
local field={}
local function curve(z)
 local t=math.clamp((z-28)/272,0,1)
 return 224+27*math.sin(t*math.pi*2)-13*math.sin(t*math.pi*4)
end
local function base(x,z)
 local h=18+math.noise(x/160,z/160,93.217)*14+math.noise(x/55,z/55,186.434)*5+math.clamp((z+100)/400,0,1)*7
 local far=math.max(math.abs(x),math.abs(z))
 return math.clamp(h+smooth((far-320)/220)*(36+math.noise(x/115,z/115,279.651)*42+math.noise(x/43,z/43,19)*10),5,95)
end
local function oldDist(x,z)
 local pts={{212,300},{204,248},{236,188},{224,128},{220,92},{224,60},{224,28}}
 local best=math.huge
 for i=1,#pts-1 do
  local a,c=pts[i],pts[i+1];local dx,dz=c[1]-a[1],c[2]-a[2]
  local t=math.clamp(((x-a[1])*dx+(z-a[2])*dz)/(dx*dx+dz*dz),0,1)
  best=math.min(best,math.sqrt((x-a[1]-t*dx)^2+(z-a[2]-t*dz)^2))
 end
 return best
end
local changed,wet,riverWet=0,0,0
for i=1,nx do
 field[i]={}
 for j=1,nz do
  local x,z=b[1]+(i-0.5)*4,b[3]+(j-0.5)*4
  local c=column(d,i,j,b[2],ny)
  local old={h=c.h,w=c.w,mat=c.mat}
  local distance=math.sqrt((x-curve(z))^2+math.max(0,z-300)^2)
  local source=math.sqrt((x-curve(300))^2+(z-300)^2)
  local hill=17*math.exp(-((x-220)^2+(z-302)^2)/(62*62))
  local natural=base(x,z)+hill
  local weight=math.max(1-smooth((oldDist(x,z)-35)/20),1-smooth((distance-38)/26),math.exp(-source^2/(60*60)))*smooth(math.min(x-b[1],b[4]-x,b[6]-z)/16)
  -- Preserve the original lake, except the mouth cut which must overlap its water.
  if z>=44 and z<=332 then
   c.h=mix(c.h,natural,weight);if old.w and z>=56 then c.w=nil;c.mat=Enum.Material.Grass end
   if oldDist(x,z)<50 and z>=60 then c.mat=Enum.Material.Grass end
  end
  local width=12+2.5*math.sin(z/24)+1.5*math.cos(z/17)
  local level=20+16*smooth((z-48)/252)
  -- The mouth extends into actual lake cells at z=28. No sandy plug.
  if z>=24 and z<=332 and distance<width+40 then
   local q=distance-width
   if q<0 then
    local depth=4.8+0.8*math.cos(z/32)
    c.h=math.min(c.h,level-depth);c.w=level;c.mat=Enum.Material.Sand
    if z>52 then c.h=level-depth end
    riverWet+=1
   elseif not c.w and z>=44 then
    -- gentle continuous banks, no vertical walls; thin sand next to water.
    local bank=level+0.5+3.5*smooth(q/20)
    c.h=mix(bank,math.max(natural,level+1),smooth(q/40))
    c.mat=if q<5 then Enum.Material.Sand else Enum.Material.Grass
   end
  end

  if c.w then wet+=1 end
  if math.abs(c.h-old.h)>0.02 or c.w~=old.w or c.mat~=old.mat then changed+=1;c.changed=true;setColumn(d,i,j,b[2],ny,c) end
  field[i][j]=c
 end
end
-- Water connectivity with a minimum deep-water cell, not just a wet sliver.
local function idx(x,z) return math.floor((x-b[1])/4)+1,math.floor((z-b[3])/4)+1 end
local ix,iz=idx(224,28)
assert(field[ix][iz].w,"Lake mouth absent")
local q={{ix,iz}};local seen={[ix*nz+iz]=true};local k=1
while k<=#q do
 local v=q[k];k+=1
 for _,o in {{1,0},{-1,0},{0,1},{0,-1}} do
  local i,j=v[1]+o[1],v[2]+o[2];local c=field[i] and field[i][j]
  if c and c.w and c.w-c.h>=2 and not seen[i*nz+j] then seen[i*nz+j]=true;table.insert(q,{i,j}) end
 end
end
local sx,sz=idx(curve(300),300);assert(seen[sx*nz+sz],"Source not connected to lake")
for z=28,300,4 do
 local i,j=idx(curve(z),z);local c=field[i][j];assert(c.w and c.w-c.h>=3 and seen[i*nz+j],"Dry river center")
end
local function heightAt(x,z)
 local gx,gz=(x-b[1])/4+0.5,(z-b[3])/4+0.5
 local i,j=math.floor(gx),math.floor(gz)
 if i<1 or i>=nx or j<1 or j>=nz then return nil end
 local a,c,f,g=field[i][j],field[i+1][j],field[i][j+1],field[i+1][j+1]
 for _,v in {a,c,f,g} do if v.w or v.mat~=Enum.Material.Grass then return nil end end
 return mix(mix(a.h,c.h,gx-i),mix(f.h,g.h,gx-i),gz-j)
end
local moves={}
local planned={}
for _,root in {W.RSSceneBuilder,W.RSWorldVegetation} do
 for _,m in root.Models:GetChildren() do
  local p=m:GetPivot().Position
  if p.X<b[1]+8 or p.X>b[4]-8 or p.Z<b[3]+8 or p.Z>b[6]-8 then continue end
  local i,j=idx(p.X,p.Z);local touched=false
  for dx=-2,2 do for dz=-2,2 do if field[i+dx] and field[i+dx][j+dz] and field[i+dx][j+dz].changed then touched=true end end end
  if not touched then continue end
  local burial=m:GetAttribute("RSBuriedDepth");local radius=m:GetAttribute("RSSupportRadius");local _,yaw,_=m:GetPivot():ToOrientation()
  local x,z=p.X,p.Z
  local ok,cf,ground=pcall(supportTarget,m,x,z,math.deg(yaw),burial,radius,heightAt)
  if not ok then
   for rad=8,64,4 do
    for a=0,15 do
     local px,pz=x+math.cos(a*math.pi/8)*rad,z+math.sin(a*math.pi/8)*rad
     local space=true
     for _,other in {W.RSSceneBuilder,W.RSWorldVegetation} do
      for _,o in other.Models:GetChildren() do
       if o~=m then local op=planned[o] or o:GetPivot().Position;if (Vector2.new(op.X,op.Z)-Vector2.new(px,pz)).Magnitude<12 then space=false;break end end
      end
      if not space then break end
     end
     if space then ok,cf,ground=pcall(supportTarget,m,px,pz,math.deg(yaw),burial,radius,heightAt);if ok then break end end
    end
    if ok then break end
   end
  end
  assert(ok,"No support for "..m.Name)
  local collider=root.Collisions:FindFirstChild(m.Name)
  local row={root=root.Name,name=m.Name,before=vec(p),after=vec(cf.Position),yaw=math.deg(yaw),ground=ground,burial=burial,radius=radius}
  if collider then row.collider=vec(collider.Position+cf.Position-p) end
  table.insert(moves,row);planned[m]=cf.Position
 end
end
table.sort(moves,function(a,c) return a.root..a.name<c.root..c.name end)
-- Horizon ring: blend from existing edge heights; preserve all original tiles.
local edges={}
local edgeWest=read({-640,-32,-640,-636,112,640})
local edgeEast=read({636,-32,-640,640,112,640})
local edgeNorth=read({-640,-32,-640,640,112,-636})
local edgeSouth=read({-640,-32,636,640,112,640})
for _,tile in outer do
 local bb=tile.bounds
 local old=read(bb)
 for x=1,64 do for y=1,36 do for z=1,64 do assert(old.SolidOccupancy[x][y][z]==0 and old.LiquidOccupancy[x][y][z]==0,"Unknown horizon terrain") end end end
end
local function edgeHeight(x,z)
 local ex,ez=math.clamp(x,-638,638),math.clamp(z,-638,638)
 local ix,iz=math.floor(ex/4),math.floor(ez/4);local key=ix..":"..iz
 if edges[key]==nil then
  if ix==-160 then edges[key]=column(edgeWest,1,iz+161,-32,36).h
  elseif ix==159 then edges[key]=column(edgeEast,1,iz+161,-32,36).h
  elseif iz==-160 then edges[key]=column(edgeNorth,ix+161,1,-32,36).h
  else edges[key]=column(edgeSouth,ix+161,1,-32,36).h end
 end
 return edges[key]
end
local function horizon(x,z)
 local dist=math.max(math.abs(x),math.abs(z))-640
 local h=math.clamp(67+math.noise(x/145,z/145,18)*45+math.noise(x/65,z/65,71)*15,35,98)
 return mix(edgeHeight(x,z),h,smooth((dist-2)/100))
end
local map={}
for i=1,nx do local col={};for j=1,nz do local c=field[i][j];table.insert(col,{math.round(c.h*100)/100,c.w or 0,c.mat.Name}) end;table.insert(map,col) end
local preview={map=map,oldHash=oldHash,changedColumns=changed,wetColumns=wet,riverColumns=riverWet,connectedDeep=#q,moves=moves,horizonTiles=#outer,boundaries=5,ragdollTopologyTests=2}
if cfg.mode=="preview" then return output(preview) end
assert(cfg.mode=="apply" and cfg.preview.oldHash==oldHash and cfg.preview.changedColumns==changed and cfg.preview.connectedDeep==#q,"Preview changed")
assert(#cfg.preview.moves==#moves,"Move count changed")
for i,r in moves do assert(r.name==cfg.preview.moves[i].name and (Vector3.new(table.unpack(r.after))-Vector3.new(table.unpack(cfg.preview.moves[i].after))).Magnitude<0.025,"Move changed") end
T:WriteVoxelChannels(region(b),4,d)
local persisted=read(b)
local hashes={river=digest(persisted,nx,ny,nz)}
local maxError=0
for i=1,nx do for y=1,ny do for j=1,nz do maxError=math.max(maxError,math.abs(persisted.SolidOccupancy[i][y][j]-d.SolidOccupancy[i][y][j]),math.abs(persisted.LiquidOccupancy[i][y][j]-d.LiquidOccupancy[i][y][j])) end end end
assert(maxError<=0.02,"River readback error")
for _,tile in outer do
 local bb=tile.bounds;local a={SolidMaterial={},SolidOccupancy={},LiquidOccupancy={}}
 for i=1,64 do
  for _,key in ch do a[key][i]={};for y=1,36 do a[key][i][y]={} end end
  for j=1,64 do setColumn(a,i,j,-32,36,{h=horizon(bb[1]+(i-0.5)*4,bb[3]+(j-0.5)*4),mat=Enum.Material.Grass}) end
 end
 T:WriteVoxelChannels(region(bb),4,a);hashes[tile.id]=digest(read(bb),64,36,64)
end
for _,r in moves do
 local root=W[r.root];local m=root.Models[r.name];local c=root.Collisions:FindFirstChild(r.name)
 moveSupported(m,c,CFrame.new(table.unpack(r.after))*CFrame.Angles(0,math.rad(r.yaw),0),r.ground,r.burial,r.radius)
end
local f=Instance.new("Folder");f.Name="RSWorldBoundary";f:SetAttribute("RSOwner","RSWorldBoundaryV1")
local function wall(name,p,size)
 local a=Instance.new("Part");a.Name=name;a.Position=p;a.Size=size;a.Anchored=true;a.CanCollide=true;a.CanTouch=false;a.Transparency=1;a.CastShadow=false;a.Parent=f
end
wall("East",Vector3.new(388,26,0),Vector3.new(8,308,784))
wall("West",Vector3.new(-388,26,0),Vector3.new(8,308,784))
wall("North",Vector3.new(0,26,-388),Vector3.new(784,308,8))
wall("South",Vector3.new(0,26,388),Vector3.new(784,308,8))
wall("Ceiling",Vector3.new(0,184,0),Vector3.new(784,8,784))
f.Parent=W
local rag=Instance.new("ModuleScript");rag.Name="RSRagdoll";rag.Source=cfg.ragdoll;rag.Parent=SSS
SSS.RSCentralSpawnSafety.Source=cfg.runtime
SPS.RSQualityPanel.Source=cfg.client
local grid=Instance.new("LocalScript");grid.Name="RSBoundaryGrid";grid.Source=cfg.grid;grid.Parent=SPS
game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere").Haze=2.2
game:GetService("AssetService"):SavePlaceAsync({SaveWithoutPublish=false})
return output({saved=true,hashes=hashes,moves=moves,changedColumns=changed,connectedDeep=#q,horizonTiles=#outer,boundaries=5,maxError=maxError})
