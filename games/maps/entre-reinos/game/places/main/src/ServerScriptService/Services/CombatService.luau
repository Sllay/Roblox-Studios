--!strict
-- T1-R3 server-only combat, projectile raycasts, enemy and physical coin views.
-- UI has no authority over position, damage, currency, target or raid state.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local World=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("WorldProfile"))
local R3=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("R3Engine"))
local Combat={}
local owner: Player?=nil
local state: any=nil
local folder: Folder?=nil
local enemies: {[number]: Model}={}
local coins: {[number]: Part}={}
local arrows: {any}={}
local cooldowns: {[string]: number}={}
local cast=RaycastParams.new()
cast.FilterType=Enum.RaycastFilterType.Include
cast.FilterDescendantsInstances={workspace.Terrain}
cast.IgnoreWater=true
local MAX_PROJECTILES=5

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

local function enemyModel(e: any): Model
    local m=Instance.new("Model")
    m.Name="Raider_"..tostring(e.id)
    local root=part(m,"HumanoidRootPart",Vector3.new(1,1,1),
        Vector3.zero,Color3.new(0,0,0))
    root.Transparency=1
    m.PrimaryPart=root
    local isDuke=e.typeId=="infected_duke"
    local flesh=if isDuke then Color3.fromRGB(77,49,96)
        else Color3.fromRGB(58,48,55)
    part(m,"Torso",Vector3.new(2.3,2.8,1.3),Vector3.new(0,1.5,0),flesh)
    part(m,"Head",Vector3.new(1.55,1.4,1.4),Vector3.new(0,3.6,0),
        if isDuke then Color3.fromRGB(115,81,131) else Color3.fromRGB(53,61,59))
    if isDuke then
        part(m,"DucalCrown",Vector3.new(1.8,0.4,1.6),
            Vector3.new(0,4.55,0),Color3.fromRGB(196,157,66))
        m:SetAttribute("ER_StoryEnemy","infected_duke")
    end
    part(m,"Left Arm",Vector3.new(0.7,2.5,0.9),Vector3.new(-1.5,1.45,0),flesh)
    part(m,"Right Arm",Vector3.new(0.7,2.5,0.9),Vector3.new(1.5,1.45,0),flesh)
    part(m,"Left Leg",Vector3.new(0.9,1.8,1),Vector3.new(-0.55,-0.7,0),flesh)
    part(m,"Right Leg",Vector3.new(0.9,1.8,1),Vector3.new(0.55,-0.7,0),flesh)
    local hue=Color3.fromRGB(203,79,61)
    part(m,"EyeL",Vector3.new(0.3,0.2,0.07),Vector3.new(-0.37,3.75,-0.73),hue)
    part(m,"EyeR",Vector3.new(0.3,0.2,0.07),Vector3.new(0.37,3.75,-0.73),hue)
    m:SetAttribute("ER_NPCVisual",true)
    m:SetAttribute("ER_Enemy",true)
    m:SetAttribute("ER_EnemyId",e.id)
    local x=e.x
    local y=World.sample(state.seed,x,0).height+2.2
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
    local live: {[number]: boolean}={}
    for _,e in ipairs(state.r3.enemies) do
        live[e.id]=true
        local model=enemies[e.id]
        if not model then model=enemyModel(e); enemies[e.id]=model end
        local y=World.sample(state.seed,e.x,0).height+2.2
        local previous=model:GetAttribute("ER_NPCPose")
        local xSpeed=if typeof(previous)=="Vector3"
            then math.clamp((e.x-previous.X)/0.1,-7,7) else 0
        model:SetAttribute("ER_NPCVelocityX",xSpeed)
        model:SetAttribute("ER_NPCPose",Vector3.new(e.x,y,0))
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

