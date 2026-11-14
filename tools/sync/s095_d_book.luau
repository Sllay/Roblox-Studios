do
local result={noPlaceWrites=true,passed=false}
local key="probe_"..game:GetService("HttpService"):GenerateGUID(false)
local store=Store.new("RSBookProbe_S095","s09_5")
local ok,err=pcall(function()
 local service=Persist.new(Core,Registry,store)
 local p=Persist.session(service,999999)
 p.key=key
 assert(Persist.load(service,p,0),"probe initial load")
 assert(Persist.discover(service,999999,"210080","Interaction","Natural",100))
 assert(Persist.flush(service,p,0),"probe save")
 local fresh=Persist.new(Core,Registry,store);local q=Persist.session(fresh,999999);q.key=key
 assert(Persist.load(fresh,q,0),"probe reload")
 local snap=Persist.snapshot(fresh,999999,"Discovery",false)
 assert(snap.ready and snap.discovered==1 and snap.percent==100 and snap.rows[1].id==nil)
 result.reload=true;result.progress=snap.percent
 -- Competing update, merge must keep old discovery and its earliest time.
 store.update(key,function(old)old.mobs["345678"]={firstAt=50,reason="Kill"};return old end)
 local stale=Persist.new(Core,Registry,store);local staleSession=Persist.session(stale,999999);staleSession.key=key;staleSession.ready=true
 assert(Persist.discover(stale,999999,"210080","Kill","Natural",200))
 assert(Persist.flush(stale,staleSession,0))
 local merged=store.get(key)
 assert(merged.mobs["210080"].firstAt==100 and merged.mobs["345678"].firstAt==50)
 result.merge=true;result.passed=true
end)
result.ok=ok;if not ok then result.error=tostring(err):sub(1,500) end
local clean,err2=pcall(function()store.removeProbe(key)end)
result.cleaned=clean;if not clean then result.cleanupError=tostring(err2):sub(1,300) end
return syncResult(result)
end
