--!strict
-- T1-R3 server-only combat, projectile raycasts, enemy and physical coin views.
-- UI has no authority over position, damage, currency, target or raid state.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local World=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("WorldProfile"))
local R3=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("R3Engine"))
local living=ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living")
local Trajectory=require(living:WaitForChild("Trajectory"))
local Structures=require(living:WaitForChild("StructureDefs"))
local Combat={}
local owner: Player?=nil
local state: any=nil
local folder: Folder?=nil
local enemies: {[number]: Model}={}
local coins: {[number]: Part}={}
local storyFigures: {[string]: Model}={}
local arrows: {any}={}
local cooldowns: {[string]: number}={}
local cast=RaycastParams.new()
cast.FilterType=Enum.RaycastFilterType.Include
cast.FilterDescendantsInstances={workspace.Terrain}
cast.IgnoreWater=true
local MAX_PROJECTILES=10

local function part(model: Model,name: string,size: Vector3,offset: Vector3,color: Color3): Part
    local obj=Instance.new("Part")
    obj.Name=name
    obj.Size=size
    obj.CFrame=CFrame.new(offset)
    obj.Material=Enum.Material.SmoothPlastic
    obj.Color=color
    obj.Anchored=true
    obj.CanCollide=false
    obj.CanQuery=false
    obj.CanTouch=false
    obj.CastShadow=true
    obj.Parent=model
    return obj
end

local function groundAt(x: number): number
    local terrain=World.sample(state.seed,x,0)
    return if terrain.wet then World.WATER_SURFACE-1 else terrain.height
end

local function enemyModel(e: any): Model
    local m=Instance.new("Model")
    m.Name=(if e.story then "Story_" else "Raider_")..tostring(e.id)
    local root=part(m,"HumanoidRootPart",Vector3.new(1,1,1),
        Vector3.zero,Color3.new(0,0,0))
    root.Transparency=1
    m.PrimaryPart=root
    local isDuke=e.typeId=="infected_duke"
    local isRoyal=e.typeId=="duke" or e.typeId=="guard"
    local flesh=if isDuke then Color3.fromRGB(77,49,96)
        elseif e.typeId=="duke" then Color3.fromRGB(107,48,55)
        elseif e.typeId=="guard" then Color3.fromRGB(60,89,104)
        else Color3.fromRGB(58,48,55)
    part(m,"Torso",Vector3.new(2.3,2.8,1.3),Vector3.new(0,1.5,0),flesh)
    part(m,"Head",Vector3.new(1.55,1.4,1.4),Vector3.new(0,3.6,0),
        if isDuke then Color3.fromRGB(115,81,131)
        elseif isRoyal then Color3.fromRGB(199,157,115) else Color3.fromRGB(53,61,59))
    if isDuke or e.typeId=="duke" then
        part(m,"DucalCrown",Vector3.new(1.8,0.4,1.6),
            Vector3.new(0,4.55,0),Color3.fromRGB(196,157,66))
    end
    part(m,"Left Arm",Vector3.new(0.7,2.5,0.9),Vector3.new(-1.5,1.45,0),flesh)
    part(m,"Right Arm",Vector3.new(0.7,2.5,0.9),Vector3.new(1.5,1.45,0),flesh)
    part(m,"Left Leg",Vector3.new(0.9,1.8,1),Vector3.new(-0.55,-0.7,0),flesh)
    part(m,"Right Leg",Vector3.new(0.9,1.8,1),Vector3.new(0.55,-0.7,0),flesh)
    if not isRoyal then
        local hue=Color3.fromRGB(215,94,57)
        part(m,"EyeL",Vector3.new(0.3,0.2,0.07),Vector3.new(-0.37,3.75,-0.73),hue)
        part(m,"EyeR",Vector3.new(0.3,0.2,0.07),Vector3.new(0.37,3.75,-0.73),hue)
    end
    for _,child in ipairs(m:GetChildren()) do
        if child:IsA("BasePart") and child~=root then
            local joint=Instance.new("Motor6D")
            joint.Name="ER_"..child.Name
            joint.Part0=root
            joint.Part1=child
            local shoulder=if child.Name:find("Arm") then child.Size.Y*0.37
                elseif child.Name:find("Leg") then child.Size.Y*0.45 else 0
            joint.C0=child.CFrame*CFrame.new(0,shoulder,0)
            joint.C1=CFrame.new(0,shoulder,0)
            joint.Parent=root
            child.Anchored=false
            child.Massless=true
        end
    end
    if e.story then
        local gui=Instance.new("BillboardGui")
        gui.Size=UDim2.fromOffset(160,24)
        gui.StudsOffset=Vector3.new(0,5.8,0)
        gui.MaxDistance=65
        gui.Parent=root
        local title=Instance.new("TextLabel")
        title.BackgroundTransparency=1
        title.Text=e.label
        title.TextColor3=Color3.fromRGB(255,227,168)
        title.TextStrokeTransparency=0.3
        title.Font=Enum.Font.GothamSemibold
        title.TextSize=13
        title.Size=UDim2.fromScale(1,1)
        title.Parent=gui
    end
    m:SetAttribute("ER_NPCVisual",true)
    if not e.story then
        m:SetAttribute("ER_Enemy",true)
        m:SetAttribute("ER_EnemyId",e.id)
    end
    local x=e.x
    local y=groundAt(x)+1.6
    local pose=Vector3.new(x,y,0)
    m:SetAttribute("ER_NPCPose",pose)
    m:SetAttribute("ER_NPCVelocityX",0)
    m:SetAttribute("ER_NPCFacing",if e.side<0 then -math.pi/2 else math.pi/2)
    m:PivotTo(CFrame.new(pose))
    m.Parent=folder
    return m
