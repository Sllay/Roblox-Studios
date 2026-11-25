--!strict
-- T1-R1. Six physically separate records, leased with UpdateAsync.
-- No guest/in-memory fake saves when DataStore is unavailable.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Slots = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("SlotModel"))
local WorldProfile = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("WorldProfile"))
local Policy = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("SlotLeasePolicy"))
local LivingModel = require(ReplicatedStorage:WaitForChild("Game")
    :WaitForChild("Living"):WaitForChild("LivingModel"))
local Regions = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("RegionalWorld"))
local store = DataStoreService:GetDataStore("EntreReinos_WorldSlots_v1")
local SaveSlotService = {}

local LOCK_SECONDS = 240
local AUTOSAVE_SECONDS = 70
local sessions: {[Player]: any} = {}
local livingSnapshotProvider: ((Player) -> (any, any))? = nil

function SaveSlotService.setLivingProvider(provider: (Player) -> (any, any))
    livingSnapshotProvider = provider
end

local function ownedToken(): string
    return game.JobId .. ":" .. HttpService:GenerateGUID(false)
end

local function cloneRecord(source: {[string]: any}): {[string]: any}
    local copy = table.clone(source)
    if source.position then copy.position = table.clone(source.position) end
    if type(source.frontierPosition)=="table" then copy.frontierPosition=table.clone(source.frontierPosition) end
    if source.regions then copy.regions = table.clone(source.regions) end
    if source.storyFlags then copy.storyFlags = table.clone(source.storyFlags) end
    if source.regionWorld then copy.regionWorld=LivingModel.clone(source.regionWorld) end
    if source.living then copy.living = LivingModel.clone(source.living) end
    return copy
end

local function lockedByOther(data: any, token: string, now: number): boolean
    return Policy.foreignLease(if type(data) == "table" then data.lock else nil, token, now)
end

local function seedValue(): number
    return Random.new():NextInteger(1, 2147483646)
end

function SaveSlotService.list(player: Player): (boolean, any)
    local result = {}
    for index = 1, Slots.COUNT do
        local success, value = pcall(function()
            return store:GetAsync(Slots.key(player.UserId, index))
        end)
        if not success then
            warn("[EntreReinos] Slot list failed for index ", index)
            return false, "datastore_unavailable"
        end
        local summary = Slots.summary(value, index)
        if type(value) == "table" and type(value.lock) == "table"
            and type(value.lock.expiresAt) == "number" then
            summary.inUse = value.lock.expiresAt > os.time()
        end
        result[index] = summary
    end
    return true, result
end

local function attachSession(player: Player, index: number, token: string, data: {[string]: any})
    local current = cloneRecord(data)
    sessions[player] = {
        index = index, token = token, data = current,
        pending = nil, busy = false, lastClock = os.clock(),
    }
    return cloneRecord(current)
end

function SaveSlotService.create(player: Player, index: number): (boolean, any)
    if not Slots.validIndex(index) or sessions[player] then
        return false, "bad_slot_or_session_active"
    end
    local token = ownedToken()
    local now = os.time()
    local seed = seedValue()
    local record = Slots.newWorld(seed, now, WorldProfile.spawn(seed))
    record.lock = {token = token, expiresAt = now + LOCK_SECONDS}
    record.lastWriteId = token .. ":create"
    local success, value = pcall(function()
        return store:UpdateAsync(Slots.key(player.UserId, index), function(old)
            if old ~= nil and (type(old) ~= "table" or old.deleted ~= true) then
                return nil
            end
            return record
        end)
    end)
    if not success then
        return false, "datastore_unavailable"
    end
    if type(value) ~= "table" or not value.lock or value.lock.token ~= token then
        return false, "slot_not_empty"
    end
    return true, attachSession(player, index, token, value)
end

