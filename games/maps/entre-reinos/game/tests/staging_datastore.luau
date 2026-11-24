-- Executed from the staging probe. Store names are isolated from gameplay.
local Http=game:GetService("HttpService")
local dataStores=game:GetService("DataStoreService")
local namespace="ER_F1_Test_"..Http:GenerateGUID(false):gsub("-",""):sub(1,16)
local Slots=loadCandidate("SlotModel")
local Living=loadCandidate("LivingModel")
local Work=loadCandidate("WorkEngine")
local Inventory=loadCandidate("Inventory")
local worldKey=Slots.key(1,1)
local main=dataStores:GetDataStore(namespace)
local backups=dataStores:GetDataStore(namespace.."B",worldKey)
local seed=516639272
local opened=true
local player={UserId=1,GetAttribute=function(_,key) return opened and key=="ER_WorldLoaded" end}
local failBackup=false
local loseReply=false

-- Faults surround real UpdateAsync calls. The names resolved below always
-- point to this run's disposable namespace, including backup scopes.
local function testStore(name,scope)
    local isBackup=name=="EntreReinos_RulesetBackups_v1"
    assert(isBackup or name=="EntreReinos_WorldSlots_v1")
    local store=dataStores:GetDataStore(if isBackup then namespace.."B" else namespace,scope)
    return {
        GetAsync=function(_,key) return store:GetAsync(key) end,
        UpdateAsync=function(_,key,transform)
            if isBackup and failBackup then error("injected backup unavailable") end
            local result=store:UpdateAsync(key,transform)
            if not isBackup and loseReply then
                loseReply=false
                error("injected lost reply after real write")
            end
            return result
        end,
    }
end
local probeGame={JobId="ER_F1_Probe"}
function probeGame:GetService(name)
    if name=="DataStoreService" then
        return {GetDataStore=function(_,store,scope) return testStore(store,scope) end}
    end
    return game:GetService(name)
end

local legacy=Slots.newWorld(seed,os.time(),loadCandidate("WorldProfile").spawn(seed))
legacy.rulesetVersion=2
legacy.living=Living.new(seed)
assert(main:UpdateAsync(worldKey,function(old)
    assert(old==nil)
    return legacy
end))
local first=loadSaveService(probeGame)
local second=loadSaveService(probeGame)
local entered,original=first.open(player,1)
assert(entered,original)
assert(not second.open(player,1),"second server acquired an active lease")

local state=assert(Living.restore(original.living,seed))
local depotOk,depot=Work.place(state,"stockpile",-16)
assert(depotOk)
local cost=loadCandidate("StructureDefs").get("stockpile")
depot.state="complete"
depot.progress=cost.buildSeconds
depot.delivered=table.clone(cost.cost)
for _=1,1800 do Work.step(state,0.1) end
assert(Inventory.count(depot.stored,"wood")>=8 and Inventory.count(depot.stored,"stone")>=3)
assert(state.stats.gathered>0 and state.stats.stored>0)
local preview,blueprint=Work.place(state,"shelter",18)
assert(preview)
for _=1,250 do
    Work.step(state,0.1)
    if (blueprint.claimed.wood or 0)>0 then break end
end
assert((blueprint.claimed.wood or 0)>0)
first.setLivingProvider(function() return state end)
failBackup=true
local saved,reason=first.save(player,false)
assert(not saved and reason=="backup_unavailable")
assert(main:GetAsync(worldKey).rulesetVersion==2)
failBackup=false
loseReply=true
saved,reason=first.save(player,false)
assert(not saved and reason=="datastore_unavailable")
assert(first.save(player,false),"retry failed to recognize committed revision")
assert(first.get(player).revision==1)
local copy=backups:GetAsync(Slots.legacyBackupKey(legacy))
assert(copy and copy.rulesetVersion==2 and copy.revision==0 and copy.lock==nil)
assert(#copy.living.buildings==0 and copy.living.sites[1].remaining==72)
assert(first.save(player,true),"could not release first session")

local reopened,record=second.open(player,1)
assert(reopened,record)
assert(record.rulesetVersion==Slots.RULESET_VERSION and record.revision==2)
local restored=assert(Living.restore(record.living,seed))
assert(restored.buildings[2].claimed.wood==blueprint.claimed.wood)
for _,site in ipairs(restored.sites) do site.remaining=0 end
for _=1,1500 do Work.step(restored,0.1) end
assert(restored.buildings[2].state=="complete")
assert(restored.stats.delivered==11)
second.setLivingProvider(function() return restored end)
assert(second.save(player,true))
for index=2,6 do assert(main:GetAsync(Slots.key(1,index))==nil) end
-- Retain the legacy backup and synthetic slot for audit in this namespace.
local datastoreResult={actual=true,locking=true,reconnected=true,backup=true,
    failureRecovery=true,delivered=restored.stats.delivered,otherSlotsUntouched=true}
