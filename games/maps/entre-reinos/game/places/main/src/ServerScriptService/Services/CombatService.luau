--!strict
-- T1-R3 server-only combat, projectile raycasts, enemy and physical coin views.
-- UI has no authority over position, damage, currency, target or raid state.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local World=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("WorldProfile"))
local R3=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("R3Engine"))
local living=ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living")
local Trajectory=require(living:WaitForChild("Trajectory"))
local Ballistics=require(living:WaitForChild("Ballistics"))
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
local equipped="sword"
local charge: any=nil
local dialogue: Model?=nil
local sequence=0
local swingTrack: AnimationTrack?=nil
local swingRig: Model?=nil
local rigTemplate: Model?=nil
local heightCache: {[number]: number}={}

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
    local cell=math.round(x*2)
    local cached=heightCache[cell]
    if cached then return cached end
    local terrain=World.sample(state.seed,x,0)
    if terrain.wet then return World.WATER_SURFACE-1 end
    local support=workspace:Raycast(Vector3.new(cell/2,70,0),Vector3.new(0,-120,0),cast)
    if not support then return terrain.height end
    heightCache[cell]=support.Position.Y
    return support.Position.Y
end

local function costume(m: Model,name: string,holder: BasePart,size: Vector3,offset: CFrame,color: Color3): Part
    local piece=part(m,name,size,Vector3.zero,color)
    piece.CFrame=holder.CFrame*offset
    piece.Anchored=false
    piece.Massless=true
    local weld=Instance.new("WeldConstraint")
    weld.Part0=holder
    weld.Part1=piece
    weld.Parent=piece
    return piece
end

local function enemyModel(e: any): Model
    local template=assert(rigTemplate,"missing_r6_actor_template")
    local m=template:Clone()
    m.Name=(if e.story then "Story_" else "Raider_")..tostring(e.id)
    local root=m:FindFirstChild("HumanoidRootPart") :: BasePart
    local head=m:FindFirstChild("Head") :: BasePart
    local hand=m:FindFirstChild("Right Arm") :: BasePart
    local torso=m:FindFirstChild("Torso") :: BasePart
    local royal=e.typeId=="duke" or e.typeId=="infected_duke"
    local infected=not e.story or e.typeId=="creature"
    local id=if royal then 7 elseif type(e.id)=="number" then e.id else #tostring(e.id)
    local skins={Color3.fromRGB(232,191,152),Color3.fromRGB(190,132,91),
        Color3.fromRGB(149,101,72),Color3.fromRGB(104,68,49)}
    local skin=skins[1+(state.seed+id)%#skins]
    if infected then skin=skin:Lerp(Color3.fromRGB(127,139,116),0.26) end
    local uniform=if royal then Color3.fromRGB(112,36,50)
        elseif e.typeId=="guard" then Color3.fromRGB(58,85,114)
        else Color3.fromRGB(111,91,65)
    local colors=Instance.new("BodyColors")
    for _,old in ipairs(m:GetChildren()) do if old:IsA("BodyColors") then old:Destroy() end end
    colors.HeadColor3=skin
    colors.LeftArmColor3=skin
    colors.RightArmColor3=skin
    colors.LeftLegColor3=Color3.fromRGB(78,62,53)
    colors.RightLegColor3=colors.LeftLegColor3
    colors.TorsoColor3=uniform
    colors.Parent=m
    torso.Color=uniform
    local h=m:FindFirstChildOfClass("Humanoid") :: Humanoid
    h.DisplayName=if e.story then e.label elseif royal then "Duque corrompido" else "Corrompido"
    h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.Subject
    h.NameDisplayDistance=if e.story then 28 else 0
    h.HealthDisplayDistance=0
    if royal then
        costume(m,"DucalCrown",head,Vector3.new(1.65,0.28,1.15),CFrame.new(0,0.64,0),Color3.fromRGB(213,168,70))
        costume(m,"DucalSash",torso,Vector3.new(0.37,2.05,0.18),
            CFrame.new(0,0,-0.56)*CFrame.Angles(0,0,0.38),Color3.fromRGB(232,186,92))
    end
    if infected then
        for _,side in ipairs({-1,1}) do
            local eye=costume(m,"CorruptedEye",head,Vector3.new(0.17,0.13,0.08),
                CFrame.new(side*0.26,0.12,-0.52),Color3.fromRGB(226,120,60))
            eye.Material=Enum.Material.Neon
        end
        costume(m,"CorruptionMark",head,Vector3.new(0.34,0.15,0.1),
            CFrame.new(0.35,-0.24,-0.51)*CFrame.Angles(0,0,-0.5),Color3.fromRGB(101,106,76))
    end
    if e.typeId=="guard" or royal then
        costume(m,"GuardBlade",hand,Vector3.new(0.25,2.5,0.14),CFrame.new(0,-1.65,-0.28),Color3.fromRGB(194,197,181)).Material=Enum.Material.Metal
        costume(m,"GuardHilt",hand,Vector3.new(0.75,0.17,0.21),CFrame.new(0,-0.51,-0.28),Color3.fromRGB(127,84,39))
    end
    m:SetAttribute("ER_NativeR6",true)
    m:SetAttribute("ER_NPCVisual",true)
    if not e.story then
        m:SetAttribute("ER_Enemy",true)
        m:SetAttribute("ER_EnemyId",e.id)
    end
    local pose=Vector3.new(e.x,groundAt(e.x)+3.06,0)
    m.PrimaryPart=root
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
        local last=model:GetAttribute("ER_NPCPose")
        local velocity=if typeof(last)=="Vector3" then math.clamp((actor.x-last.X)/0.12,-6,6) else 0
        model:SetAttribute("ER_NPCVelocityX",velocity)
        model:SetAttribute("ER_NPCPose",Vector3.new(actor.x,groundAt(actor.x)+3.06,-1))
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
        local y=groundAt(e.x)+3.06
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
    equipped="sword"
    charge=nil
    dialogue=nil
    if swingTrack then swingTrack:Destroy() end
    swingTrack,swingRig=nil,nil
    table.clear(heightCache)
end

function Combat.start(player: Player,living: any,worldFolder: Folder)
    cleanup()
    if not rigTemplate then
        local description=Instance.new("HumanoidDescription")
        local ok,rig=pcall(function()
            return Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R6)
        end)
        description:Destroy()
        assert(ok and rig and rig:IsA("Model"),"r6_actor_creation_failed")
        for _,item in ipairs(rig:GetDescendants()) do
            if item:IsA("BasePart") then
                item.CanCollide=false
                item.CanTouch=false
                item.CanQuery=false
                item.Anchored=item.Name=="HumanoidRootPart"
            elseif item:IsA("BaseScript") then item:Destroy() end
        end
        local h=rig:FindFirstChildOfClass("Humanoid") :: Humanoid
        h.AutoRotate=false
        if not h:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent=h end
        rigTemplate=rig
    end
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

