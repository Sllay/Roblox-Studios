--!strict
-- Pure lease and revision decisions used by server UpdateAsync; no Roblox service side effects.
local Policy = {}

function Policy.foreignLease(lock: any, token: string, now: number): boolean
    if lock == nil then return false end
    if type(lock) ~= "table" or type(lock.token) ~= "string"
        or type(lock.expiresAt) ~= "number" or not (lock.expiresAt >= 0 and lock.expiresAt < math.huge) then
        return true -- Unknown lease schema blocks takeover.
    end
    return lock.token ~= token and lock.expiresAt > now
end

function Policy.writeDecision(old: any, token: string, expectedRevision: number,
        pendingRevision: number, writeId: string): string
    if type(old) ~= "table" then return "conflict" end
    if old.lastWriteId == writeId and old.revision == pendingRevision then
        if old.lock == nil or (type(old.lock) == "table" and old.lock.token == token) then
            return "already_applied"
        end
        return "conflict"
    end
    if type(old.lock) ~= "table" or old.lock.token ~= token then
        return "conflict"
    end
    if old.revision ~= expectedRevision or pendingRevision ~= expectedRevision + 1 then
        return "conflict"
    end
    return "apply"
end

return Policy
