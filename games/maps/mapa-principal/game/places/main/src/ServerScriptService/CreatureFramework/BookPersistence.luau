--!strict
-- Per-player monotonic Book ledger. Store adapter methods may yield; transform never yields.
local B={}
local function validId(v:any):boolean return type(v)=="string" and string.match(v,"^[1-9]%d%d%d%d%d$")~=nil end
function B.decode(raw:any,core:any):any
 if raw==nil then return core.new() end
 assert(type(raw)=="table" and raw.schema==1 and type(raw.mobs)=="table","unsupported Book schema")
 local out=core.new();local count=0
 for id,e in pairs(raw.mobs) do
  count+=1;assert(count<=10000 and validId(id) and type(e)=="table","invalid Book entry")
  assert(type(e.firstAt)=="number" and e.firstAt>=0 and e.firstAt<math.huge and (e.reason=="Kill" or e.reason=="Interaction" or e.reason=="Observation"),"invalid Book discovery")
  out.mobs[id]={firstAt=e.firstAt,reason=e.reason}
 end
 return out
end
function B.new(core:any,registry:any,store:any):any
 return {core=core,registry=registry,store=store,sessions={},cursor=1}
end
function B.session(s:any,userId:number):any
 assert(userId>0 and userId%1==0 and userId<2^53,"invalid user")
 local p=s.sessions[userId]
 if not p then p={userId=userId,key="u_"..tostring(userId),ledger=s.core.new(),ready=false,dirty=false,revision=0,busy=false,retryAt=0,failures=0,leaving=false,handles={},nextHandle=0};s.sessions[userId]=p end
 return p
end
local function fail(p:any,now:number,err:any)
 p.failures+=1;p.retryAt=now+math.min(60,2^math.min(6,p.failures));p.error=tostring(err):sub(1,200)
end
function B.load(s:any,p:any,now:number):boolean
 if p.ready then return true end
 if p.busy or now<p.retryAt or not s.store.canRead() then return false end
 p.busy=true
 local ok,value=pcall(function()return B.decode(s.store.get(p.key),s.core)end)
 p.busy=false
 if not ok then fail(p,now,value);return false end
 p.ledger=s.core.merge(value,p.ledger);p.ready=true;p.failures=0;p.retryAt=0;p.error=nil;return true
end
function B.discover(s:any,userId:number,speciesId:string,reason:string,origin:string,at:number):boolean
 local species=s.registry.get(speciesId);if not species then return false end
 local p=B.session(s,userId)
 local changed=s.core.discover(p.ledger,{speciesId=speciesId,reason=reason,origin=origin,at=at,verified=true},species)
 if changed then p.dirty=true;p.revision+=1 end
 return changed
end
function B.flush(s:any,p:any,now:number):boolean
 if not p.dirty then return p.ready end
 if not p.ready or p.busy or now<p.retryAt or not s.store.canWrite() then return false end
 p.busy=true
 local revision=p.revision
 local snapshot=s.core.merge(s.core.new(),p.ledger)
 local ok,value=pcall(function()
  local result=s.store.update(p.key,function(old:any)
   local prior=B.decode(old,s.core)
   return s.core.merge(prior,snapshot)
  end)
  assert(result~=nil,"Book update cancelled")
  return B.decode(result,s.core)
 end)
 p.busy=false
 if not ok then fail(p,now,value);return false end
 p.ledger=s.core.merge(value,p.ledger);p.dirty=p.revision~=revision;p.failures=0;p.retryAt=0;p.error=nil
 return not p.dirty
end
function B.tick(s:any,now:number,maxOperations:number):number
 local ids:{number}={};for id in pairs(s.sessions) do table.insert(ids,id) end;table.sort(ids)
 local n=#ids;if n==0 then s.cursor=1;return 0 end
 s.cursor=math.clamp(s.cursor,1,n)
 local work=0;local checked=0
 while checked<n and work<maxOperations do
  local id=ids[s.cursor];s.cursor=s.cursor%n+1;checked+=1
  local p=s.sessions[id]
  if not p then continue end
  if not p.ready and now>=p.retryAt and not p.busy and s.store.canRead() then B.load(s,p,now);work+=1
  elseif p.ready and p.dirty and now>=p.retryAt and not p.busy and s.store.canWrite() then B.flush(s,p,now);work+=1 end
  if p.leaving and p.ready and not p.dirty and not p.busy then s.sessions[id]=nil end
 end
 return work
end
function B.snapshot(s:any,userId:number,order:string,developer:boolean):any
 local p=B.session(s,userId);local all=s.registry.all();local found,total,percent=s.core.progress(p.ledger,all)
 local rows={}
 for _,species in s.core.ordered(p.ledger,all,order) do
  local row=s.registry.bookRow(species.id,developer)
  if row then
   if not p.handles[species.id] then p.nextHandle+=1;p.handles[species.id]="entry_"..tostring(p.nextHandle) end
   row.key=p.handles[species.id];row.firstAt=p.ledger.mobs[species.id].firstAt;row.reason=p.ledger.mobs[species.id].reason;table.insert(rows,row)
  end
 end
 return {ready=p.ready,discovered=found,total=total,percent=percent,unknown=total-found,rows=rows,schema=1}
end
return table.freeze(B)
