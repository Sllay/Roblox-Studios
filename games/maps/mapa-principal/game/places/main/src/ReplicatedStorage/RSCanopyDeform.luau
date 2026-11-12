--!strict
-- Deterministic local-space deformation. No asset permissions bypass.
local D={}
D.maxVertices=2400
D.maxActive=2
D.interval=1/12
function D.weight(y:number,low:number,high:number):number
    local t=math.clamp(((y-low)/math.max(high-low,.0001)-.45)/.55,0,1)
    return t*t*(3-2*t)
end
function D.displacement(p:Vector3,low:number,high:number,width:number,time:number,phase:number,wind:Vector3,strength:number):Vector3
    local w=D.weight(p.Y,low,high)
    if w==0 or strength<=.01 then return Vector3.zero end
    local lateral=Vector3.yAxis:Cross(wind)
    local branch=math.sin(p.X/math.max(width,.01)*9+p.Z/math.max(width,.01)*5+time*2.2+phase)
    local gust=.65+.35*math.sin(time*.7+phase)
    local amount=math.min(width*.035,(high-low)*.025)*math.clamp(strength/8,0,1)*w
    return (wind*(gust*.7+branch*.3)+lateral*(branch*.4)+Vector3.yAxis*(math.sin(time*1.7+phase+p.Z)*.12))*amount
end
return D
