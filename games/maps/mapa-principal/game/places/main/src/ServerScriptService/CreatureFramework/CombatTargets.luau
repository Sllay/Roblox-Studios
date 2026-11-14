--!strict
export type Candidate={id:string,faction:string,alive:boolean,prey:boolean,visible:boolean,distance:number,threat:number}
local T={}
function T.choose(candidates:{Candidate},faction:string,profile:any,current:string?,maxChecks:number):Candidate?
 local best:Candidate?=nil;local score=-math.huge
 for i=1,math.min(#candidates,maxChecks) do
  local c=candidates[i]
  if c.alive and c.faction~=faction and c.visible and c.distance<=profile.sight and (not profile.preyOnly or c.prey) then
   local value=profile.sight-c.distance+math.clamp(c.threat,0,10)*.5+(if c.id==current then 4 else 0)
   if value>score or (value==score and best and c.id<best.id) then best=c;score=value end
  end
 end
 return best
end
return table.freeze(T)
