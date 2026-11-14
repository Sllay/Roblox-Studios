--!strict
-- Sole authoritative species catalog. Technical ID is permanent; instances have separate IDs.
export type Stats={health:number,damage:number,walkSpeed:number,runSpeed:number}
export type Species={id:string,name:string,description:string,category:string,disposition:string,profile:string,biomes:{string},modelAssetId:string,preview:{source:string,assetId:string?},animations:{[string]:string},base:Stats,growth:Stats,levelCap:number,discoverable:boolean}
local chicken:Species={
 id="210080",name="Galinha",description="Pequena ave terrestre que procura sementes e insetos. Curiosa, desconfiada de movimentos bruscos e rápida para fugir de ameaças.",
 category="Animal",disposition="Passive",profile="PassivePrey",biomes={"emerald_valley"},
 modelAssetId="76960331636475",
 preview={source="asset-library/candidates/chicken-rig-43578265487-1/idle.png",assetId="107933673393998"},
 animations={Idle="123461134632415",Walk="128847740648973",Run="128056941885930",Peck="136236973921119",Flap="78561104554317"},
 -- Provisional balance. Speeds match measured source gait, not final gameplay tuning.
 base={health=20,damage=0,walkSpeed=0.397,runSpeed=0.736},
 growth={health=0.08,damage=0.08,walkSpeed=0.01,runSpeed=0.01},
 levelCap=10,discoverable=true,
}
local R={}
R.levelsEnabled=false
local biomeNames:{[string]:string}={emerald_valley="Vale Esmeralda"}
function R.biomeName(id:string):string? return biomeNames[id] end
local data:{[string]:Species}={}
local function freezeSpecies(s:Species):Species
 table.freeze(s.biomes);table.freeze(s.preview);table.freeze(s.animations);table.freeze(s.base);table.freeze(s.growth)
 return table.freeze(s)
end
function R.validate(s:Species):boolean
 assert(#s.id==6 and string.match(s.id,"^[1-9]%d%d%d%d%d$")~=nil,"invalid species ID")
 assert(#s.name>0 and #s.description>0 and #s.preview.source>0 and #s.biomes>0,"missing Book metadata")
 assert(s.disposition=="Passive" or s.disposition=="Neutral" or s.disposition=="Aggressive","invalid disposition")
 for _,biome in s.biomes do assert(biomeNames[biome]~=nil,"unknown biome") end
 assert(#s.category>0 and #s.profile>0 and tonumber(s.modelAssetId)~=nil,"invalid species contract")
 assert(s.levelCap>=1 and s.levelCap%1==0 and s.levelCap<=100,"invalid level cap")
 for key,value in pairs(s.base) do assert(value>=0 and value<math.huge and value==value,"invalid base "..key) end
 for key,value in pairs(s.growth) do assert(value>=0 and value<=1,"invalid growth "..key) end
 assert(s.base.health>0 and s.base.runSpeed>=s.base.walkSpeed,"invalid locomotion")
 if s.preview.assetId then assert(string.match(s.preview.assetId,"^%d+$")~=nil,"invalid preview asset") end
 for _,name in {"Idle","Walk","Run"} do assert(tonumber(s.animations[name])~=nil,"missing locomotion clip") end
 return true
end
local function register(s:Species)
 R.validate(s);assert(data[s.id]==nil,"duplicate species ID");data[s.id]=freezeSpecies(s)
end
register(chicken)
table.freeze(data)
function R.get(id:string):Species? return data[id] end
function R.all():{Species}
 local result:{Species}={};for _,s in pairs(data) do table.insert(result,s) end
 table.sort(result,function(a,b)return a.id<b.id end);return result
end
function R.stats(s:Species,level:number,enabled:boolean):Stats
 assert(level%1==0 and level>=1 and level<=s.levelCap,"invalid level")
 local n=if enabled then level-1 else 0
 local function scale(v:number,g:number):number return v*(1+g*n) end
 return {health=math.floor(scale(s.base.health,s.growth.health)+.5),damage=math.floor(scale(s.base.damage,s.growth.damage)+.5),walkSpeed=scale(s.base.walkSpeed,s.growth.walkSpeed),runSpeed=scale(s.base.runSpeed,s.growth.runSpeed)}
end
function R.previewStats(s:Species):{level1:Stats,level10:Stats,levelHigh:number}
 local high=math.min(10,s.levelCap)
 return {level1=R.stats(s,1,true),level10=R.stats(s,high,true),levelHigh=high}
end
return table.freeze(R)
