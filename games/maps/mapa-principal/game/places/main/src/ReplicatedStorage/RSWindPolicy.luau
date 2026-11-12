--!strict
-- Pure wind policy. The client owns only visual motion.
local W = {}
W.radius = 120
W.fullRadius = 72
W.maxActive = 48
W.updateInterval = 1/30
function W.fade(distance: number): number
    local t = math.clamp((W.radius-distance)/(W.radius-W.fullRadius),0,1)
    return t*t*(3-2*t)
end
function W.angle(time: number, phase: number, strength: number, distance: number, bush: boolean): number
    local gust = 0.65 + 0.35*math.sin(time*0.61+phase*0.37)
    local ripple = 0.70 + 0.30*math.sin(time*2.1+phase)
    local maxAngle = if bush then 1.3 else 2.4
    return math.rad(maxAngle)*math.clamp(strength/18,0,1)*gust*ripple*W.fade(distance)
end
function W.phase(x: number,z: number): number
    return (x*0.071+z*0.113) % (2*math.pi)
end
return W
