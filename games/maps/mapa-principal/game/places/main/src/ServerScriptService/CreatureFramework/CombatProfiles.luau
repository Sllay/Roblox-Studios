--!strict
-- Shared capability profiles, not registered species or final balance.
export type Profile={id:string,kind:string,preyOnly:boolean,sight:number,minRange:number,maxRange:number,idealRange:number,windup:number,recovery:number,cooldown:number,retreatHealth:number,hungerThreshold:number,projectileSpeed:number}
local P={}
local profiles:{[string]:Profile}={
 Predator={id="Predator",kind="Melee",preyOnly=true,sight=28,minRange=0,maxRange=2.5,idealRange=1.8,windup=.35,recovery=.6,cooldown=1.2,retreatHealth=.2,hungerThreshold=.4,projectileSpeed=0},
 Melee={id="Melee",kind="Melee",preyOnly=false,sight=32,minRange=0,maxRange=3.2,idealRange=2.2,windup=.4,recovery=.65,cooldown=1.25,retreatHealth=.2,hungerThreshold=0,projectileSpeed=0},
 Ranged={id="Ranged",kind="Ranged",preyOnly=false,sight=45,minRange=8,maxRange=30,idealRange=16,windup=.6,recovery=.5,cooldown=1.5,retreatHealth=.25,hungerThreshold=0,projectileSpeed=48},
}
for _,p in pairs(profiles) do table.freeze(p) end;table.freeze(profiles)
function P.get(id:string):Profile? return profiles[id] end
function P.brain(id:string,passive:any,combat:any):any
 if id=="PassivePrey" then return passive end
 return combat.withProfile(assert(P.get(id),"unknown combat profile"))
end
return table.freeze(P)
