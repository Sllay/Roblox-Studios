--!strict
-- Candidate selection only; server navigation/perception adapter must supply real observations.
export type Candidate={id:string,walkable:boolean,wet:boolean,blocked:boolean,deadEnd:boolean,clearance:number,slope:number,threatDistance:number,routeLength:number,concealment:number,escapeOptions:number}
local E={}
function E.choose(candidates:{Candidate},currentThreatDistance:number,maxCandidates:number):(Candidate?,number)
 assert(maxCandidates>=1 and maxCandidates%1==0,"invalid candidate budget")
 local best:Candidate?=nil;local bestScore=-math.huge
 for i=1,math.min(#candidates,maxCandidates) do
  local c=candidates[i]
  if c.walkable and not c.wet and not c.blocked and not c.deadEnd and c.clearance>=.5 and c.slope<=35 and c.escapeOptions>=1 and c.threatDistance>currentThreatDistance and c.routeLength>0 then
   -- Favor reachable distance, cover, alternate exits; penalize long routes and slope.
   local score=2*(c.threatDistance-currentThreatDistance)+4*math.clamp(c.concealment,0,1)+math.min(3,c.escapeOptions)-.25*c.routeLength-.03*c.slope
   if score>bestScore or (score==bestScore and best and c.id<best.id) then best=c;bestScore=score end
  end
 end
 return best,bestScore
end
return table.freeze(E)
