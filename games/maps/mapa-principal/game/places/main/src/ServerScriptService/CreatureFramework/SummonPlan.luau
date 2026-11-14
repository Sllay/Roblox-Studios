--!strict
-- Pure command planning, never accepts a client privilege flag as authority.
export type Plan={speciesId:string,count:number,position:{number}?,here:boolean,aiEnabled:boolean,origin:string,level:number}
local S={}
function S.parse(args:{string},authorized:boolean,exists:boolean,_capacity:number):(Plan?,string?)
 if not authorized then return nil,"forbidden" end
 if #args~=5 and #args~=7 then return nil,"usage: /summon mob ID count here true|false OR ID count x y z true|false" end
 if args[1]~="mob" or not exists or not string.match(args[2],"^[1-9]%d%d%d%d%d$") then return nil,"unknown species" end
 local n=tonumber(args[3])
 if not n or n%1~=0 or n<1 or n>10000 then return nil,"invalid count (1–10000 per request)" end
 local flag=args[#args];if flag~="true" and flag~="false" then return nil,"invalid AI flag" end
 local pos:{number}?=nil;local here=#args==5
 if here then if args[4]~="here" then return nil,"invalid position" end
 else
  local x,y,z=tonumber(args[4]),tonumber(args[5]),tonumber(args[6])
  if not x or not y or not z or math.abs(x)>1e5 or math.abs(y)>1e5 or math.abs(z)>1e5 then return nil,"invalid position" end
  pos={x,y,z}
 end
 return {speciesId=args[2],count=n,position=pos,here=here,aiEnabled=flag=="true",origin="Developer",level=1},nil
end
return table.freeze(S)
