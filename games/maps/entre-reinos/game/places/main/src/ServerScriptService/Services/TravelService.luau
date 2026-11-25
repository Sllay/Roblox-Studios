--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local shared=ReplicatedStorage:WaitForChild("Game")
local Profile=require(shared:WaitForChild("RegionalProfile"))
local Work=require(shared:WaitForChild("Living"):WaitForChild("WorkEngine"))
local R3=require(shared:WaitForChild("Living"):WaitForChild("R3Engine"))
local Inventory=require(shared:WaitForChild("Living"):WaitForChild("Inventory"))
local World=require(script.Parent:WaitForChild("WorldService"))
local Rig=require(script.Parent:WaitForChild("VehicleRig"))
local Service={}
local owner: Player?=nil
local regional: any=nil
local folder: Folder?=nil
local rigs: {[string]: any}={}
local stops: {any}={}
local dockModels: {[number]: Instance}={}
local riding: string?=nil
local input=0
local received=0
local speed=0
local exhausted=false
local mountHealth: RBXScriptConnection?=nil
local heading=1
local lastAction=0
local lastInput=0
local changePosition: ((Player, any) -> (boolean, string?))?=nil
local transit=false
local updateTime=0
local WALK_SPEED, RUN_SPEED, ROW_SPEED=17,26,9
local HORSE_PRICE=12

local remotes=shared
local steering=Instance.new("RemoteEvent")
steering.Name="ER_TravelSteering"
steering.Parent=remotes

local function character(player: Player): (BasePart?, Humanoid?)
    local avatar=player.Character
    local root=if avatar then avatar:FindFirstChild("HumanoidRootPart") else nil
    local human=if avatar then avatar:FindFirstChildOfClass("Humanoid") else nil
    if root and root:IsA("BasePart") and human and human.Health>0 then return root,human end
    return nil,nil
end

function Service.steer(player: Player, value: any): boolean
    if player~=owner or not riding or type(value)~="number" or not (value>=-1 and value<=1) then return false end
    local now=os.clock()
    if now-lastInput<0.045 then return false end
    lastInput,received,input=now,now,value
    return true
end
steering.OnServerEvent:Connect(Service.steer)

local function closeTo(root: BasePart, position: any, radius: number): boolean
    return math.abs(root.Position.X-position.x)<=radius
        and math.abs(root.Position.Y-position.y)<=8 and math.abs(root.Position.Z)<=2.5
end

local function nearStop(root: BasePart, limit: number): any
    for _,stop in ipairs(stops) do
        if math.abs(stop.moor.x-root.Position.X)<=limit then return stop end
    end
    return nil
end

local function nearbyCapital(x: number): (string?, any)
    if math.abs(x)<=12 then return "0",Profile.spawn(regional.seed) end
    local town=Profile.settlement(regional.seed,2)
    if town and math.abs(town.x-x)<=12 then return "2",{x=town.x,y=Profile.sample(regional.seed,town.x,0).height+4,z=0} end
    return nil,nil
end

local function mapStops()
    for _,crossing in ipairs(regional.graph.crossings) do
        if crossing.region~=0 then continue end
        for _,sign in ipairs({1,-1}) do
            local bank=if sign==1 then crossing.west else crossing.east
            for offset=2,32,1 do
                local x=bank.x+sign*offset
                local terrain=Profile.sample(regional.seed,x,0)
                if not terrain.waterSurface or terrain.waterSurface-terrain.height<1.8 then continue end
                table.insert(stops,{bank={x=bank.x,y=bank.y,z=0},moor={x=x,y=terrain.waterSurface,z=0}})
                break
            end
        end
        break
    end
end

local function drawDock(index: number,stop: any)
    if dockModels[index] or not World.isLoadedAt(stop.bank.x) then return end
    local hull=Instance.new("Model")
    hull.Name=if index==1 then "Ancoradouro do Vale" else "Ancoradouro da Margem"
    local function plank(name: string, size: Vector3,pose: CFrame): Part
        local p=Instance.new("Part")
        p.Name=name
        p.Anchored=true
        p.Size=size
        p.CFrame=pose
        p.Color=Color3.fromRGB(114,80,50)
        p.Material=Enum.Material.WoodPlanks
        p.Parent=hull
        return p
    end
    local length=math.abs(stop.moor.x-stop.bank.x)
    -- Lateral walk lane remains clear for native swimming. Dock alongside it.
    local y=math.max(stop.moor.y+0.5,stop.bank.y+0.35)
    local center=(stop.moor.x+stop.bank.x)/2
    plank("Píer",Vector3.new(length+1.2,0.52,3.8),CFrame.new(center,y,-1.05))
    for _,x in ipairs({stop.bank.x,stop.moor.x}) do
        plank("Pilote",Vector3.new(0.62,14,0.62),CFrame.new(x,y-6,-4.55))
        plank("Amarra",Vector3.new(0.7,1.35,0.7),CFrame.new(x,y+0.64,-4.55))
    end
    hull.Parent=folder
    dockModels[index]=hull
