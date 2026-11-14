--!strict
-- Logical and materialized population accounting. Reserve synchronously before engine spawn.
export type Caps={global:number,active:number,perChunk:number,perBiome:{[string]:number},perSpecies:{[string]:number}}
export type Record={id:string,species:string,biome:string,chunk:string,active:boolean,reserved:boolean,expiresAt:number}
export type Manager={caps:Caps,records:{[string]:Record},total:number,active:number,biomes:{[string]:number},chunks:{[string]:number},species:{[string]:number}}
local P={}
local function count(m:{[string]:number},k:string):number return m[k] or 0 end
local function bump(m:{[string]:number},k:string,delta:number)
 local n=count(m,k)+delta;assert(n>=0,"population underflow");if n==0 then m[k]=nil else m[k]=n end
end
local function key(biome:string,chunk:string):string return biome.."/"..chunk end
local function validCap(n:number):boolean return n>=0 and n%1==0 and n<math.huge end
function P.new(caps:Caps):Manager
 assert(validCap(caps.global) and validCap(caps.active) and validCap(caps.perChunk) and caps.active<=caps.global,"invalid caps")
 for _,v in pairs(caps.perBiome) do assert(validCap(v),"invalid biome cap") end
 for _,v in pairs(caps.perSpecies) do assert(validCap(v),"invalid species cap") end
 local copy={global=caps.global,active=caps.active,perChunk=caps.perChunk,perBiome=table.clone(caps.perBiome),perSpecies=table.clone(caps.perSpecies)}
 table.freeze(copy.perBiome);table.freeze(copy.perSpecies);table.freeze(copy)
 return {caps=copy,records={},total=0,active=0,biomes={},chunks={},species={}}
end
function P.reserve(m:Manager,id:string,species:string,biome:string,chunk:string,active:boolean,now:number,ttl:number):(boolean,string?)
 if #id==0 or #chunk==0 or m.records[id] then return false,"identity" end
 if now~=now or math.abs(now)==math.huge or ttl<=0 or ttl>60 or ttl~=ttl then return false,"invalid lease" end
 local c=m.caps;local bc=c.perBiome[biome];local sc=c.perSpecies[species]
 if not bc or not sc then return false,"unregistered profile" end
 if m.total>=c.global or count(m.biomes,biome)>=bc or count(m.species,species)>=sc or count(m.chunks,key(biome,chunk))>=c.perChunk then return false,"population cap" end
 if active and m.active>=c.active then return false,"materialization cap" end
 m.records[id]={id=id,species=species,biome=biome,chunk=chunk,active=active,reserved=true,expiresAt=now+ttl}
 m.total+=1;if active then m.active+=1 end
 bump(m.biomes,biome,1);bump(m.chunks,key(biome,chunk),1);bump(m.species,species,1)
 return true,nil
end
function P.release(m:Manager,id:string):boolean
 local r=m.records[id];if not r then return false end
 m.records[id]=nil;m.total-=1;if r.active then m.active-=1 end
 bump(m.biomes,r.biome,-1);bump(m.chunks,key(r.biome,r.chunk),-1);bump(m.species,r.species,-1);return true
end
function P.expire(m:Manager,id:string,now:number):boolean
 local r=m.records[id];if r and r.reserved and now>=r.expiresAt then return P.release(m,id) end
 return false
end
function P.commit(m:Manager,id:string,now:number):boolean
 local r=m.records[id];if not r or not r.reserved then return false end
 if now>=r.expiresAt then P.release(m,id);return false end
 r.reserved=false;return true
end
function P.setActive(m:Manager,id:string,active:boolean):boolean
 local r=m.records[id];if not r or r.reserved then return false end
 if r.active==active then return true end
 if active and m.active>=m.caps.active then return false end
 r.active=active;m.active+=if active then 1 else -1;return true
end
function P.move(m:Manager,id:string,biome:string,chunk:string):boolean
 local r=m.records[id];if not r or r.reserved or #chunk==0 then return false end
 if r.biome==biome and r.chunk==chunk then return true end
 local bc=m.caps.perBiome[biome];if not bc then return false end
 if count(m.chunks,key(biome,chunk))>=m.caps.perChunk then return false end
 if biome~=r.biome and count(m.biomes,biome)>=bc then return false end
 bump(m.biomes,r.biome,-1);bump(m.chunks,key(r.biome,r.chunk),-1)
 r.biome=biome;r.chunk=chunk;bump(m.biomes,biome,1);bump(m.chunks,key(biome,chunk),1);return true
end
return table.freeze(P)
