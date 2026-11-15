--!strict
-- Ecological configuration is independent of assets and combat profiles.
export type Profile={population:number,groupKind:string,groupMax:number,territorial:boolean,migrationSeconds:number?,exclusiveSameSpecies:boolean,roamRadius:number,canSwim:boolean}
local P={}
local function profile(p:Profile):Profile
 assert(p.population>0 and p.population%1==0 and p.groupMax>=1 and p.groupMax<=p.population)
 assert(p.roamRadius>0 and (not p.exclusiveSameSpecies or p.territorial))
 assert(not p.migrationSeconds or (p.territorial and p.migrationSeconds>0))
 return table.freeze(p)
end
P.chicken=profile({population=16,groupKind="Solo",groupMax=1,territorial=false,exclusiveSameSpecies=false,roamRadius=100,canSwim=false})
P.rabbit=profile({population=16,groupKind="Companion",groupMax=2,territorial=false,exclusiveSameSpecies=false,roamRadius=100,canSwim=false})
P.cow=profile({population=8,groupKind="Herd",groupMax=8,territorial=true,migrationSeconds=300,exclusiveSameSpecies=false,roamRadius=100,canSwim=false})
P.pig=profile({population=16,groupKind="Herd",groupMax=4,territorial=true,migrationSeconds=300,exclusiveSameSpecies=true,roamRadius=100,canSwim=false})
P.sheep=profile({population=8,groupKind="Herd",groupMax=2,territorial=true,migrationSeconds=300,exclusiveSameSpecies=false,roamRadius=100,canSwim=false})
return table.freeze(P)