end

local function refreshRig(kind: string): any
    local record=regional.record[kind]
    local parent=folder
    if not record or not parent then return nil end
    local existing=rigs[kind]
    local position=record.position
    if not World.isLoadedAt(position.x) then return nil end
    if not existing then
        existing=Rig.create(kind,parent)
        rigs[kind]=existing
    end
    existing.model:PivotTo(CFrame.new(position.x,position.y,0)*CFrame.Angles(0,-heading*math.pi/2,0))
    existing.model:SetAttribute("ER_VehicleId",record.id)
    existing.model:SetAttribute("ER_Energy",record.energy)
    existing.model:SetAttribute("ER_Vitality",record.health)
    return existing
end

local function detachRider(human: Humanoid)
    local rig=if riding then rigs[riding] else nil
    local weld=if rig then rig.seat:FindFirstChild("SeatWeld") else nil
    if weld and weld:IsA("Weld") then weld:Destroy() end
    human.Sit=false
end

local function clearRider(player: Player)
    if riding and rigs[riding] then Rig.animate(rigs[riding],0) end
    riding=nil
    if regional then regional.record.rider=nil end
    speed,input=0,0
    exhausted=false
    if mountHealth then mountHealth:Disconnect(); mountHealth=nil end
    player:SetAttribute("ER_Riding",nil)
    local _,human=character(player)
    if human then human:SetStateEnabled(Enum.HumanoidStateType.Jumping,true) end
end

local function board(player: Player,kind: string,human: Humanoid): boolean
    local rig=refreshRig(kind)
    if not rig or riding or rig.seat:FindFirstChild("SeatWeld") then return false end
    riding=kind
    regional.record.rider=kind
    player:SetAttribute("ER_Riding",kind)
    human:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
    local record=regional.record[kind]
    local previousHealth=human.Health
    mountHealth=human.HealthChanged:Connect(function(health)
        if health<previousHealth and riding==kind then
            record.health=math.max(0,record.health-(previousHealth-health)*0.5)
        end
        previousHealth=health
    end)
    rig.seat:Sit(human)
    return true
end

function Service.start(player: Player,session: any,parent: Folder,
        checkpoint: (Player,any) -> (boolean,string?))
    owner,regional,changePosition=player,session,checkpoint
    local group=Instance.new("Folder")
    group.Name="ER_Travel"
    group.Parent=parent
    folder=group
    mapStops()
    if #stops==2 and not regional.record.boat then
        regional.record.boat={id="boat:2",position=table.clone(stops[1].moor),health=100}
    end
    local boat=regional.record.boat
    if boat and not boat.cargo then boat.cargo=Inventory.new(36) end
    local _,human=character(player)
    local saved=regional.record.rider
    if human and (saved=="mount" or saved=="boat") and regional.record[saved] then
        board(player,saved,human)
    end
end

function Service.stop()
    if owner then clearRider(owner) end
    if folder then folder:Destroy() end
    owner,regional,folder,changePosition=nil,nil,nil,nil
    table.clear(rigs)
    table.clear(stops)
    table.clear(dockModels)
    transit=false
    input,speed,updateTime,lastAction,lastInput,received=0,0,0,0,0,0
end

function Service.busy(): boolean return transit end

function Service.status(player: Player,root: BasePart): string?
    if player~=owner or not regional or not regional.home.r3
        or regional.home.r3.prologue.stage~="sandbox" then return nil end
    if riding then
        return if riding=="mount" then "dismount"
            elseif nearStop(root,5) or regional.record.boat.health<=0 then "disembark" else nil
    end
    local mount=regional.record.mount
    if mount and mount.health>0 and closeTo(root,mount.position,7) then return "mount" end
    local boat=regional.record.boat
    if boat and boat.health>0 and closeTo(root,boat.position,6) then return "board" end
    local capital,arrival=nearbyCapital(root.Position.X)
    local setup=Profile.sample(regional.seed,18,0)
    if (not mount or mount.health<=0) and closeTo(root,{x=18,y=setup.height,z=0},6) then return "buy_mount" end
    if capital and closeTo(root,arrival,12) and regional.record.discovered[if capital=="0" then "2" else "0"] then
        return "travel"
    end
    return nil
end