local function equipAvatar(root: BasePart): Trail?
    local character=root.Parent
    if not character or not character:IsA("Model") then return nil end
    local old=character:FindFirstChild("ER_PlayerWeapon")
    if old and old:GetAttribute("Mode")==equipped then return old:FindFirstChildOfClass("Trail") end
    if old then old:Destroy() end
    local hand=character:FindFirstChild("Right Arm")
    if not hand or not hand:IsA("BasePart") then return nil end
    local grip=CFrame.new(0,-0.72,-0.24)*CFrame.Angles(-math.pi/2,0,0)
    local blade=costume(character,"ER_PlayerWeapon",hand,
        if equipped=="sword" then Vector3.new(0.31,2.4,0.16) else Vector3.new(0.18,1.5,0.2),
        grip*CFrame.new(0,1.2,0),if equipped=="sword" then Color3.fromRGB(206,213,201)
            else Color3.fromRGB(137,89,43))
    blade:SetAttribute("Mode",equipped)
    if equipped=="bow" then
        for side=-1,1,2 do
            local limb=costume(character,"Limb",blade,Vector3.new(0.14,0.86,0.16),
                CFrame.new(0,0.96*side,0.2)*CFrame.Angles(side*0.62,0,0),blade.Color)
            limb.Parent=blade
        end
        return nil
    end
    blade.Material=Enum.Material.Metal
    costume(character,"Hilt",blade,Vector3.new(0.74,0.14,0.25),
        CFrame.new(0,-1.15,0),Color3.fromRGB(160,111,55)).Parent=blade
    local base=Instance.new("Attachment")
    base.Position=Vector3.new(0,-0.86,0)
    base.Parent=blade
    local tip=Instance.new("Attachment")
    tip.Position=Vector3.new(0,1.15,0)
    tip.Parent=blade
    local trail=Instance.new("Trail")
    trail.Attachment0=base
    trail.Attachment1=tip
    trail.Lifetime=0.14
    trail.LightEmission=0.4
    trail.Enabled=false
    trail.Color=ColorSequence.new(Color3.fromRGB(255,232,175),Color3.fromRGB(176,211,226))
    trail.Transparency=NumberSequence.new(0.2,1)
    trail.Parent=blade
    return trail
end

