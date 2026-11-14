--!strict
-- Spatial hash: bounded cell/candidate inspection, no global all-pairs.
export type Point={id:string,x:number,z:number,cell:string}
export type Index={size:number,points:{[string]:Point},cells:{[string]:{[string]:boolean}}}
local G={}
local function cell(x:number,z:number,size:number):string return ("%d:%d"):format(math.floor(x/size),math.floor(z/size)) end
function G.new(size:number):Index assert(size>=8 and size<=128);return {size=size,points={},cells={}} end
function G.remove(g:Index,id:string):boolean
 local p=g.points[id];if not p then return false end
 local bucket=g.cells[p.cell];bucket[id]=nil;if next(bucket)==nil then g.cells[p.cell]=nil end
 g.points[id]=nil;return true
end
function G.upsert(g:Index,id:string,x:number,z:number)
 assert(x==x and z==z and math.abs(x)<1e6 and math.abs(z)<1e6,"invalid coordinate")
 local k=cell(x,z,g.size);local p=g.points[id]
 if p and p.cell==k then p.x=x;p.z=z;return end
 if p then G.remove(g,id) end
 local b=g.cells[k];if not b then b={};g.cells[k]=b end;b[id]=true;g.points[id]={id=id,x=x,z=z,cell=k}
end
function G.query(g:Index,x:number,z:number,radius:number,maxChecks:number,maxResults:number):({string},number)
 assert(radius>=0 and radius<=256 and maxChecks>=1 and maxResults>=1)
 local rows:{Point}={};local checks=0;local r2=radius*radius
 for cx=math.floor((x-radius)/g.size),math.floor((x+radius)/g.size) do
  for cz=math.floor((z-radius)/g.size),math.floor((z+radius)/g.size) do
   local b=g.cells[("%d:%d"):format(cx,cz)]
   if b then for id in pairs(b) do
    if checks>=maxChecks then break end;checks+=1
    local p=g.points[id];local dx,dz=p.x-x,p.z-z
    if dx*dx+dz*dz<=r2 then table.insert(rows,p) end
   end end
   if checks>=maxChecks then break end
  end
  if checks>=maxChecks then break end
 end
 table.sort(rows,function(a,b)
  local da=(a.x-x)^2+(a.z-z)^2;local db=(b.x-x)^2+(b.z-z)^2
  if da~=db then return da<db end;return a.id<b.id
 end)
 local ids:{string}={};for i=1,math.min(#rows,maxResults) do table.insert(ids,rows[i].id) end
 return ids,checks
end
return table.freeze(G)
