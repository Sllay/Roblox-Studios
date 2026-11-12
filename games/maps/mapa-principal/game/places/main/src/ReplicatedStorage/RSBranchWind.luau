--!strict
-- Bone.Transform is visual-only; works with an authored skinned canopy.
-- No EditableMesh dependency. Root and lower canopy remain fixed.
local B={}
B.maxActive=8
B.interval=1/20
B.maxBones=32
function B.weight(height:number):number
    local t=math.clamp((height-.45)/.55,0,1)
    return t*t*(3-2*t)
end
function B.angle(time:number,phase:number,height:number,strength:number,distanceFade:number):number
    local w=B.weight(height)
    local gust=.75+.25*math.sin(time*.63+phase*.7)
    local flutter=.55+.45*math.sin(time*2.3+phase)
    return math.rad(5)*w*math.clamp(strength/8,0,1)*distanceFade*gust*flutter
end
function B.transform(axis:Vector3,time:number,phase:number,height:number,strength:number,fade:number):CFrame
    local a=B.angle(time,phase,height,strength,fade)
    if a==0 then return CFrame.identity end
    return CFrame.fromAxisAngle(axis,a)*CFrame.Angles(0,a*.18*math.sin(time*3.1+phase),0)
end
return B