local function playSwing(human: Humanoid)
    local character=human.Parent
    if character~=swingRig then
        if swingTrack then swingTrack:Destroy() end
        swingRig=if character and character:IsA("Model") then character else nil
        swingTrack=nil
        local animator=human:FindFirstChildOfClass("Animator")
        if animator then
            local animation=Instance.new("Animation")
            animation.AnimationId="rbxassetid://129967390"
            local ok,track=pcall(function() return animator:LoadAnimation(animation) end)
            animation:Destroy()
            if ok then
                track.Priority=Enum.AnimationPriority.Action
                swingTrack=track
            end
        end
    end
    if swingTrack then swingTrack:Play(0.045) end
end

local function beginDialogue(player: Player,root: BasePart): any
    if not allowed("duke",0.4) or R3.storyAction(state,root.Position.X)~="training" then
        return {ok=false,error="too_far_from_story"}
    end
    if state.r3.prologue.scene and math.abs(root.Position.Y-(groundAt(root.Position.X)+3))>7 then
        return {ok=false,error="too_far_from_story"}
    end
    local character=player.Character
    if not character then return {ok=false,error="character_not_ready"} end
    dialogue=character
    charge=nil
    return {ok=true}
end

function Combat.action(player: Player,action: string,arg: any): any
    if player~=owner or not state then return {ok=false,error="world_not_loaded"} end
    local root,h=playerRoot(player)
    if not root or not h then return {ok=false,error="character_not_ready"} end
    if dialogue and dialogue~=player.Character then dialogue=nil end
    if action=="duke_talk" then return beginDialogue(player,root) end
    if action=="duke_close" then dialogue=nil; return {ok=true} end
    if action=="duke_accept" then
        if dialogue~=player.Character or R3.storyAction(state,root.Position.X)~="training" then
            return {ok=false,error="too_far_from_story"}
        end
        dialogue=nil
        local ok,result=R3.command(state,"training",root.Position.X)
        return {ok=ok,error=if not ok then result else nil}
    end
    if dialogue then return {ok=false,error="dialogue_open"} end
    if action=="r3_status" then return {ok=true,data=R3.summary(state)} end
    if action=="select_weapon" then
        if arg~="sword" and arg~="bow" then return {ok=false,error="invalid_weapon"} end
        if not allowed("weapon",0.18) then return {ok=false,error="rate_limited"} end
        charge=nil
        equipped=arg
        equipAvatar(root)
        return {ok=true}
    end
    if action=="attack" then
        if equipped~="sword" then return {ok=false,error="invalid_weapon"} end
        if not allowed("attack",0.52) then return {ok=false,error="rate_limited"} end
        local trail=equipAvatar(root)
        playSwing(h)
        if trail then trail.Enabled=true end
        player:SetAttribute("ER_PlayerAttack",workspace:GetServerTimeNow())
        task.wait(0.12)
        if trail and trail.Parent then trail.Enabled=false end
        if playerRoot(player)~=root or player~=owner or not state or dialogue or equipped~="sword" then
            return {ok=false,error="action_unavailable"}
        end
        local side=direction(root)
        local start=Vector3.new(root.Position.X-side*0.15,root.Position.Y,0)
        local target=sweep(start,start+Vector3.new(side*6,0,0))
        local hit=target~=nil and R3.damageEnemy(state,target,16)
        return {ok=true,hit=hit,target=if hit then target else nil}
    elseif action=="bow_cancel" then
        if charge and charge.id==arg then charge=nil end
        return {ok=true}
    elseif action=="bow_begin" then
        if equipped~="bow" then return {ok=false,error="invalid_weapon"} end
        if state.r3.arrows<=0 then return {ok=false,error="no_arrows"} end
        if not allowed("bow_begin",0.22) then return {ok=false,error="rate_limited"} end
        sequence+=1
        charge={id=sequence,root=root,at=workspace:GetServerTimeNow()}
        return {ok=true,id=sequence,started=charge.at}
    elseif action=="bow_release" then
        local shot=charge
        if not shot or shot.id~=arg then return {ok=false,error="action_unavailable"} end
        charge=nil
        local seconds=workspace:GetServerTimeNow()-shot.at
        if equipped~="bow" or shot.root~=root or seconds<0 or seconds>Ballistics.MAX_HOLD then
            return {ok=false,error="action_unavailable"}
        end
        if state.r3.arrows<=0 then return {ok=false,error="no_arrows"} end
        if not allowed("bow",0.7) then return {ok=false,error="rate_limited"} end
        local side=direction(root)
        local pos=root.Position+Vector3.new(side*1.1,0.9,-root.Position.Z)
        local vx,vy=Ballistics.velocity(seconds)
        if not launch(pos,Vector3.new(side*vx,vy,0),14) then return {ok=false,error="too_many_arrows"} end
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
        if type(arg)~="string" or #arg>16 or arg=="training" then return {ok=false,error="action_unavailable"} end
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
    if owner then
        local root=playerRoot(owner)
        if root then equipAvatar(root) end
    end
end

return Combat