function SaveSlotService.open(player: Player, index: number): (boolean, any)
    if not Slots.validIndex(index) or sessions[player] then
        return false, "bad_slot_or_session_active"
    end
    local token = ownedToken()
    local now = os.time()
    local success, value = pcall(function()
        return store:UpdateAsync(Slots.key(player.UserId, index), function(old)
            if not Slots.validWorld(old) or lockedByOther(old, token, now) then
                return nil
            end
            local nextRecord = cloneRecord(old)
            nextRecord.lock = {token = token, expiresAt = now + LOCK_SECONDS}
            return nextRecord
        end)
    end)
    if not success then
        return false, "datastore_unavailable"
    end
    if type(value) ~= "table" or not value.lock or value.lock.token ~= token then
        return false, "slot_missing_corrupt_or_locked"
    end
    return true, attachSession(player, index, token, value)
end

function SaveSlotService.delete(player: Player, index: number): (boolean, any)
    if not Slots.validIndex(index) or sessions[player] then
        return false, "bad_slot_or_session_active"
    end
    local token = ownedToken()
    local now = os.time()
    local success, value = pcall(function()
        return store:UpdateAsync(Slots.key(player.UserId, index), function(old)
            if lockedByOther(old, token, now) then
                return nil
            end
            if old ~= nil and not (type(old) == "table" and old.deleted == true)
                and not Slots.validWorld(old) then
                return nil -- Never delete an unknown future schema automatically.
            end
            return {deleted = true, schemaVersion = Slots.SCHEMA_VERSION, deletedAt = now, deleteId = token}
        end)
    end)
    if not success then
        return false, "datastore_unavailable"
    end
    if type(value) ~= "table" or value.deleted ~= true or value.deleteId ~= token then
        return false, "locked_or_corrupt_slot"
    end
    return true, {index = index, exists = false}
end

local function trackWorld(player: Player, s: any, record: any): number
    local now = os.clock()
    if record.frontierPosition and record.frontierPosition.revision==record.revision then
        record.frontierPosition.revision=record.revision+1
    end
    -- A failed world load must never record the menu spawn as game progress,
    -- nor advance the world's simulation clock while there is no active world.
    if player:GetAttribute("ER_WorldLoaded") ~= true then
        return now
    end
    local elapsed = math.clamp(now - s.lastClock, 0, 180)
    record.clockSeconds += elapsed

    local char = player.Character
    local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
    local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
    if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
        local p = root.Position
        if record.regionWorld and math.abs(p.Z)<=2 and Regions.validPosition({x=p.X,y=p.Y,z=0}) then
            record.regionWorld.position={x=p.X,y=p.Y,z=0}
        end
        if math.abs(p.Z)<=2 and Slots.validTravel(p.X,p.Y,0) then
            if Slots.validPosition(p.X,p.Y,0) then
                record.position={x=p.X,y=p.Y,z=0}
                record.frontierPosition=nil
            else
                record.frontierPosition={x=p.X,y=p.Y,z=0,revision=s.data.revision+1}
            end
        end
    end
    return now
end

local function backupLegacy(player: Player, session: any): (boolean, string?)
    local data=session.data
    local backup=cloneRecord(data)
    backup.lock=nil
    local key=Slots.legacyBackupKey(data)
    local ok,stored=pcall(function()
        local backups=DataStoreService:GetDataStore("EntreReinos_RulesetBackups_v1",
            Slots.key(player.UserId,session.index))
        return backups:UpdateAsync(key,function(existing)
            if existing==nil then return backup end
            -- Retries after a lost response reuse the first confirmed backup.
            -- A different generation or unknown record cannot be overwritten.
            if not Slots.validWorld(existing) or (existing.rulesetVersion or 1)~=(backup.rulesetVersion or 1)
                or existing.seed~=backup.seed or existing.createdAt~=backup.createdAt
                or existing.revision~=backup.revision or existing.lastWriteId~=backup.lastWriteId then return nil end
            return existing
        end)
    end)
    if not ok then return false,"backup_unavailable" end
    if not Slots.validWorld(stored) then return false,"backup_conflict" end
    return true,nil
end

