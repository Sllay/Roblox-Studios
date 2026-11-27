--!strict
-- Extra native Terrain is outside the persisted playable voxel envelope.
local Profile=require("./RegionalProfile")
local Scenery={}
Scenery.VERSION=2
Scenery.ROW=64
Scenery.MAX_ASPECT=2.2
Scenery.CAMERA_DISTANCE=118
Scenery.VERTICAL_FOV=46
Scenery.EDGE_CHUNKS=2
local b=Profile.BOUNDS

local function smooth(v: number): number
    v=math.clamp(v,0,1)
    return v*v*(3-2*v)
end

function Scenery.bounds(id: number,row: number)
    local x=id*Profile.CHUNK_STUDS-Profile.CHUNK_STUDS/2
    local zMin=if row==0 then b.zMin elseif row==1 then b.zMax else b.zMin+row*Scenery.ROW
    local zMax=if row==0 then b.zMax else zMin+Scenery.ROW
    return {xMin=x,xMax=x+Profile.CHUNK_STUDS,yMin=-32,yMax=148,zMin=zMin,zMax=zMax}
end

function Scenery.sample(seed: number,x: number,z: number)
    local old=Profile.sample(seed,x,z)
    local phase=(seed%11369)/97
    if z<b.zMin then
        local depth=b.zMin-z
        local taper=smooth(depth/45)
        local stages=13*smooth(depth/64)+23*smooth((depth-44)/86)+25*smooth((depth-102)/88)
        local hill=taper*(math.noise(x/115,z/88,phase)*25+math.noise(x/58,z/44,phase)*10)
        local rise=9*smooth(depth/38)+11*smooth((depth-46)/52)+10*smooth((depth-112)/78)
        local bed=old.channelBed+rise
        local level=old.channelSurface+rise
        local land=old.landHeight+stages+hill
        -- Raise the upland and river independently, then join both with a
        -- continuous bank. Widen the bank as relief increases upstream.
        local relief=math.max(0,land-level-(old.landHeight-old.channelSurface))
        local bankWidth=old.channelBankWidth+relief
        local shoulder=smooth((old.riverDist-old.channelWidth)/bankWidth)
        local height=bed+(land-bed)*shoulder
        local wet=shoulder<1 and height<level
        local material=if wet then "Mud" elseif shoulder<1 then "Sand"
            elseif height>83 then "Slate" else old.material
        return {height=height,waterSurface=if wet then level else nil,wet=wet,
            material=material,biome=old.biome}
    elseif z>b.zMax then
        local distance=z-b.zMax
        local t=smooth(distance/35)
        local shore=b.zMax+29+7*math.noise(x/94,phase,2.1)
        local blend=smooth((z-shore+12)/23)
        local bed=-12+2*math.noise(x/95,z/31,phase)
        local height=old.height+(bed-old.height)*blend
        -- All tributaries converge to one foreground level. Away from a
        -- river, use that same level before the first coastal wet column.
        local shoulder=smooth((old.riverDist-old.channelWidth)/old.channelBankWidth)
        local level=6+(old.channelSurface-6)*(1-t)*(1-smooth(distance/12)*shoulder)
        local wet=height<level and (shoulder<1 or blend>0)
        local material=if wet and blend>0.05 then "Mud" elseif blend>0.05 then "Sand" else old.material
        return {height=height,waterSurface=if wet then level else nil,wet=wet,
            material=material,biome=old.biome}
    end
    return old
end

-- Worst allowed horizontal frustum at each layer. Leave a full chunk
-- of lead time for generation and add directional headroom while riding.
function Scenery.coverage(x: number,velocity: number,row: number): (number,number)
    local depth=if row<0 then -(b.zMin+row*Scenery.ROW) elseif row==0 then -b.zMin else -b.zMax
    local half=(Scenery.CAMERA_DISTANCE+depth)*math.tan(math.rad(Scenery.VERTICAL_FOV*0.5))*Scenery.MAX_ASPECT
        +Profile.CHUNK_STUDS*0.5
    local lead=math.clamp(velocity,-36,36)*1.45
    local cap=Profile.CHUNK_RADIUS+Scenery.EDGE_CHUNKS
    return math.max(-cap,math.floor((x-half+math.min(0,lead)+32)/64)),
        math.min(cap,math.floor((x+half+math.max(0,lead)+32)/64))
end

function Scenery.trees(seed: number,id: number,row: number): {any}
    local bounds=Scenery.bounds(id,row)
    local result={}
    local spacing=if row<=-2 then 16 else 8
    local phase=(seed%17749)/51
    for x=bounds.xMin+spacing/2,bounds.xMax-1,spacing do
        for z=bounds.zMin+spacing/2,bounds.zMax-1,spacing do
            local clump=math.noise(x/45,z/33,phase)
            local detail=math.noise(x/11,z/9,phase+6)
            local px=x+detail*3
            local pz=z+math.noise(x/13,phase,z/15)*3
            if row==1 and pz>b.zMax+14 then continue end
            local point=Scenery.sample(seed,px,pz)
            local density=if point.biome=="forest" or point.biome=="heartland" then -0.09
                elseif point.biome=="rockland" or point.biome=="mountains" then 0.10 else 0.015
            if clump+detail*0.28<density or point.wet or point.height>82 then continue end
            if math.abs(Scenery.sample(seed,px+4,pz).height-point.height)>3.4 then continue end
            table.insert(result,{x=px,y=point.height,z=pz,size=0.72+(detail+0.5)*0.53,
                angle=math.rad((seed+x*13+z*7)%360),conifer=point.height>48 or point.biome=="forest"})
            if #result>=(if row<=-2 then 8 else 13) then return result end
        end
    end
    return result
end
return Scenery
