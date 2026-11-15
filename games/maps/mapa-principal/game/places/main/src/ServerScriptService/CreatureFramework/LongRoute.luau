--!strict
-- Incremental A* over a local grid. Edge validation is supplied by the terrain adapter.
local R={}
local function key(x:number,z:number):string return x..":"..z end
function R.new(x:number,z:number,tx:number,tz:number,step:number,maxNodes:number):any
 assert(step>0 and maxNodes>0)
 local gx,gz=math.round((tx-x)/step),math.round((tz-z)/step)
 local first={x=0,z=0,g=0,f=math.abs(gx)+math.abs(gz),parent=nil}
 return {x=x,z=z,gx=gx,gz=gz,step=step,maxNodes=maxNodes,open={first},best={[key(0,0)]=0},expanded=0,status="Pending",path=nil}
end
function R.advance(s:any,budget:number,edge:(number,number,number,number)->boolean):string
 if s.status~="Pending" then return s.status end
 for _=1,budget do
  if #s.open==0 or s.expanded>=s.maxNodes then s.status="Failed";break end
  local i=1;for j=2,#s.open do if s.open[j].f<s.open[i].f then i=j end end
  local n=table.remove(s.open,i);s.expanded+=1
  if n.g~=s.best[key(n.x,n.z)] then continue end
  if n.x==s.gx and n.z==s.gz then
   local path={};while n.parent do table.insert(path,1,{x=s.x+n.x*s.step,z=s.z+n.z*s.step});n=n.parent end
   s.path=path;s.status="Ready";break
  end
  for _,d in {{1,0},{-1,0},{0,1},{0,-1}} do
   local x,z=n.x+d[1],n.z+d[2];local k=key(x,z);local g=n.g+1
   if g<(s.best[k] or math.huge) and edge(s.x+n.x*s.step,s.z+n.z*s.step,s.x+x*s.step,s.z+z*s.step) then
    s.best[k]=g;table.insert(s.open,{x=x,z=z,g=g,f=g+math.abs(s.gx-x)+math.abs(s.gz-z),parent=n})
   end
  end
 end
 return s.status
end
return table.freeze(R)