end

local function syncViews()
    if not folder or not state then return end
    local activeStory: {[string]: boolean}={}
    for _,actor in ipairs(R3.storyActors(state.r3.prologue)) do
        activeStory[actor.id]=true
        local model=storyFigures[actor.id]
        if not model then
            model=enemyModel({id=actor.id,x=actor.x,typeId=actor.kind,story=true,label=actor.label,side=1})
            storyFigures[actor.id]=model
        end
        model:SetAttribute("ER_NPCPose",Vector3.new(actor.x,groundAt(actor.x)+1.6,-1))
        model:SetAttribute("ER_NPCActivity",actor.activity)
        model:SetAttribute("ER_NPCFacing",if actor.kind=="creature" then -math.pi/2 else math.pi/2)
    end
    for id,model in pairs(storyFigures) do
        if not activeStory[id] then model:Destroy(); storyFigures[id]=nil end
    end
    local live: {[number]: boolean}={}
    for _,e in ipairs(state.r3.enemies) do
        live[e.id]=true
        local model=enemies[e.id]
        if not model then model=enemyModel(e); enemies[e.id]=model end
        local y=groundAt(e.x)+1.6
        local velocity=e.motionX or 0
        model:SetAttribute("ER_NPCVelocityX",velocity)
        if math.abs(velocity)>0.1 then
            model:SetAttribute("ER_NPCFacing",if velocity>0 then -math.pi/2 else math.pi/2)
        end
        model:SetAttribute("ER_NPCPose",Vector3.new(e.x,y,0))
        model:SetAttribute("ER_NPCActivity",if e.attackClock>1.42 then "strike" else "idle")
        model:SetAttribute("ER_EnemyHealth",math.max(0,e.hp))
    end
    for id,model in pairs(enemies) do
        if not live[id] then
            model:Destroy()
            enemies[id]=nil
        end
    end
    local active: {[number]: boolean}={}
    for _,drop in ipairs(state.r3.drops) do
        if not drop.claimed then
            active[drop.id]=true
            if not coins[drop.id] then
                local p=Instance.new("Part")
                p.Name="Coin_"..tostring(drop.id)
                p.Shape=Enum.PartType.Ball
                p.Size=Vector3.new(1,1,0.5)
                p.Material=Enum.Material.Metal
                p.Color=Color3.fromRGB(246,195,52)
                p.Anchored=true
                p.CanCollide=false
                p.CanTouch=false
                p.CanQuery=false
                p:SetAttribute("ER_CoinId",drop.id)
                p:SetAttribute("ER_CoinAmount",drop.value)
                p.Position=Vector3.new(drop.x,
                    World.sample(state.seed,drop.x,0).height+2,-1)
                p.Parent=folder
                coins[drop.id]=p
            end
        end
    end
    for id,p in pairs(coins) do
        if not active[id] then p:Destroy(); coins[id]=nil end
    end
end

local function cleanup()
    for _,p in pairs(coins) do p:Destroy() end
    for _,m in pairs(enemies) do m:Destroy() end
    for _,m in pairs(storyFigures) do m:Destroy() end
    storyFigures={}
    for _,v in ipairs(arrows) do if v.part then v.part:Destroy() end end
    coins={}
    enemies={}
    arrows={}
    cooldowns={}
end

function Combat.start(player: Player,living: any,worldFolder: Folder)
    cleanup()
    owner=player
    state=living
    folder=worldFolder
    syncViews()
