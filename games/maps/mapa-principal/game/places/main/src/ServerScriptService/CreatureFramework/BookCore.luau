--!strict
-- Server-side discovery ledger. No client-authored discovery or duplicate species unlock.
export type Entry={firstAt:number,reason:string}
export type Ledger={schema:number,mobs:{[string]:Entry}}
export type Event={speciesId:string,reason:string,at:number,verified:boolean,origin:string}
export type Species={id:string,name:string,description:string,category:string,disposition:string,discoverable:boolean,biomes:{string},preview:{source:string,assetId:string?}}
local B={}
local reasons:{[string]:boolean}={Kill=true,Interaction=true,Observation=true}
function B.new():Ledger return {schema=1,mobs={}} end
function B.discover(ledger:Ledger,event:Event,known:boolean):boolean
 -- verified is set ONLY by server gameplay services after validation; not a remote payload.
 if not known or not event.verified or event.origin~="Natural" or not reasons[event.reason] then return false end
 if event.at<0 or event.at~=event.at or event.at==math.huge then return false end
 if not string.match(event.speciesId,"^[1-9]%d%d%d%d%d$") then return false end
 if ledger.mobs[event.speciesId] then return false end
 ledger.mobs[event.speciesId]={firstAt=event.at,reason=event.reason};return true
end
function B.merge(a:Ledger,b:Ledger):Ledger
 assert(a.schema==1 and b.schema==1,"ledger schema mismatch")
 local result=B.new()
 for _,ledger in {a,b} do
  for id,e in pairs(ledger.mobs) do
   local current=result.mobs[id]
   if not current or e.firstAt<current.firstAt or (e.firstAt==current.firstAt and e.reason<current.reason) then
    result.mobs[id]={firstAt=e.firstAt,reason=e.reason}
   end
  end
 end
 return result
end
function B.progress(ledger:Ledger,species:{Species}):(number,number,number)
 local discovered,total=0,0
 for _,s in species do
  if s.discoverable then total+=1;if ledger.mobs[s.id] then discovered+=1 end end
 end
 return discovered,total,if total==0 then 0 else 100*discovered/total
end
function B.ordered(ledger:Ledger,species:{Species},order:string):{Species}
 assert(order=="Discovery" or order=="Alphabetical","invalid sort")
 local rows:{Species}={}
 for _,s in species do if s.discoverable and ledger.mobs[s.id] then table.insert(rows,s) end end
 table.sort(rows,function(a,b)
  if order=="Discovery" then
   local x,y=ledger.mobs[a.id].firstAt,ledger.mobs[b.id].firstAt
   if x~=y then return x<y end
  end
  if a.name~=b.name then return a.name<b.name end
  return a.id<b.id
 end)
 return rows
end
function B.publicRow(s:Species,developer:boolean):{[string]:any}
 -- developer flag must come from server authorization. No technical ID in ordinary projection.
 local row:{[string]:any}={name=s.name,description=s.description,category=s.category,disposition=s.disposition,biomes=table.clone(s.biomes),previewAssetId=s.preview.assetId}
 if developer then row.id=s.id end
 return row
end
return table.freeze(B)
