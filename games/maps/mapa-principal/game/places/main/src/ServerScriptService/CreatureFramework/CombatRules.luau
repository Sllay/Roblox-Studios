--!strict
-- Server-only strike authorization. Each attack token can commit at most once.
export type AttackMemory={lastToken:number,nextAt:number}
export type Actor={id:string,faction:string,alive:boolean,damage:number}
local R={}
function R.new():AttackMemory return {lastToken=0,nextAt=0} end
function R.authorize(m:AttackMemory,p:any,attacker:Actor,target:Actor,token:number,now:number,distance:number,visible:boolean):boolean
 if not attacker.alive or not target.alive or attacker.id==target.id or attacker.faction==target.faction then return false end
 if token%1~=0 or token<=m.lastToken or token>1e9 or now<m.nextAt or now~=now or now==math.huge then return false end
 if not visible or distance~=distance or distance<p.minRange or distance>p.maxRange then return false end
 if attacker.damage<=0 or attacker.damage~=attacker.damage or attacker.damage>10000 then return false end
 m.lastToken=token;m.nextAt=now+p.cooldown;return true
end
return table.freeze(R)