end

function Combat.stop()
    cleanup()
    owner=nil
    state=nil
    folder=nil
end

local function playerRoot(player: Player): (BasePart?,Humanoid?)
    local char=player.Character
    if not char then return nil,nil end
    local root=char:FindFirstChild("HumanoidRootPart")
    local h=char:FindFirstChildOfClass("Humanoid")
    if root and root:IsA("BasePart") and h and h.Health>0
        and math.abs(root.Position.Z)<5 then return root,h end
    return nil,nil
end

local function direction(root: BasePart): number
    return if root.CFrame.LookVector.X>=0 then 1 else -1
end

local function allowed(action: string,seconds: number): boolean
    local now=os.clock()
    if now-(cooldowns[action] or -1e9)<seconds then return false end
    cooldowns[action]=now
    return true
end

-- Return the first swept hit in the same X/Y lane used by the rendered
-- hostile rig. Terrain and standing fortifications can occlude the target.
local function sweep(origin: Vector3,goal: Vector3): (number?, number)
    local delta=goal-origin
    local ray=workspace:Raycast(origin,delta,cast)
    local limit=if ray then ray.Distance/delta.Magnitude else 1
    for _,b in ipairs(state.buildings) do
        local def=Structures.get(b.typeId)
        if def.kind=="defense" and b.health>0 and b.progress>=def.buildSeconds then
            local hit=Trajectory.intersection(origin.X,origin.Y,delta.X,delta.Y,
                b.x,b.y,0.55,def.height-1)
            if hit and hit>0 and hit<limit then limit=hit end
        end
    end
    local target: number?=nil
    for _,enemy in ipairs(state.r3.enemies) do
        local hit=Trajectory.intersection(origin.X,origin.Y,delta.X,delta.Y,
            enemy.x,groundAt(enemy.x)+0.35,1.25,5.4)
        if enemy.hp>0 and hit and hit<limit then target=enemy.id; limit=hit end
    end
    return target,limit
end

local function launch(position: Vector3,velocity: Vector3,damage: number): boolean
    if not folder or #arrows>=MAX_PROJECTILES then return false end
    local arrow=Instance.new("Part")
    arrow.Name="ER_Arrow"
    arrow.Size=Vector3.new(0.16,0.16,2)
    arrow.Anchored=true
    arrow.CanCollide=false
    arrow.CanTouch=false
    arrow.CanQuery=false
    arrow.Material=Enum.Material.Wood
    arrow.Color=Color3.fromRGB(205,171,103)
    arrow.CFrame=CFrame.lookAt(position,position+velocity)
    arrow.Parent=folder
    table.insert(arrows,{part=arrow,p=position,v=velocity,age=0,damage=damage})
    return true
end

function Combat.fireResident(npc: any,enemy: any): boolean
    local difference=enemy.x-npc.x
    local side=if difference<0 then -1 else 1
    local origin=Vector3.new(npc.x+side*0.8,groundAt(npc.x)+3.5,0)
    local flight=math.clamp(math.abs(enemy.x-origin.X)/42,0.4,0.72)
    local vertical=(groundAt(enemy.x)+3-origin.Y)/flight+workspace.Gravity*flight/2
    return launch(origin,Vector3.new((enemy.x-origin.X)/flight,vertical,0),10)
end

