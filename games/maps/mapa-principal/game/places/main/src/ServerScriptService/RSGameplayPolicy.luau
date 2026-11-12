--!strict
-- Pure policy predicates plus a typed Roblox adapter. Runtime and CI share them.
local Policy = {}
function Policy.isAlive(health: number, dead: boolean): boolean
    return health > 0 and not dead
end
function Policy.inRadius(x: number, z: number, radius: number): boolean
    return x*x + z*z <= radius*radius
end
function Policy.inWorld(x: number, y: number, z: number, limit: number, floor: number): boolean
    return math.abs(x) <= limit and math.abs(z) <= limit and y >= floor
end
function Policy.supportValid(height: number, expected: number, normalY: number, tolerance: number, minNormal: number): boolean
    return math.abs(height-expected) <= tolerance and normalY >= minNormal
end
function Policy.humanoidAlive(humanoid: Humanoid?): boolean
    if humanoid == nil then return false end
    return Policy.isAlive(humanoid.Health, humanoid:GetState() == Enum.HumanoidStateType.Dead)
end
return Policy
