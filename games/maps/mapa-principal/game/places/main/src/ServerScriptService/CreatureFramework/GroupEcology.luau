--!strict
local G={}
local function dist(a:any,b:any):number return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
function G.new():any return {groups={},membership={},serial=0} end
function G.valid(s:any,species:string,p:any,radius:number,exclusive:boolean,ignore:string?):boolean
 for id,g in pairs(s.groups) do
  if id~=ignore and g.species==species and (exclusive or g.profile.exclusiveSameSpecies) then
   if g.center and dist(p,g.center)<radius+g.radius+8 then return false end
   if g.destination and dist(p,g.destination)<radius+g.radius+8 then return false end
  end
 end
 return true
end
function G.create(s:any,species:string,profile:any,center:any,now:number):any
 local radius=profile.territoryRadius or 40
 if profile.territorial and not G.valid(s,species,center,radius,profile.exclusiveSameSpecies,nil) then return nil end
 s.serial+=1;local id=tostring(s.serial)
 local g={id=id,species=species,profile=profile,center=center,radius=radius,members={},count=0,nextMigration=now+(profile.migrationSeconds or math.huge),destination=nil}
 s.groups[id]=g;return g
end
function G.join(s:any,g:any,id:string):boolean
 if s.membership[id] or g.count>=g.profile.groupMax then return false end
 g.members[id]=true;g.count+=1;s.membership[id]=g.id;return true
end
function G.leave(s:any,id:string)
 local gid=s.membership[id];if not gid then return end
 local g=s.groups[gid];s.membership[id]=nil;g.members[id]=nil;g.count-=1
 if g.count==0 then s.groups[gid]=nil end
end
function G.pair(s:any,a:string,b:string):boolean
 local ga=s.groups[s.membership[a]];local gb=s.groups[s.membership[b]]
 if not ga or not gb or ga==gb or ga.species~=gb.species or ga.profile.groupKind~="Companion" or ga.count~=1 or gb.count~=1 then return false end
 G.leave(s,b);return G.join(s,ga,b)
end
function G.begin(s:any,g:any,destination:any,now:number):boolean
 if not g.profile.migrationSeconds or g.destination or dist(g.center,destination)<g.radius or not G.valid(s,g.species,destination,g.radius,g.profile.exclusiveSameSpecies,g.id) then return false end
 g.destination=destination;g.started=now;return true
end
function G.finish(g:any,now:number,success:boolean)
 if success then g.center=g.destination end
 g.destination=nil;g.nextMigration=now+(if success then g.profile.migrationSeconds else 15)
end
function G.force(s:any,p:any,radius:number,now:number):number
 local n=0
 for _,g in pairs(s.groups) do
  if g.profile.migrationSeconds and not g.destination and dist(g.center,p)<=radius then g.nextMigration=now;n+=1 end
 end
 return n
end
return table.freeze(G)
