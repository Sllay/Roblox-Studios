--!strict
-- Bounded round-robin policy; never creates one heartbeat per mob.
export type Tier="Near"|"Mid"|"Far"|"Abstract"
export type Slot={id:string,tier:Tier,due:number}
local B={}
local intervals:{[Tier]:number}={Near=.1,Mid=.5,Far=2,Abstract=10}
function B.tier(distance:number,previous:Tier?):Tier
 -- Hysteresis avoids repeated promotion/demotion at a boundary.
 local d=math.max(0,distance)
 if previous=="Near" and d<=55 then return "Near" end
 if previous=="Mid" and d>45 and d<=125 then return "Mid" end
 if previous=="Far" and d>115 and d<=255 then return "Far" end
 if previous=="Abstract" and d>245 then return "Abstract" end
 if d<=50 then return "Near" elseif d<=120 then return "Mid" elseif d<=250 then return "Far" else return "Abstract" end
end
function B.take(slots:{Slot},cursor:number,now:number,maxChecks:number,maxUpdates:number):({string},number,number)
 local out:{string}={};local n=#slots
 assert(maxChecks>=0 and maxUpdates>=0 and maxChecks%1==0 and maxUpdates%1==0,"invalid budget")
 if n==0 then return out,1,0 end
 cursor=math.clamp(cursor,1,n);local checks=0
 while checks<math.min(maxChecks,n) and #out<maxUpdates do
  local slot=slots[cursor];checks+=1;cursor=cursor%n+1
  if slot.due<=now then table.insert(out,slot.id);slot.due=now+intervals[slot.tier] end
 end
 return out,cursor,checks
end
return table.freeze(B)
