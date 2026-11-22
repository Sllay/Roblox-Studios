--!strict
-- Pure movement projection: Roblox native joystick / gamepad / keyboard input
-- lives in its usual X,Z plane; Entre Reinos movement lives in X,Y.
-- Input from PlayerModule:GetControls():GetMoveVector() is analog, NOT a binary key.
local Projection = {}

local function finite(value: any): boolean
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

function Projection.toLane(x: any, z: any): (number, number)
    if not finite(x) or not finite(z) then return 0, 0 end
    local lateral = math.clamp(x, -1, 1)
    local depth = math.clamp(-z, -1, 1) -- native joystick up is -Z
    local length = math.sqrt(lateral * lateral + depth * depth)
    if length > 1 then
        lateral /= length
        depth /= length
    end
    -- Preserve analog joystick speed, suppress hardware drift.
    if math.abs(lateral) < 0.07 then lateral = 0 end
    if math.abs(depth) < 0.07 then depth = 0 end
    return lateral, depth
end

function Projection.facing(lateral: number, vertical: number,
        swimming: boolean, lastFacing: number): number
    -- Side-view priority: facing left/right, or front/back on dry land only.
    if lateral > 0.20 then return -math.pi / 2 end
    if lateral < -0.20 then return math.pi / 2 end
    if not swimming and vertical > 0.30 then return 0 end
    if not swimming and vertical < -0.30 then return math.pi end
    return lastFacing
end

return Projection
