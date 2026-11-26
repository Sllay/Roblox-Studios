--!strict
local Inventory=require("./Inventory")
local Profile=require("../RegionalProfile")
local Production=require("./Production")
local Needs={}
local XP_LIMIT=900
local ACTIVITIES={gather=true,woodcut=true,mining=true,build=true,craft=true,farm=true,hunt=true}
local FAUNA_LIMIT=6

function Needs.level(npc: any, activity: string): number
    return 1+math.floor(math.sqrt(((npc.skills and npc.skills[activity]) or 0)/10))
end

function Needs.rate(npc: any,activity: string): number
    return (1+0.05*(Needs.level(npc,activity)-1))*(if npc.hunger>=75 then 0.75 else 1)
end

function Needs.learn(state: any,npc: any,activity: string,amount: number)
    if not state.production then return end
    npc.skills=npc.skills or {}
    npc.skills[activity]=math.min(XP_LIMIT,(npc.skills[activity] or 0)+amount)
end

local function finite(v: any,low: number,high: number): boolean
    return type(v)=="number" and v>=low and v<=high
end

function Needs.valid(state: any): boolean
    local data=state.production
    if not data then return true end
    if data.orchardClock~=nil and not finite(data.orchardClock,0,100) then return false end
    if data.fauna~=nil then
        local seen={}
        if type(data.fauna)~="table" or #data.fauna>FAUNA_LIMIT
            or not finite(data.breeding,0,180) or not finite(data.nextAnimal,1,1e9) then return false end
        for i,a in pairs(data.fauna) do
            if not finite(i,1,#data.fauna) or i%1~=0 or type(a)~="table"
                or not finite(a.id,1,data.nextAnimal-1) or a.id%1~=0 or seen[a.id]
                or not finite(a.x,-Profile.PLAY_EDGE,Profile.PLAY_EDGE) or not finite(a.z,-28,28)
                or not finite(a.home,-Profile.PLAY_EDGE+20,Profile.PLAY_EDGE-20)
                or not finite(a.health,1,3) or not finite(a.flight,-1,1) then return false end
            seen[a.id]=true
        end
    end
    for _,npc in ipairs(state.npcs) do
        if npc.skills~=nil then
            if type(npc.skills)~="table" then return false end
            for name,xp in pairs(npc.skills) do
                if not ACTIVITIES[name] or not finite(xp,0,XP_LIMIT) or xp%1~=0 then return false end
            end
        end
    end
    for _,b in ipairs(state.buildings) do
        local plot=b.plot
        if plot~=nil and (b.typeId~="farm" or type(plot)~="table"
            or (plot.stage~="prepare" and plot.stage~="seed" and plot.stage~="grow" and plot.stage~="harvest")
            or not finite(plot.progress,0,30) or type(plot.irrigated)~="boolean") then return false end
    end
    return true
end

local function terrainSafe(state: any,x: number,z: number): boolean
    return math.abs(x)<Profile.PLAY_EDGE-20 and not Profile.sample(state.seed,x,z).wet
end

local function spawnAnimal(state: any,x: number,z: number)
    if not terrainSafe(state,x,z) then return end
    local data=state.production
    table.insert(data.fauna,{id=data.nextAnimal,x=x,z=z,home=x,health=3,flight=0})
    data.nextAnimal+=1
end

function Needs.seedLandscape(state: any,origin: number)
    local data=state.production
    if data.fauna then return end
    data.fauna={}
    data.nextAnimal=1
    data.breeding=0
    for _,offset in ipairs({-23,24,-41,43}) do
        spawnAnimal(state,origin+offset,-3)
    end
    if #state.sites>=256 then return end
    -- A seed-specific finite wild seed source is established once per kingdom.
    for _,offset in ipairs({-21,22,-36,36}) do
        local x=origin+offset
        if terrainSafe(state,x,-4.4) then
            table.insert(state.sites,{id="wild_grain",item="grain",x=x,z=-4.4,remaining=8})
            break
        end
    end
    for _,offset in ipairs({23,-25,12,-14,30,-31}) do
        local x=origin+offset
        if #state.sites<256 and terrainSafe(state,x,3.5) then
            table.insert(state.sites,{id="forage_orchard",item="food",x=x,z=3.5,remaining=9})
            data.orchardClock=0
            break
        end
    end
end

local function complete(b: any): boolean
    return b.state=="complete" and b.health>0 and not b.ruined
end

function Needs.stepLand(state: any,dt: number)
    local data=state.production
    if not data then return end
    for _,b in ipairs(state.buildings) do
        if b.typeId~="farm" then continue end
        if not complete(b) then
            if b.ruined then b.plot=nil end
            continue
        end
        if not b.plot then
            local water=false
            for _,dx in ipairs({-24,-12,0,12,24}) do
                if Profile.sample(state.seed,b.x+dx,-10).wet or Profile.sample(state.seed,b.x+dx,0).wet then
                    water=true
                    break
                end
            end
            b.plot={stage="prepare",progress=0,irrigated=water}
        elseif b.plot.stage=="grow" then
            b.plot.progress=math.min(30,b.plot.progress+dt*(if b.plot.irrigated then 1 else 0.48))
            if b.plot.progress>=30 then b.plot.stage="harvest" end
        end
    end
    if data.orchardClock~=nil then
        data.orchardClock=math.min(100,data.orchardClock+dt)
        if data.orchardClock>=100 then
            for _,site in ipairs(state.sites) do
                if site.id=="forage_orchard" then
                    site.remaining=math.min(9,site.remaining+1)
                    break
                end
            end
            data.orchardClock=0
        end
    end
    if not data.fauna then return end
    for _,a in ipairs(data.fauna) do
        local dx=if a.flight~=0 then a.flight*3.8 else math.sin(state.elapsed*0.53+a.id)*1.1
        local x=a.x+dt*dx
        local z=a.z+math.sin(state.elapsed*0.78+a.id)*dt*0.8
        if math.abs(x-a.home)<14 and math.abs(z)<12 and terrainSafe(state,x,z) then a.x,a.z=x,z
        else a.flight=0 end
        if math.floor(state.elapsed/3)~=math.floor((state.elapsed-dt)/3) then a.flight=0 end
    end
    if #data.fauna>=2 and #data.fauna<FAUNA_LIMIT then
        data.breeding=math.min(180,data.breeding+dt)
        if data.breeding>=180 then
            local adult=data.fauna[1]
            spawnAnimal(state,adult.home,adult.z)
            data.breeding=0
        end
    end
end

local function nearbyFood(state: any,npc: any,work: any): any
    local best=nil
    local distance=math.huge
    for _,b in ipairs(state.buildings) do
        local d=math.abs(npc.x-b.x)
        if d<distance and work.stockAvailable(state,b,"food")>0
            and work.canReach(state,npc.x,b.x,"worker") then best,distance=b,d end
    end
    return best
end

local function rest(state: any,npc: any,dt: number,work: any): boolean
    local shelter=nil
    local nearest=math.huge
    for _,b in ipairs(state.buildings) do
        local dist=math.abs(npc.x-b.x)
        if dist<nearest and (b.typeId=="house" or b.typeId=="shelter" or b.typeId=="castle")
            and complete(b) and work.canReach(state,npc.x,b.x,"worker") then shelter,nearest=b,dist end
    end
    if shelter then
        npc.homeId=shelter.id
        if not work.walkToBuilding(state,npc,shelter,dt) then return true end
    end
    npc.activity="rest"
    npc.fatigue=math.max(0,npc.fatigue-dt*(if shelter then 4.5 else 2.5))
    if npc.fatigue<=30 then npc.state="idle" end
    return true
end

function Needs.care(state: any,npc: any,dt: number,work: any): boolean
    if not state.production then return false end
    if npc.hunger>=100 then npc.health=math.max(0,npc.health-dt*0.65) end
    if npc.hunger>=60 and Inventory.take(npc.inventory,"food",1) then npc.hunger-=45 end
    if npc.hunger>=70 and (npc.state=="idle" or npc.state=="meal" or npc.hunger>=95) then
        local depot=nearbyFood(state,npc,work)
        if depot then
            if npc.state~="meal" then work.releaseWorker(state,npc);npc.state="meal" end
            if work.walkToBuilding(state,npc,depot,dt) and work.stockAvailable(state,depot,"food")>0
                and Inventory.take(depot.stored,"food",1) then
                npc.hunger-=45
                npc.state="idle"
            end
            return true
        end
        for _,site in ipairs(state.sites) do
            if site.item~="food" or work.sourceAvailable(state,site)<1
                or not work.canReach(state,npc.x,site.x,"worker") then continue end
            if npc.state~="meal" then work.releaseWorker(state,npc);npc.state="meal" end
            if work.walkResident(state,npc,site.x,dt,site.z or -4)
                and work.sourceAvailable(state,site)>0 then
                site.remaining-=1
                npc.hunger=math.max(0,npc.hunger-45)
                npc.state="idle"
            end
            return true
        end
    end
    if npc.state=="meal" then npc.state="idle" end
    if npc.state=="rest" then return rest(state,npc,dt,work) end
    return false
end

local function farm(state: any,npc: any,dt: number,work: any): boolean
    local best=nil
    local distance=math.huge
    for _,b in ipairs(state.buildings) do
        local plot=b.plot
        if b.typeId~="farm" or not complete(b) or not plot or plot.stage=="grow"
            or not work.canReach(state,npc.x,b.x,"worker") then continue end
        if plot.stage=="harvest" and not Inventory.canAdd(npc.inventory,"grain",4) then continue end
        local dist=math.abs(npc.x-b.x)
        if dist<distance then best,distance=b,dist end
    end
    if not best then return false end
    local plot=best.plot
    if plot.stage=="seed" and Inventory.count(npc.inventory,"grain")<1 then
        for _,b in ipairs(state.buildings) do
            if work.stockAvailable(state,b,"grain")>0 and work.canReach(state,npc.x,b.x,"worker") then
                if work.walkToBuilding(state,npc,b,dt) and work.stockAvailable(state,b,"grain")>0 then
                    Inventory.transfer(b.stored,npc.inventory,"grain",1)
                end
                return true
            end
        end
        for _,site in ipairs(state.sites) do
            if site.item=="grain" and work.sourceAvailable(state,site)>0 and work.canReach(state,npc.x,site.x,"worker") then
                if work.walkResident(state,npc,site.x,dt,site.z) and work.sourceAvailable(state,site)>0
                    and Inventory.add(npc.inventory,"grain",1) then site.remaining-=1 end
                return true
            end
        end
        return false
    end
    if not work.walkToBuilding(state,npc,best,dt) then return true end
    npc.activity="farm"
    if plot.stage=="prepare" then
        plot.progress+=dt*Needs.rate(npc,"farm")*Production.toolRate(npc,"hoe")
        if plot.progress>=3 then
            plot.progress=0
            plot.stage="seed"
            Production.wear(npc,"hoe")
        end
    elseif plot.stage=="seed" and Inventory.take(npc.inventory,"grain",1) then
        plot.stage="grow"
        plot.progress=0
    elseif plot.stage=="harvest" and Inventory.add(npc.inventory,"grain",4) then
        plot.stage="prepare"
        plot.progress=0
        Needs.learn(state,npc,"farm",6)
    end
    return true
end

local function hunt(state: any,npc: any,dt: number,work: any): boolean
    if #(state.production.fauna or {})<=2 or (npc.huntDelay or 0)>state.elapsed or not Inventory.canAdd(npc.inventory,"meat",2)
        or Inventory.weight(npc.inventory)+5>npc.inventory.maxMass then return false end
    local best=nil
    local distance=90
    for i,a in ipairs(state.production.fauna or {}) do
        local dist=math.abs(a.x-npc.x)
        if dist<distance and work.canReach(state,npc.x,a.x,"worker") then best,distance=i,dist end
    end
    if not best then return false end
    local a=state.production.fauna[best]
    if not work.walkResident(state,npc,a.x,dt,a.z,6.8) then return true end
    a.health-=1
    npc.activity="hunt"
    npc.huntDelay=state.elapsed+1
    a.flight=if a.x>=npc.x then 1 else -1
    if a.health<=0 then
        assert(Inventory.add(npc.inventory,"meat",2) and Inventory.add(npc.inventory,"leather",1))
        table.remove(state.production.fauna,best)
        Needs.learn(state,npc,"hunt",8)
    end
    return true
end

function Needs.work(state: any,npc: any,dt: number,work: any): boolean
    if not state.production or npc.state~="idle" then return false end
    local role=npc.profession
    if (role=="farmer" or role=="common" or npc.order=="food") and Inventory.count(npc.inventory,"grain")<=1 then return farm(state,npc,dt,work) end
    if (role=="hunter" or role=="common" or npc.order=="food") and Inventory.count(npc.inventory,"meat")==0 then return hunt(state,npc,dt,work) end
    return false
end

return Needs