function Service.cargo(player: Player, direction: any): any
    if player~=owner or not regional or transit or (direction~="load" and direction~="unload") then
        return {ok=false,error="travel_unavailable"}
    end
    local root=character(player)
    local boat=regional.record.boat
    local stop=if root then nearStop(root,7) else nil
    if not root or not stop or not boat or boat.health<=0 or not closeTo(root,boat.position,7)
        or math.abs(boat.position.x-stop.moor.x)>3 then return {ok=false,error="travel_unavailable"} end
    if os.clock()-lastAction<0.45 then return {ok=false,error="rate_limited"} end
    lastAction=os.clock()
    local bag=regional.home.r3.playerBag
    local from,to=if direction=="load" then bag else boat.cargo, if direction=="load" then boat.cargo else bag
    if not Inventory.transfer(from,to,"wood",1) then return {ok=false,error="travel_cargo_capacity"} end
    return {ok=true}
end

function Service.cargoAvailable(player: Player,root: BasePart): number?
    local boat=if regional then regional.record.boat else nil
    local stop=nearStop(root,7)
    if player~=owner or not boat or not stop or not closeTo(root,boat.position,7)
        or math.abs(boat.position.x-stop.moor.x)>3 then return nil end
    return Inventory.count(boat.cargo,"wood")
end

function Service.action(player: Player,arg: any): any
    if type(arg)~="string" or #arg>16 or player~=owner or transit then return {ok=false,error="travel_unavailable"} end
    local root,human=character(player)
    if not root or not human or Service.status(player,root)~=arg then return {ok=false,error="travel_unavailable"} end
    local now=os.clock()
    if now-lastAction<0.45 then return {ok=false,error="rate_limited"} end
    lastAction=now
    if arg=="buy_mount" then
        if not R3.payTravel(regional.home,HORSE_PRICE,"horse:1") then return {ok=false,error="travel_cost"} end
        local ground=Profile.sample(regional.seed,18,0)
        regional.record.mount={id="horse:1",health=100,energy=100,position={x=18,y=ground.height,z=0}}
        refreshRig("mount")
        return {ok=true}
    end
    if arg=="mount" or arg=="board" then
        return {ok=board(player,if arg=="mount" then "mount" else "boat",human),error="travel_unavailable"}
    end
    if arg=="dismount" or arg=="disembark" then
        local stop=nearStop(root,5)
        local record=regional.record[riding :: string]
        if arg=="disembark" and not stop and record.health<=0 and #stops==2 then
            stop=if root.Position.X<=(stops[1].moor.x+stops[2].moor.x)/2 then stops[1] else stops[2]
        end
        local x=if arg=="disembark" and stop then stop.bank.x else record.position.x
        local y=if arg=="disembark" and stop then stop.bank.y else record.position.y
        if not World.isLoadedAt(x) then return {ok=false,error="terrain_not_ready"} end
        detachRider(human)
        clearRider(player)
        root.CFrame=CFrame.new(x,y+4.1,0)
        root.AssemblyLinearVelocity=Vector3.zero
        return {ok=true}
    end
    if arg=="travel" and changePosition then
        local from=nearbyCapital(root.Position.X)
        local town=Profile.settlement(regional.seed,2)
        local x=if from=="0" and town then town.x else 0
        local ground=Profile.sample(regional.seed,x,0)
        -- SeatPart can briefly outlive its physical weld after disembarking.
        local seat=human.SeatPart
        if ground.wet or human.Sit or (seat and seat:FindFirstChild("SeatWeld")) then
            return {ok=false,error="travel_unavailable"}
        end
        transit=true
        root.Anchored=true
        local ready=World.ensureNear(regional.seed,x)
        if ready then task.wait() end
        local groundOnly=RaycastParams.new()
        groundOnly.FilterType=Enum.RaycastFilterType.Include
        groundOnly.FilterDescendantsInstances={workspace.Terrain}
        local hit=if ready then workspace:Raycast(Vector3.new(x,70,0),Vector3.new(0,-105,0),groundOnly) else nil
        local ok=false
        local err="terrain_not_ready"
        if hit and hit.Material~=Enum.Material.Water and human.Health>0 and player.Character==root.Parent then
            local destination={x=x,y=hit.Position.Y+3.6,z=0}
            local confirmed,safe,reason=pcall(changePosition,player,destination)
            ok,err=confirmed and safe,if confirmed then reason or "travel_unavailable" else "datastore_unavailable"
            if ok and player.Character==root.Parent and human.Health>0 then
                root.CFrame=CFrame.new(destination.x,destination.y,0)
                root.AssemblyLinearVelocity=Vector3.zero
            end
        end
        if root.Parent then root.Anchored=false end
        transit=false
        return {ok=ok,error=err}
    end
    return {ok=false,error="travel_unavailable"}