function Combat.action(player: Player,action: string,arg: any): any
    if player~=owner or not state then return {ok=false,error="world_not_loaded"} end
    local root,h=playerRoot(player)
    if not root or not h then return {ok=false,error="character_not_ready"} end
    if action=="r3_status" then return {ok=true,data=R3.summary(state)} end
    if action=="attack" then
        if not allowed("attack",0.45) then return {ok=false,error="rate_limited"} end
        local d=state.r3
        if d.prologue.stage=="guard" then
            local ok,stage=R3.command(state,"training")
            return {ok=ok,stage=stage}
        end
        local hit,target=R3.hit(state,root.Position.X,root.Position.Y,
            direction(root),7,16)
        syncViews()
        return {ok=true,hit=hit,target=if hit then target else nil}
    elseif action=="bow" then
        if #arrows>=MAX_PROJECTILES then return {ok=false,error="too_many_arrows"} end
        if state.r3.arrows<=0 then return {ok=false,error="no_arrows"} end
        if not allowed("bow",0.85) then return {ok=false,error="rate_limited"} end
        local side=direction(root)
        local arrow=Instance.new("Part")
        arrow.Name="ER_Arrow"
        arrow.Size=Vector3.new(0.25,0.25,2.3)
        arrow.Anchored=true
        arrow.CanCollide=false
        arrow.CanTouch=false
        arrow.CanQuery=false
        arrow.Material=Enum.Material.Wood
        arrow.Color=Color3.fromRGB(168,141,83)
        arrow.Parent=folder
        local pos=root.Position+Vector3.new(side*1.3,1.2,0)
        arrow.CFrame=CFrame.new(pos)
        table.insert(arrows,{part=arrow,p=pos,v=Vector3.new(side*70,37,0),age=0})
        state.r3.arrows-=1
        state.r3.stats.shots+=1
        return {ok=true,arrows=state.r3.arrows}
    elseif action=="drop_coin" then
        if not allowed("coin",0.3) then return {ok=false,error="rate_limited"} end
        local ok,result=R3.drop(state,root.Position.X,1)
        if ok then syncViews() end
        return {ok=ok,result=result,error=if not ok then result else nil}
    elseif action=="pickup_coin" then
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
    elseif action=="craft_arrows" then
        if not allowed("craft_arrows",0.65) then
            return {ok=false,error="rate_limited"}
        end
        local ok,result=R3.craftArrows(state,root.Position.X)
        return {ok=ok,result=result,error=if not ok then result else nil}
    elseif action=="trade" then
        if type(arg)~="string" then return {ok=false,error="unknown_trade_item"} end
        if not allowed("trade",0.7) then return {ok=false,error="rate_limited"} end
        local ok,result=R3.trade(state,arg,root.Position.X)
        return {ok=ok,result=result,error=if not ok then result else nil}
    elseif action=="arm_defender" then
        if type(arg)~="string" then return {ok=false,error="invalid_equipment"} end
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
        local ok,result=R3.command(state,tostring(arg))
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
        local ray=workspace:Raycast(a.p,nextPos-a.p,cast)
        local impact=ray~=nil
        local deltaX=nextPos.X-a.p.X
        if not impact and math.abs(deltaX)>0.001 then
            local side=if deltaX>0 then 1 else -1
            for _,e in ipairs(state.r3.enemies) do
                local near=e.x-a.p.X
                if near*side>=0 and math.abs(near)<=math.abs(deltaX)+2 then
                    local y=World.sample(state.seed,e.x,0).height+3.4
                    local alpha=math.clamp(near/deltaX,0,1)
                    local arrowY=a.p.Y+(nextPos.Y-a.p.Y)*alpha
                    if math.abs(arrowY-y)<=3.8 then
                        local ok=R3.hit(state,a.p.X,arrowY,side,
                            math.abs(deltaX)+2,14)
                        if ok then impact=true; break end
                    end
                end
            end
        end
        if impact or a.age>3 or math.abs(nextPos.X)>126 or nextPos.Y< -28 then
            a.part:Destroy()
            table.remove(arrows,i)
        else
            a.p=nextPos
            a.v=nextVelocity
            a.part.CFrame=CFrame.lookAt(nextPos,nextPos+nextVelocity)
        end
    end
    syncViews()
end

return Combat