function SaveSlotService.save(player: Player, release: boolean?, destination: any?): (boolean, string?)
    local s = sessions[player]
    if not s then
        return false, "no_session"
    end
    local startWait = os.clock()
    while s.busy and os.clock() - startWait < 12 do
        task.wait(0.05)
    end
    if s.busy then
        return false, "save_busy"
    end
    if sessions[player] ~= s then return false, "no_session" end
    if destination and (not Regions.validPosition(destination) or release) then
        return false,"invalid_travel_destination"
    end
    if destination and s.pending and (not s.pending.destination
        or s.pending.destination.x~=destination.x or s.pending.destination.y~=destination.y) then
        return false,"save_busy"
    end
    if destination and DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)<1 then
        return false,"save_busy"
    end
    s.busy = true
    if not s.pending then
        local record = cloneRecord(s.data)
        local upgrading = false
        if livingSnapshotProvider and player:GetAttribute("ER_WorldLoaded") == true then
            local invoked, state, regional = pcall(livingSnapshotProvider, player)
            if not invoked or (state ~= nil and not LivingModel.valid(state)) then
                s.busy = false
                warn("[EntreReinos] Refusing save of invalid population snapshot.")
                return false, "living_snapshot_invalid"
            end
            if state ~= nil then
                -- Materialize a deep copy. DataStore's UpdateAsync may retry
                -- while the live NPC simulation is still ticking.
                record.living = LivingModel.clone(state)
                if regional~=nil then
                    if not Regions.valid(regional,record.seed,state) then
                        s.busy=false
                        return false,"invalid_regional_snapshot"
                    end
                    local previous=record.regionWorld
                    record.regionWorld=LivingModel.clone(regional)
                    if previous then record.regionWorld.position=table.clone(previous.position) end
                end
                local society=state.production or (regional and regional.foreign and regional.foreign.production)
                record.rulesetVersion = if society then Slots.RULESET_VERSION
                    elseif record.regionWorld then Slots.REGIONAL_RULESET_VERSION else Slots.LEGACY_RULESET_VERSION
                upgrading = (s.data.rulesetVersion or 1)<record.rulesetVersion
                record.saveFormatVersion = Slots.SAVE_FORMAT_VERSION
            end
        end
        local capturedAt = trackWorld(player, s, record)
        if destination then
            if not record.regionWorld or record.regionWorld.rider then
                s.busy=false
                return false,"invalid_travel_destination"
            end
            record.regionWorld.position=table.clone(destination)
        end
        record.revision = s.data.revision + 1
        record.updatedAt = os.time()
        local id = ownedToken() .. ":save:" .. tostring(record.revision)
        record.lastWriteId = id
        if not Slots.validWorld(record) then
            s.busy = false
            return false, "world_snapshot_invalid"
        end
        if record.regionWorld then
            local serialized,encoded=pcall(HttpService.JSONEncode,HttpService,record)
            if not serialized or #encoded>Regions.MAX_JSON_BYTES then
                s.busy=false
                return false,"regional_snapshot_too_large"
            end
        end
        if upgrading then
            local backedUp,reason=backupLegacy(player,s)
            if not backedUp then
                s.busy = false
                return false,reason
            end
        end
        s.pending = {record = record, id = id, releasing = release == true,destination=destination}
        s.lastClock = capturedAt
    elseif release and not s.pending.releasing then
        -- First resolve an uncertain autosave before creating a release record.
        s.busy = false
        local ok, reason = SaveSlotService.save(player, false)
        if not ok then return false, reason end
        return SaveSlotService.save(player, true)
    end
    local pending = s.pending
    local success, result = pcall(function()
        return store:UpdateAsync(Slots.key(player.UserId, s.index), function(old)
            if not Slots.validWorld(old) then return nil end
            local decision = Policy.writeDecision(old, s.token, s.data.revision, pending.record.revision, pending.id)
            if decision == "already_applied" then return old end
            if decision ~= "apply" then return nil end
            local writing = table.clone(pending.record)
            writing.lock = if pending.releasing then nil
                else {token = s.token, expiresAt = os.time() + LOCK_SECONDS}
            return writing
        end)
    end)
    s.busy = false
    if not success then
        return false, "datastore_unavailable"
    end
    if type(result) ~= "table" or result.lastWriteId ~= pending.id
        or result.revision ~= pending.record.revision then
        return false, "session_conflict"
    end
    s.data = cloneRecord(result)
    s.pending = nil
    if pending.releasing then
        sessions[player] = nil
    end
    return true, nil
