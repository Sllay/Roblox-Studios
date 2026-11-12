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
local names = {Tree_01="Canopy_01",Tree_08="Canopy_08",Tree_03="Canopy_03",Tree_12="Canopy_12",Bush_01="Bush_Canopy_01",Bush_03="Bush_Canopy_03"}
local pines = {["Pine_01.1"]="rbxassetid://17718985299",["Pine_03.1"]="rbxassetid://17718985397"}
function W.foliage(asset: string, species: string, name: string, material: string, mesh: string): boolean
    if asset=="79689531752352" then return names[species]==name and material=="LeafyGrass" end
    if asset=="18817890736" then return name=="Leaves" and pines[species]==mesh and material=="Plastic" end
    return false
end
function W.angle(time: number, phase: number, strength: number, distance: number, bush: boolean): number
    local gust = 0.75 + 0.25*math.sin(time*0.43+phase*0.37)
    local ripple = 0.55 + 0.45*math.sin(time*0.95+phase)
    local maxAngle = if bush then 1.5 else 3.0
    return math.rad(maxAngle)*math.clamp(strength/8,0,1)*gust*ripple*W.fade(distance)
end
function W.phase(x: number,z: number): number
    return (x*0.071+z*0.113) % (2*math.pi)
end
return W
