--!strict
-- Extra native Terrain is outside the persisted playable voxel envelope.
local Profile=require("./RegionalProfile")
local Scenery={}
Scenery.VERSION=3
Scenery.ROW=64
Scenery.MAX_ASPECT=2.2
Scenery.CAMERA_DISTANCE=118
Scenery.VERTICAL_FOV=46
Scenery.EDGE_CHUNKS=2
Scenery.SEA_LEVEL=6
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
        -- The upstream course meanders independently of the mountain field.
        -- Its offset fades to zero at the persisted back edge.
        local bend=8*taper*math.noise(depth/54,phase,7.3)
        local channel=Profile.sample(seed,x-bend,z)
        local bed=channel.channelBed+rise
        local level=channel.channelSurface+rise
        local land=old.landHeight+stages+hill
        -- Raise the upland and river independently, then join both with a
        -- continuous bank. Widen the bank as relief increases upstream.
        local relief=math.max(0,land-level-(old.landHeight-channel.channelSurface))
        local bankWidth=channel.channelBankWidth+relief
        local shoulder=smooth((channel.riverDist-channel.channelWidth)/bankWidth)
        local height=bed+(land-bed)*shoulder
        local wet=shoulder<1 and height<level
        local material=if wet then "Mud" elseif shoulder<1 then "Sand"
            elseif height>83 then "Slate" else old.material
        return {height=height,waterSurface=if wet then level else nil,wet=wet,
            material=material,biome=old.biome}
    elseif z>b.zMax then
        local distance=z-b.zMax
        local shore=Profile.sample(seed,x,b.zMax)
        local mouthDepth=math.max(0,(shore.waterSurface or shore.height)-shore.height)
        -- The shore is the last edge of playable ground. The first marine
        -- voxel is on a submerged shelf even at high coastal escarpments.
        local shelf=math.min(shore.height,Scenery.SEA_LEVEL-Profile.CELL)
        local seabed=-16+2*math.noise(x/95,z/31,phase)
        local slope=smooth(distance/(Profile.CELL/2))
        local offshore=smooth((distance-Profile.CELL/2)/(8*Profile.CELL))
        local near=shore.height+(shelf-shore.height)*slope
        local height=near+(seabed-near)*offshore
        -- Only a river mouth has a local head of water. It descends into
        -- the shared sea level within three cells of the coast.
        local plume=(shore.channelSurface-Scenery.SEA_LEVEL)
            *smooth(mouthDepth/Profile.CELL)*(1-smooth(distance/(3*Profile.CELL)))
        local level=Scenery.SEA_LEVEL+plume
        local wet=height<level
        return {height=height,waterSurface=if wet then level else nil,wet=wet,
            material=if offshore>0.5 then "Mud" else "Sand",biome=old.biome}
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

function Scenery.vegetation(seed: number,id: number,row: number): {any}
    if row==1 then return {} end
    local bounds=Scenery.bounds(id,row)
    local result={}
    local spacing=if row<=-2 then 16 else 8
    local budget=if row==-3 then 5 elseif row==-2 then 8 else 13
    local phase=(seed%17749)/51
    for x=bounds.xMin+spacing/2,bounds.xMax-1,spacing do
        for z=bounds.zMin+spacing/2,bounds.zMax-1,spacing do
            -- Keep the playable lane, buildings and approaches clear.
            if row==0 and z>=-23 then continue end
            local clump=math.noise(x/45,z/33,phase)
            local detail=math.noise(x/11,z/9,phase+6)
            local px=x+detail*3
            local pz=z+math.noise(x/13,phase,z/15)*3
            local point=Scenery.sample(seed,px,pz)
            if point.wet or point.height>98 then continue end
            if math.abs(Scenery.sample(seed,px+3,pz).height-point.height)>3
                or math.abs(Scenery.sample(seed,px,pz+3).height-point.height)>3 then continue end
            local density=if point.biome=="forest" or point.biome=="heartland" then -0.11
                elseif point.biome=="rockland" or point.biome=="mountains" then 0.11 else 0.018
            local kind
            if clump+detail*0.28>=density and point.material=="Grass" then
                kind=if point.height>48 or point.biome=="forest" then "pine"
                    elseif detail>0.02 then "tree" else "broadleaf"
            elseif row>-2 then
                if point.material=="Rock" or point.material=="Slate" then kind=if detail>0 then "rock" else "pebble"
                elseif point.material=="Grass" and clump>density-0.15 then
                    kind=if detail>0.20 then "log" elseif detail>=0 then "bush" else "stick"
                elseif point.material=="Sand" and detail>0.17 then kind="pebble" end
            end
            if not kind then continue end
            table.insert(result,{x=px,y=point.height,z=pz,size=0.78+(detail+0.5)*0.42,
                angle=math.rad((seed+x*13+z*7)%360),kind=kind,tint=math.floor((clump+1)*97),
                score=clump+0.4*detail})
        end
    end
    table.sort(result,function(a,b) return a.score>b.score end)
    while #result>budget do table.remove(result) end
    return result
end
return Scenery
