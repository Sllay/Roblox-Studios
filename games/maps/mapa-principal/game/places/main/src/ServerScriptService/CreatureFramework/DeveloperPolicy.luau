--!strict
local P={}
-- Creator account and explicitly configured server allowlist; no client-supplied role.
function P.authorized(userId:number,creatorId:number,creatorType:string,allowlist:{[number]:boolean}):boolean
 return userId>0 and (allowlist[userId]==true or (creatorType=="User" and userId==creatorId))
end
function P.tokens(command:string):{string}?
 if #command>160 then return nil end
 local args:{string}={};for token in string.gmatch(command,"%S+") do table.insert(args,token) end
 if args[1]~="/summon" then return nil end
 table.remove(args,1);return args
end
return table.freeze(P)
