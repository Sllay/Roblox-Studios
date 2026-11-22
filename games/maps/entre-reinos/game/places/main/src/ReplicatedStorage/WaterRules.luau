--!strict
-- Deterministic fallback for a native voxel-water volume. The entire river
-- uses the same WorldProfile seed and level that WriteVoxelChannels generates.
-- This avoids treating visible water as dry ground when Humanoid transitions
-- briefly to Freefall or Running at the water surface.
local Profile=require("./WorldProfile")
local Water={}
function Water.submerged(seed: number,x: number,y: number,z: number): boolean
    if not Profile.validSeed(seed) or type(x)~="number" or type(y)~="number"
        or type(z)~="number" or x~=x or y~=y or z~=z then return false end
    local sample=Profile.sample(seed,x,z)
    -- Bank blend may have liquid behind it, but only below the same surface.
    -- Player R6 root is ~2 studs above its feet.
    return sample.riverDist<Profile.RIVER_HALF_WIDTH+8
        and y<=Profile.WATER_SURFACE+2.6
        and y>=Profile.BOUNDS.yMin-4
        and y-2.4<Profile.WATER_SURFACE
end
return Water
