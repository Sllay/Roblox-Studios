-- Disposable Open Cloud runtime. The SaveSlotService adapter routes every
-- DataStore name into the same unpredictable synthetic namespace.
local Slots=loadCandidate("SlotModel")
local Profile=loadCandidate("RegionalProfile")
local Regions=loadCandidate("RegionalWorld")
local Living=loadCandidate("LivingModel")
local R3=loadCandidate("R3Engine")
local Work=loadCandidate("WorkEngine")
local Market=loadCandidate("Market")
local Http=game:GetService("HttpService")
local dataStores=game:GetService("DataStoreService")
local prefix="ER_T2R2_"..Http:GenerateGUID(false):gsub("-",""):sub(1,16)
local seed=516639272
local player={UserId=1,GetAttribute=function(_,key) return key=="ER_WorldLoaded" end}
local key=Slots.key(1,1)
local main=dataStores:GetDataStore(prefix)
local backup=dataStores:GetDataStore(prefix.."B",key)
local failBackup,loseReply=false,false
local adapter={JobId="ER_T2R2_Probe"}
function adapter:GetService(name)
    if name~="DataStoreService" then return game:GetService(name) end
    return {
        GetDataStore=function(_,name,scope)
            local isBackup=name=="EntreReinos_RulesetBackups_v1"
            assert(isBackup or name=="EntreReinos_WorldSlots_v1")
            local store=dataStores:GetDataStore(if isBackup then prefix.."B" else prefix,scope)
            return {
                GetAsync=function(_,id) return store:GetAsync(id) end,
                UpdateAsync=function(_,id,callback)
                    if isBackup and failBackup then error("test: backup unavailable") end
                    local value=store:UpdateAsync(id,callback)
                    if not isBackup and loseReply then
                        loseReply=false
                        error("test: response lost after real write")
                    end
                    return value
                end,
            }
        end,
        GetRequestBudgetForRequestType=function(_,request)
            return dataStores:GetRequestBudgetForRequestType(request)
        end,
    }
end
local home=Living.new(seed)
R3.ensure(home,false)
assert(Work.initializeVillage(home))
local regional=assert(Regions.new(seed,home,nil,Profile.spawn(seed)))
local town=assert(Profile.settlement(seed,2))
Regions.activate(regional,town.x)
local legacy=Slots.newWorld(seed,os.time(),Profile.spawn(seed))
legacy.living=home
legacy.regionWorld=Regions.snapshot(regional)
legacy.rulesetVersion=4
assert(Slots.validWorld(legacy))
assert(main:UpdateAsync(key,function(old) assert(old==nil);return legacy end))
local first,second=loadSaveService(adapter),loadSaveService(adapter)
local opened,original=first.open(player,1)
assert(opened and original.rulesetVersion==4 and not second.open(player,1))
local live=assert(Regions.new(seed,original.living,original.regionWorld,Slots.spawnPosition(original)))
local active=Regions.activate(live,0)
for _=1,240 do
    Work.step(active,0.1)
    Regions.stepEconomy(live,active,0.1)
end
assert(Market.diplomacy(live,"trade"))
assert(Market.diplomacy(live,"tribute"))
assert(Work.setOrder(active,active.npcs[1],"building"))
first.setLivingProvider(function() return live.home,Regions.snapshot(live) end)

failBackup=true
local ok,reason=first.save(player,false)
assert(not ok and reason=="backup_unavailable")
assert(main:GetAsync(key).rulesetVersion==4)
failBackup=false
loseReply=true
ok,reason=first.save(player,false)
assert(not ok and reason=="datastore_unavailable")
assert(first.save(player,false),"idempotent retry did not recognize persisted revision")
assert(first.get(player).revision==1)
local old=backup:GetAsync(Slots.legacyBackupKey(original))
assert(old.rulesetVersion==4 and old.living.production==nil and old.lock==nil)
assert(first.save(player,true))
local reopened,record=second.open(player,1)
assert(reopened and record.rulesetVersion==5 and record.revision==2)
assert(record.living.npcs[1].order=="building" and record.living.npcs[1].social)
assert(record.living.production.market.accord=="trade")
assert(record.regionWorld.foreign.npcs[1].id==1001 and record.regionWorld.foreign.elapsed>=23.5)
assert(record.regionWorld.foreign.production.stewardPlanned)
assert(second.save(player,true))
for index=2,6 do assert(main:GetAsync(Slots.key(1,index))==nil) end
local recoverUser={UserId=2,GetAttribute=function() return false end}
assert(main:UpdateAsync(Slots.key(2,1),function(current) assert(current==nil);return old end))
local recovered,copy=first.open(recoverUser,1)
assert(recovered and copy.rulesetVersion==4 and copy.living.production==nil)
assert(first.save(recoverUser,true))
return {actual=true,oldRuleset=4,newRuleset=5,backupRestored=true,backupFault=true,replyRetry=true,
    distinctSlots=true,preservedRegionalWork=true,bytes=#Http:JSONEncode(record)}
