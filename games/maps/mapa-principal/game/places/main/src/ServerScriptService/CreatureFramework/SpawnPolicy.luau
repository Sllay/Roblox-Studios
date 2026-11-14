--!strict
-- One natural population controller per species/biome. Clock is monotonic seconds.
export type Policy={speciesId:string,biomeId:string,maximum:number,initial:number,respawnSeconds:number,allowedMaterials:{[string]:boolean}}
export type Clock={due:number?,lastNow:number,initializing:boolean,retryAt:number}
local S={}
S.chicken=table.freeze({speciesId="210080",biomeId="emerald_valley",maximum=15,initial=15,respawnSeconds=300,allowedMaterials=table.freeze({Grass=true})})
function S.new():Clock return {due=nil,lastNow=0,initializing=true,retryAt=0} end
function S.next(c:Clock,p:Policy,count:number,now:number):boolean
 assert(now>=c.lastNow and now<math.huge and count>=0 and count%1==0,"invalid spawn clock")
 c.lastNow=now
 if count>=p.maximum then c.due=nil;c.initializing=false;return false end
 if c.initializing and count>=p.initial then c.initializing=false end
 if not c.initializing and not c.due then c.due=now+p.respawnSeconds end
 return now>=c.retryAt and (c.initializing or now>=(c.due or math.huge))
end
function S.result(c:Clock,p:Policy,countAfter:number,now:number,success:boolean)
 assert(now>=c.lastNow and now<math.huge,"invalid spawn result clock");c.lastNow=now
 if not success then c.retryAt=now+5;return end
 c.retryAt=0
 if countAfter>=p.maximum then c.initializing=false;c.due=nil
 elseif c.initializing and countAfter<p.initial then c.due=nil
 else c.initializing=false;c.due=now+p.respawnSeconds end
end
return table.freeze(S)