end

function SaveSlotService.active(player: Player): boolean
    return sessions[player] ~= nil
end

function SaveSlotService.get(player: Player)
    local s = sessions[player]
    return if s then s.data else nil
end

function SaveSlotService.index(player: Player): number?
    local s = sessions[player]
    return if s then s.index else nil
end

function SaveSlotService.autosave(player: Player)
    if not sessions[player] or player:GetAttribute("ER_WorldLoaded")~=true then return end
    if DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)<1 then
        return
    end
    local success, reason = SaveSlotService.save(player, false)
    if not success then
        warn("[EntreReinos] Autosave not confirmed: ", reason)
    end
end

function SaveSlotService.startAutosave()
    task.spawn(function()
        while true do
            task.wait(AUTOSAVE_SECONDS)
            for player, _ in pairs(sessions) do
                SaveSlotService.autosave(player)
            end
        end
    end)
end

function SaveSlotService.abortActivation(player: Player): (boolean, string?)
    -- Release ONLY the lease, preserving the world seed and the last good position.
    -- A transient datastore throttle cannot permanently trap an in-memory session.
    local s = sessions[player]
    if not s then return true, nil end
    if s.busy or s.pending then return false, "session_busy_or_missing" end
    s.busy = true
    local lastError = "datastore_unavailable"
    for attempt = 1, 3 do
        local success, result = pcall(function()
            return store:UpdateAsync(Slots.key(player.UserId, s.index), function(old)
                if not Slots.validWorld(old) then return nil end
                if old.revision ~= s.data.revision
                    or old.lastWriteId ~= s.data.lastWriteId then return nil end
                if old.lock == nil then
                    -- Idempotent retry after a response was lost.
                    return old
                end
                if type(old.lock) ~= "table" or old.lock.token ~= s.token then
                    return nil
                end
                local unlocked = cloneRecord(old)
                unlocked.lock = nil
                return unlocked
            end)
        end)
        if success then
            if Slots.validWorld(result) and result.lock == nil
                and result.revision == s.data.revision
                and result.lastWriteId == s.data.lastWriteId then
                sessions[player] = nil
                s.busy = false
                return true, nil
            end
            lastError = "session_conflict"
            break -- Never clear a newer or foreign lock.
        end
        lastError = "datastore_unavailable"
        if attempt < 3 then task.wait(attempt) end
    end
    s.busy = false
    return false, lastError
end


-- Lobby-owned creation does not open or lock a gameplay session. The world
-- reserved server independently acquires the lease after teleport validation.
function SaveSlotService.createDetached(player: Player, index: number): (boolean, any)
    if not Slots.validIndex(index) or sessions[player] then
        return false, "bad_slot_or_session_active"
    end
    local token = ownedToken()
    local now = os.time()
    local seed = seedValue()
    local record = Slots.newWorld(seed, now, WorldProfile.spawn(seed))
    record.lastWriteId = token .. ":create_detached"
    -- Intentionally no lock: lobby never owns a world or a live simulation.
    local success, value = pcall(function()
        return store:UpdateAsync(Slots.key(player.UserId, index), function(old)
            if old ~= nil and (type(old) ~= "table" or old.deleted ~= true) then
                return nil
            end
            return record
        end)
    end)
    if not success then return false, "datastore_unavailable" end
    if not Slots.validWorld(value) or value.lastWriteId ~= record.lastWriteId then
        return false, "slot_not_empty"
    end
    return true, cloneRecord(value)
end

function SaveSlotService.inspect(player: Player, index: number): (boolean, any)
    if not Slots.validIndex(index) then return false, "invalid_slot" end
    local success, value = pcall(function()
        return store:GetAsync(Slots.key(player.UserId, index))
    end)
    if not success then return false, "datastore_unavailable" end
    if not Slots.validWorld(value) then return false, "slot_missing_corrupt_or_locked" end
    -- Access is always computed from the Player.UserId; never from client data.
    return true, Slots.summary(value, index)
end

return SaveSlotService
