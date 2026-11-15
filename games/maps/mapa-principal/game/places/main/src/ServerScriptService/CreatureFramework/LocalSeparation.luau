--!strict
local S={}
local function key(x:number,z:number):string return tostring(x)..":"..tostring(z) end
function S.new(cell:number):any assert(cell>0);return {cell=cell,maxRadius=0,buckets={},entries={}} end
function S.remove(s:any,id:string)
 local e=s.entries[id];if not e then return end
 local bucket=s.buckets[e.key];bucket[id]=nil;if next(bucket)==nil then s.buckets[e.key]=nil end;s.entries[id]=nil
end
function S.put(s:any,id:string,x:number,z:number,radius:number)
 S.remove(s,id);s.maxRadius=math.max(s.maxRadius,radius)
 local k=key(math.floor(x/s.cell),math.floor(z/s.cell))
 local e={id=id,x=x,z=z,radius=radius,key=k};s.entries[id]=e
 local bucket=s.buckets[k] or {};s.buckets[k]=bucket;bucket[id]=e
end
function S.steer(s:any,id:string,x:number,z:number,radius:number,dx:number,dz:number):(number,number)
 local reach=radius+s.maxRadius+.4;local ax,az=0,0
 for i=math.floor((x-reach)/s.cell),math.floor((x+reach)/s.cell) do
  for j=math.floor((z-reach)/s.cell),math.floor((z+reach)/s.cell) do
   for other,e in pairs(s.buckets[key(i,j)] or {}) do
    if other==id then continue end
    local vx,vz=x-e.x,z-e.z;local d=math.sqrt(vx*vx+vz*vz);local limit=radius+e.radius+.4
    if d<limit then
     if d<.001 then vx=if id<other then .001 else -.001;vz=0;d=.001 end
     local w=math.max(0,1-d/limit);ax+=vx/d*w;az+=vz/d*w
    end
   end
  end
 end
 local m=math.sqrt(ax*ax+az*az);if m>1 then ax/=m;az/=m end
 local vx,vz=dx+ax*.65,dz+az*.65;local n=math.sqrt(vx*vx+vz*vz)
 if n<.001 then return dx,dz end
 return vx/n,vz/n
end
return table.freeze(S)