function Combat.action(player: Player,action: string,arg: any): any
    if player~=owner or not state then return {ok=false,error="world_not_loaded"} end
    local root,h=playerRoot(player)
    if not root or not h then return {ok=false,error="character_not_ready"} end
    if action=="r3_status" then return {ok=true,data=R3.summary(state)} end
    if action=="attack" then
        if not allowed("attack",0.45) then return {ok=false,error="rate_limited"} end
        local side=direction(root)
        local start=Vector3.new(root.Position.X-side*0.15,root.Position.Y,0)
        local target=sweep(start,start+Vector3.new(side*6,0,0))
        player:SetAttribute("ER_PlayerAttack",workspace:GetServerTimeNow())
        local hit=target~=nil and R3.damageEnemy(state,target,16)
        return {ok=true,hit=hit,target=if hit then target else nil}
    elseif action=="bow" then
        if state.r3.arrows<=0 then return {ok=false,error="no_arrows"} end
        if not allowed("bow",0.85) then return {ok=false,error="rate_limited"} end
        local side=direction(root)
        local pos=root.Position+Vector3.new(side*1.1,0.9,-root.Position.Z)
        if not launch(pos,Vector3.new(side*64,30,0),14) then
            return {ok=false,error="too_many_arrows"}
        end
        player:SetAttribute("ER_PlayerBow",workspace:GetServerTimeNow())
        state.r3.arrows-=1
        state.r3.stats.shots+=1
        return {ok=true,arrows=state.r3.arrows}
    elseif action=="drop_coin" then
        if not allowed("coin",0.3) then return {ok=false,error="rate_limited"} end
        local ok,result=R3.drop(state,root.Position.X,1)
        if ok then syncViews() end
        return {ok=ok,result=result,error=if not ok then result else nil}
    elseif action=="pickup_coin" then
        if not allowed("pickup_coin",0.2) then return {ok=false,error="rate_limited"} end
        local dropHeight=nil
        for _,item in ipairs(state.r3.drops) do
            if item.id==arg and not item.claimed then
                dropHeight=World.sample(state.seed,item.x,0).height+2
                break
            end
        end
        if dropHeight~=nil and math.abs(root.Position.Y-dropHeight)>10 then
            return {ok=false,error="too_far_from_coin"}
        end
        local ok,result=R3.pickup(state,arg,root.Position.X)
        if ok then syncViews() end
        return {ok=ok,result=result,error=if not ok then result else nil}
    elseif action=="take_wood" then
        if not allowed("take_wood",0.35) then
            return {ok=false,error="rate_limited"}
        end
        local ok,result=R3.takeWood(state,root.Position.X,root.Position.Y)
        return {ok=ok,result=result,error=if not ok then result else nil}
    elseif action=="craft_arrows" then
        if not allowed("craft_arrows",0.65) then
            return {ok=false,error="rate_limited"}
        end
        local ok,result=R3.craftArrows(state,root.Position.X,root.Position.Y)
        return {ok=ok,result=result,error=if not ok then result else nil}
    elseif action=="trade" then
        if type(arg)~="string" then return {ok=false,error="unknown_trade_item"} end
        if not allowed("trade",0.7) then return {ok=false,error="rate_limited"} end
        local ok,result=R3.trade(state,arg,root.Position.X,root.Position.Y)
        return {ok=ok,result=result,error=if not ok then result else nil}
    elseif action=="arm_defender" then
        if not allowed("equip",0.45) then return {ok=false,error="rate_limited"} end
        if type(arg)~="string" or #arg>32 then return {ok=false,error="invalid_equipment"} end
        local id,weapon=string.match(arg,"^(%d+):(%a+)$")
        if not id then return {ok=false,error="invalid_equipment"} end
        if math.abs(root.Position.X)>120 then return {ok=false,error="outside_region"} end
        local npcId=tonumber(id)
        if not npcId then return {ok=false,error="invalid_equipment"} end
        local npc=nil
        for _,n in ipairs(state.npcs) do if n.id==npcId then npc=n; break end end
        if not npc or math.abs(npc.x-root.Position.X)>15 then
            return {ok=false,error="too_far_from_defender"}
        end
        local ok,result=R3.arm(state,npcId,weapon)
        return {ok=ok,result=result,error=if not ok then result else nil}
    elseif action=="prologue" then
        if not allowed("command",0.5) then return {ok=false,error="rate_limited"} end
        if type(arg)~="string" or #arg>16 then return {ok=false,error="action_unavailable"} end
        local ok,result=R3.command(state,arg,root.Position.X)
        syncViews()
        return {ok=ok,result=result,error=if not ok then result else nil}
    end
    return {ok=false,error="invalid_action"}
end

function Combat.tick(dt: number)
    if not state or not folder then return end
    local elapsed=math.clamp(dt,0,0.12)
    -- Physics sweep against Roblox native Terrain; hits on enemies are
    -- resolved in authoritative X/Y with stable target IDs, never client hits.
    for i=#arrows,1,-1 do
        local a=arrows[i]
        a.age+=elapsed
        local nextVelocity=a.v+Vector3.new(0,-workspace.Gravity*elapsed,0)
        local nextPos=a.p+(a.v+nextVelocity)*0.5*elapsed
        local target,alpha=sweep(a.p,nextPos)
        local impact=alpha<1
        if target then R3.damageEnemy(state,target,a.damage) end
        if impact or a.age>3 or math.abs(nextPos.X)>126 or nextPos.Y< -28 then
            a.part:Destroy()
            table.remove(arrows,i)
        else
            a.p=nextPos
            a.v=nextVelocity
            a.part.CFrame=CFrame.lookAt(nextPos,nextPos+nextVelocity)
        end
    end
end

function Combat.present()
    syncViews()
end

return Combat
