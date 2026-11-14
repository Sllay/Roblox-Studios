--!strict
-- Server-only gameplay integration; no client-provided species, origin, damage or discovery flag.
local E={}
function E.new(book:any,persistence:any,director:any,validateInteraction:(any,any)->boolean):any
 return {book=book,persistence=persistence,director=director,validateInteraction=validateInteraction,lastInteraction={}}
end
function E.interact(s:any,actor:any,mobId:string,now:number,unix:number):boolean
 local uid=actor.UserId
 if type(uid)~="number" or uid<=0 or type(mobId)~="string" or #mobId>64 then return false end
 local r=s.director.agents[mobId]
 if not r or not r.adapter.alive or r.origin~="Natural" then return false end
 if now-(s.lastInteraction[uid] or -math.huge)<.5 then return false end
 s.lastInteraction[uid]=now
 if not s.validateInteraction(actor,r) then return false end
 return s.persistence.discover(s.book,uid,r.speciesId,"Interaction",r.origin,unix)
end
-- Only trusted server combat resolver calls this after hit/range/weapon validation.
-- No remote invokes this method. Environmental damage has no attacker.
function E.damage(s:any,directorModule:any,mobId:string,amount:number,attackerUserId:number?,now:number,unix:number):boolean
 local r=s.director.agents[mobId]
 if not r or not r.adapter.alive or amount<=0 or amount~=amount or amount>10000 then return false end
 r.health=math.max(0,r.health-amount);r.adapter.model:SetAttribute("CreatureHealth",r.health)
 if r.health>0 then r.adapter:damage();return true end
 r.adapter.alive=false
 if attackerUserId and attackerUserId>0 and attackerUserId%1==0 then s.persistence.discover(s.book,attackerUserId,r.speciesId,"Kill",r.origin,unix) end
 directorModule.remove(s.director,mobId,now)
 return true
end
function E.forgetActor(s:any,userId:number) s.lastInteraction[userId]=nil end
return table.freeze(E)
