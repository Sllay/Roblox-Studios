--!strict
-- T1-R1. Six physically separate records, leased with UpdateAsync.
-- No guest/in-memory fake saves when DataStore is unavailable.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Slots = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("SlotModel"))
local WorldProfile = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("WorldProfile"))
local Policy = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("SlotLeasePolicy"))
local store = DataStoreService:GetDataStore("EntreReinos_WorldSlots_v1")
local SaveSlotService = {}

local LOCK_SECONDS = 240
local AUTOSAVE_SECONDS = 70
local sessions: {[Player]: any} = {}

local function ownedToken(): string
    return game.JobId .. ":" .. HttpService:GenerateGUID(false)
end

local function cloneRecord(source: {[string]: any}): {[string]: any}
    local copy = table.clone(source)
    if source.position then copy.position = table.clone(source.position) end
    if source.regions then copy.regions = table.clone(source.regions) end
    if source.storyFlags then copy.storyFlags = table.clone(source.storyFlags) end
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
            if type(old) == "table" and old.deleted ~= true and not Slots.validWorld(old) then
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

local function trackWorld(player: Player, s: any)
    local now = os.clock()
    local elapsed = math.clamp(now - s.lastClock, 0, 180)
    s.lastClock = now
    s.data.clockSeconds += elapsed

    local char = player.Character
    local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
    local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
    if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
        local p = root.Position
        if p.X == p.X and p.Y == p.Y and math.abs(p.Z) <= 2
            and p.X >= -121 and p.X <= 121 and p.Y >= -24 and p.Y <= 76 then
            s.data.position = {x = p.X, y = p.Y, z = 0}
        end
    end
end

function SaveSlotService.save(player: Player, release: boolean?): (boolean, string?)
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
    s.busy = true
    if not s.pending then
        trackWorld(player, s)
        local record = cloneRecord(s.data)
        record.revision = s.data.revision + 1
        record.updatedAt = os.time()
        local id = ownedToken() .. ":save:" .. tostring(record.revision)
        record.lastWriteId = id
        record.lock = if release then nil else {token = s.token, expiresAt = os.time() + LOCK_SECONDS}
        s.pending = {record = record, id = id, releasing = release == true}
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
            return pending.record
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
    if not sessions[player] then return end
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

return SaveSlotService
