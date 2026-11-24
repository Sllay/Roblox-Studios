--!strict
-- Shared preview and server physics, in studs and seconds.
local Ballistics={}
Ballistics.FULL_CHARGE=1.15
Ballistics.MAX_HOLD=3.5
Ballistics.MARK_HOLD=0.75

function Ballistics.velocity(seconds: number): (number,number)
    local fraction=math.clamp(seconds/Ballistics.FULL_CHARGE,0,1)
    return 30+64*fraction,21+31*fraction
end

function Ballistics.offset(vx: number,vy: number,gravity: number,t: number): (number,number)
    return vx*t,vy*t-gravity*t*t*0.5
end

return Ballistics
