--!strict
-- Ordered intersection of one authoritative sweep with a lane-aligned volume.
-- Returns the first fraction in [0,1], including a segment starting inside.
local Trajectory={}

local function slab(origin: number,delta: number,low: number,high: number,
        near: number,far: number): (number,number)
    if math.abs(delta)<1e-8 then
        if origin<low or origin>high then return 1,0 end
        return near,far
    end
    local a=(low-origin)/delta
    local b=(high-origin)/delta
    return math.max(near,math.min(a,b)),math.min(far,math.max(a,b))
end

function Trajectory.intersection(x: number,y: number,dx: number,dy: number,
        center: number,bottom: number,halfWidth: number,height: number): number?
    local near,far=slab(x,dx,center-halfWidth,center+halfWidth,0,1)
    if near>far then return nil end
    near,far=slab(y,dy,bottom,bottom+height,near,far)
    return if near<=far then near else nil
end

function Trajectory.box(x: number,y: number,z: number,dx: number,dy: number,dz: number,
        halfX: number,halfY: number,halfZ: number): number?
    local near,far=slab(x,dx,-halfX,halfX,0,1)
    if near>far then return nil end
    near,far=slab(y,dy,-halfY,halfY,near,far)
    if near>far then return nil end
    near,far=slab(z,dz,-halfZ,halfZ,near,far)
    return if near<=far then near else nil
end

return Trajectory