end

function Service.tick(dt: number)
    local player=owner
    if not player or not regional or not folder then return end
    updateTime+=dt
    if updateTime<0.065 then return end
    dt=math.min(updateTime,0.15)
    updateTime=0
    for i,stop in ipairs(stops) do drawDock(i,stop) end
    local root,human=character(player)
    if not root or not human then
        if riding then clearRider(player) end
        return
    end
    for _,kind in ipairs({"mount","boat"}) do
        local record=regional.record[kind]
        if not record then continue end
        if kind~=riding and math.abs(record.position.x-root.Position.X)>170 then
            if rigs[kind] then rigs[kind].model:Destroy(); rigs[kind]=nil end
        elseif not rigs[kind] then
            refreshRig(kind)
        end
    end
    if not riding then return end
    local record=regional.record[riding]
    local rig=rigs[riding]
    if not rig then clearRider(player); return end
    if rig.seat.Occupant~=human then
        -- Roblox may briefly leave Occupant unset while establishing welds.
        if human.SeatPart~=nil or not human.Sit then clearRider(player) end
        return
    end
    local command=if os.clock()-received<=0.3 and record.health>0 then input else 0
    local mounted=riding=="mount"
    if mounted then
        local wet=Profile.sample(regional.seed,record.position.x,0)
        local unsupported=wet.waterSurface and wet.waterSurface-wet.height>2
            and not Work.deckAt(regional.home,record.position.x,0,"mount")
        if unsupported and record.lastLand and World.isLoadedAt(record.lastLand.x) then
            record.position=table.clone(record.lastLand)
            detachRider(human)
            clearRider(player)
            root.CFrame=CFrame.new(record.position.x,record.position.y+4,0)
            root.AssemblyLinearVelocity=Vector3.zero
            refreshRig("mount")
            return
        end
        if record.energy<=1 then exhausted=true elseif record.energy>=23 then exhausted=false end
    end
    local gallop=mounted and math.abs(command)>0.92 and not exhausted
    local limit=if mounted then (if gallop then RUN_SPEED else WALK_SPEED) else ROW_SPEED
    speed+=math.clamp(command*limit-speed,-28*dt,28*dt)
    local old=record.position
    local nextX=math.clamp(old.x+speed*dt,-Profile.PLAY_EDGE,Profile.PLAY_EDGE)
    local ground=Profile.sample(regional.seed,nextX,0)
    local nextY=ground.height
    local valid=World.isLoadedAt(nextX)
    if mounted then
        local district=regional.active or regional.home
        local steppedX,surface=Work.mountStep(district,old,nextX)
        if steppedX and surface then
            nextX,nextY=steppedX,surface
            valid=World.isLoadedAt(nextX)
        else
            valid=false
        end
        if valid and math.abs(speed)>0.01 then
            local obstacle=RaycastParams.new()
            obstacle.FilterType=Enum.RaycastFilterType.Exclude
            obstacle.FilterDescendantsInstances={workspace.Terrain,rig.model,root.Parent :: Instance}
            obstacle.RespectCanCollide=true
            local hit=workspace:Raycast(Vector3.new(old.x,old.y+2,0),
                Vector3.new(nextX-old.x+math.sign(speed)*1.65,0,0),obstacle)
            valid=hit==nil
        end
        if valid then
            local support=Profile.sample(regional.seed,nextX,0)
            local deck=Work.deckAt(district,nextX,0,"mount")
            if not deck and (support.waterSurface or support.height)<=support.height then
                record.lastLand={x=nextX,y=nextY,z=0}
            end
        end
        local running=gallop and valid and math.abs(nextX-old.x)>WALK_SPEED*dt*0.8
        record.energy=math.clamp(record.energy+(if running then -13 else 8)*dt,0,100)
        player:SetAttribute("ER_MountEnergy",math.floor(record.energy))
    else
        if #stops~=2 then valid=false else nextX=math.clamp(nextX,stops[1].moor.x,stops[2].moor.x) end
        local water=Profile.sample(regional.seed,nextX,0)
        valid=valid and water.waterSurface~=nil and water.waterSurface-water.height>=1.25
        nextY=water.waterSurface or old.y
    end
    if valid then
        if mounted then speed=(nextX-old.x)/dt end
        record.position={x=nextX,y=nextY,z=0}
        if math.abs(speed)>0.5 then heading=math.sign(speed) end
    else
        speed=0
    end
    refreshRig(riding)
    Rig.animate(rig,speed)
end
return Service
