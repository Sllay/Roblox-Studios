--!strict
-- Extra native Terrain is outside the persisted playable voxel envelope.
local Profile=require("./RegionalProfile")
local Scenery={}
Scenery.VERSION=1
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
        local water=old.waterSurface
        local rise=stages+hill
        if water then
            -- Step the feeder beds gradually up to the headwaters. The
            -- underlying course uses the same meander as the adjacent seam.
            rise=9*smooth(depth/38)+11*smooth((depth-46)/52)+10*smooth((depth-112)/78)
            water+=rise
        end
        return {height=old.height+rise,waterSurface=water,wet=old.wet,
            material=if not water and old.height+rise>83 then "Slate" else old.material,biome=old.biome}
    elseif z>b.zMax then
        local t=smooth((z-b.zMax)/35)
        local shore=b.zMax+29+7*math.noise(x/94,phase,2.1)
        local blend=smooth((z-shore+12)/23)
        local bed=-12+2*math.noise(x/95,z/31,phase)
        local height=old.height+(bed-old.height)*blend
        local source=old.waterSurface
        local level=if source then source+(6-source)*t else 6
        local water=if height<level and (source~=nil or blend>0.1) then level else nil
        return {height=height,waterSurface=water,wet=water~=nil,
            material=if water and blend>0.05 then "Mud" elseif blend>0.05 then "Sand" else old.material,biome=old.biome}
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

function Scenery.cascade(seed: number,id: number): {any}?
    local bounds=Scenery.bounds(id,-1)
    local firstZ=b.zMin-24
    local center: number?=nil
    local best=3
    for x=bounds.xMin+1,bounds.xMax-1,2 do
        local sample=Profile.sample(seed,x,firstZ)
        if sample.wet and sample.riverDist<best then center,best=x,sample.riverDist end
    end
    if not center then return nil end
    local anchor=center
    -- Own exactly one sheet per course when a meander crosses a chunk edge.
    if Profile.sample(seed,anchor-2,firstZ).riverDist<best
        or Profile.sample(seed,anchor+2,firstZ).riverDist<best then return nil end
    local points={}
    for z=b.zMin-38,b.zMin-8,10 do
        local bestGap=math.huge
        local picked=anchor
        for x=anchor-12,anchor+12,2 do
            local sample=Profile.sample(seed,x,z)
            if sample.wet and sample.riverDist<bestGap then picked,bestGap=x,sample.riverDist end
        end
        local sample=Scenery.sample(seed,picked,z)
        if not sample.waterSurface then return nil end
        table.insert(points,{x=picked,y=sample.waterSurface+0.2,z=z})
    end
    return points
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
