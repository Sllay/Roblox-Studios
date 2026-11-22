--!strict
-- T1-R2: server-owned NPC population, physical 3D representations, site stocks,
-- building progress, and world-snapshot integration. No loops run in the lobby.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local PhysicsService=game:GetService("PhysicsService")
local Lighting=game:GetService("Lighting")
local shared=ReplicatedStorage:WaitForChild("Game")
local Profile=require(shared:WaitForChild("WorldProfile"))
local Living=require(shared:WaitForChild("Living"):WaitForChild("LivingModel"))
local Work=require(shared:WaitForChild("Living"):WaitForChild("WorkEngine"))
local R3=require(shared:WaitForChild("Living"):WaitForChild("R3Engine"))
local Combat=require(script.Parent:WaitForChild("CombatService"))
local Structures=require(shared:WaitForChild("Living"):WaitForChild("StructureDefs"))
local Professions=require(shared:WaitForChild("Living"):WaitForChild("ProfessionDefs"))
local WorldService=require(script.Parent:WaitForChild("WorldService"))
local Service={}
local owner: Player?=nil
local state: any=nil
local visualization: Folder?=nil
local figures: {[number]: Model}={}
local buildings: {[number]: Model}={}
local siteDisplays: {[string]: BillboardGui}={}
local connection: RBXScriptConnection?=nil
local simulationAccumulator=0
local drawAccumulator=0
local lastActionAt: {[Player]: number}={}
-- Non-physical R6 residents. Logical work coordinates remain untouched.
local GHOST_GROUP="ER_GhostNPC"
if not PhysicsService:IsCollisionGroupRegistered(GHOST_GROUP) then
    PhysicsService:RegisterCollisionGroup(GHOST_GROUP)
end
PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP,GHOST_GROUP,false)
PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP,"Default",false)

-- Four stable depth lanes and small visual offsets avoid NPC piles at the
-- same work station. These are presentation offsets, never job/save positions.
local function actorX(npc: any): number
    return npc.x+(((npc.id-1)%4)-1.5)*2.2
end
local function actorZ(npc: any): number
    return -8+((npc.id-1)%4)*4
end

local function ghostPart(p: BasePart)
    p.CollisionGroup=GHOST_GROUP
    p.CanCollide=false
    p.CanQuery=false
    p.CanTouch=false
end
local groundCast=RaycastParams.new()
groundCast.FilterType=Enum.RaycastFilterType.Include
groundCast.FilterDescendantsInstances={workspace.Terrain}
groundCast.IgnoreWater=true

-- Height must come from the actually-generated voxel surface, not only
-- Profile.sample: voxel quantization and a Model pivot differ from the rig feet.
local function groundHeight(x: number, z: number): number
    local hit=workspace:Raycast(Vector3.new(x,70,z),Vector3.new(0,-120,0),groundCast)
    if hit then return hit.Position.Y end
    return Profile.sample(state.seed,x,z).height
end

local function pivotToFoot(model: Model): number
    local pivot=model:GetPivot().Position.Y
    local bottom=math.huge
    for _,name in ipairs({"Left Leg","Right Leg"}) do
        local leg=model:FindFirstChild(name)
        if leg and leg:IsA("BasePart") then
            bottom=math.min(bottom,leg.Position.Y-leg.Size.Y*0.5)
        end
    end
    if bottom==math.huge then
        local bounds,boundsSize=model:GetBoundingBox()
        bottom=bounds.Position.Y-boundsSize.Y*0.5
    end
    return math.clamp(pivot-bottom,1.8,7)
end

local actions=Instance.new("RemoteFunction")
actions.Name="ER_LivingActions"
actions.Parent=shared

local function makePart(parent: Instance,name: string,size: Vector3,color: Color3): Part
    local p=Instance.new("Part")
    p.Name=name
    p.Anchored=true
    p.CanCollide=false
    p.CanQuery=false
    p.CanTouch=false
    p.CastShadow=false
    p.Size=size
    p.Material=Enum.Material.SmoothPlastic
    p.Color=color
    p.Parent=parent
    return p
end
local function textTag(part: BasePart,label: string): (BillboardGui, TextLabel)
    local bill=Instance.new("BillboardGui")
    bill.Name="ER_Info"
    bill.AlwaysOnTop=false
    bill.MaxDistance=40
    bill.Size=UDim2.fromOffset(146,36)
    bill.StudsOffset=Vector3.new(0,1.8,0)
    bill.Adornee=part
    bill.Parent=part
    local caption=Instance.new("TextLabel")
    caption.Name="Info"
    caption.BackgroundTransparency=1
    caption.TextStrokeColor3=Color3.new(0,0,0)
    caption.TextStrokeTransparency=0.08
    caption.BorderSizePixel=0
    caption.Size=UDim2.fromScale(1,1)
    caption.Text=label
    caption.TextColor3=Color3.fromRGB(244,242,224)
    caption.Font=Enum.Font.GothamSemibold
    caption.TextSize=11
    caption.TextScaled=false
    caption.TextWrapped=true
    caption.Parent=bill
    return bill,caption
end

local function createActor(npc: any): Model?
    local description=Instance.new("HumanoidDescription")
    local ok,model=pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(
            description,Enum.HumanoidRigType.R6)
    end)
    description:Destroy()
    if not ok or not model or not model:IsA("Model") then
        warn("[EntreReinos][Living] Could not create native R6 NPC ",npc.name,": ",model)
        return nil
    end
    model.Name="NPC_"..tostring(npc.id).."_"..npc.name
    model:SetAttribute("ER_NPC",true)
    model:SetAttribute("ER_NPCId",npc.id)
    model:SetAttribute("Profession",npc.profession)
    local prof=Professions.get(npc.profession)
    local humanoid=model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayName=npc.name.." · "..prof.label
        humanoid.AutoRotate=false
    end
    for _,item in ipairs(model:GetDescendants()) do
        if item:IsA("BasePart") then
            ghostPart(item)
            item.CastShadow=true
        end
    end
    -- Accessory or rig parts inserted later must stay ghosted too.
    model.DescendantAdded:Connect(function(item: Instance)
        if item:IsA("BasePart") then ghostPart(item) end
    end)
    local root=model:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then root.Anchored=true end
    -- R6 feet and Model:GetPivot() can differ by several studs.
    -- Measure *before* pivoting, then keep this per-rig offset.
    local feetOffset=pivotToFoot(model)
    model:SetAttribute("ER_FeetOffset",feetOffset)
    model:SetAttribute("ER_NPCVisual",true)
    model:SetAttribute("ER_NPCVelocityX",0)
    local x,z=actorX(npc),actorZ(npc)
    local target=Vector3.new(x,groundHeight(x,z)+feetOffset+0.14,z)
    model:SetAttribute("ER_NPCPose",target)
    model:SetAttribute("ER_NPCFacing",0)
    model:PivotTo(CFrame.new(target))
    model.Parent=visualization
    return model
end

local function syncNPC(npc: any)
    local model=figures[npc.id]
    if not model then return end
    local x,z=actorX(npc),actorZ(npc)
    local offset=model:GetAttribute("ER_FeetOffset")
    if type(offset)~="number" then return end
    local target=Vector3.new(x,groundHeight(x,z)+offset+0.14,z)
    local motion=if type(npc.motionX)=="number" then npc.motionX else 0
    local vx=math.clamp(motion,-9,9)
    -- A single replicated pose is atomic; clients do their own frame-level
    -- interpolation from this logical position. No low-FPS PivotTo on server.
    model:SetAttribute("ER_NPCPose",target)
    model:SetAttribute("ER_NPCVelocityX",vx)
    local facing=model:GetAttribute("ER_NPCFacing")
    if vx>0.08 then facing=-math.pi/2
    elseif vx< -0.08 then facing=math.pi/2 end
    if type(facing)=="number" then model:SetAttribute("ER_NPCFacing",facing) end
    local h=model:FindFirstChildOfClass("Humanoid")
    if h and h.DisplayName~=npc.name.." · "..tostring(npc.state) then
        h.DisplayName=npc.name.." · "..tostring(npc.state)
    end
end
local function buildVisual(b: any)
    if not visualization then return end
    local def=Structures.get(b.typeId)
    if not def then return end
    local model=Instance.new("Model")
    model.Name="Building_"..tostring(b.id).."_"..b.typeId
    model:SetAttribute("ER_BuildingId",b.id)
    model:SetAttribute("ER_Saveable",true)
    model:SetAttribute("TypeId",b.typeId)
    local base=makePart(model,"Foundation",
        Vector3.new(def.footprint,1,7),Color3.fromRGB(104,90,76))
    base.Position=Vector3.new(b.x,b.y+0.35,-10)
    local wall=makePart(model,"Structure",Vector3.new(
        def.footprint-1,def.height,5),Color3.fromRGB(146,115,80))
    wall.Position=Vector3.new(b.x,b.y+def.height/2+1,-10)
    wall.Transparency=0.80
    local tagPart=makePart(model,"InfoAnchor",
        Vector3.new(1,1,1),Color3.fromRGB(30,49,35))
    tagPart.Position=Vector3.new(b.x,b.y+def.height+2,-10)
    tagPart.Transparency=1
    textTag(tagPart,def.label.." | Plantação de obra")
    model.Parent=visualization
    buildings[b.id]=model
end
local function syncBuild(b: any)
    if not buildings[b.id] then buildVisual(b) end
    local model=buildings[b.id]
    if not model then return end
    local def=Structures.get(b.typeId)
    local wall=model:FindFirstChild("Structure")
    if wall and wall:IsA("BasePart") then
        wall.Transparency=if b.state=="complete" then 0 else if b.state=="building" then 0.35 else 0.76
        wall.Color=if b.state=="damaged" then Color3.fromRGB(109,83,73)
            else if b.state=="complete" then Color3.fromRGB(150,112,77)
            else Color3.fromRGB(133,138,116)
    end
    local p=model:FindFirstChild("InfoAnchor")
    local gui=if p then p:FindFirstChild("ER_Info") else nil
    local caption=if gui then gui:FindFirstChild("Info") else nil
    if caption and caption:IsA("TextLabel") then
        local delivered=""
        for resource,cost in pairs(def.cost) do
            delivered..=resource.." "..tostring(b.delivered[resource] or 0)
                .."/"..tostring(cost).."  "
        end
        caption.Text=def.label.." #"..tostring(b.id)..": "..b.state.."\n"
            ..(if b.state=="complete" then "Concluído"
                else tostring(math.floor(100*b.progress/def.buildSeconds)).."% | "..delivered)
    end
end

local function createSiteVisual(site: any)
    if not visualization then return end
    local pos=Profile.sample(state.seed,site.x,0)
    local p=makePart(visualization,"Resource_"..site.id,
        Vector3.new(2.4,1.6,2.4),
        if site.item=="wood" then Color3.fromRGB(92,68,46)
        else if site.item=="stone" then Color3.fromRGB(111,113,120)
        else if site.item=="iron" then Color3.fromRGB(90,100,121)
        else Color3.fromRGB(94,143,83))
    p.Position=Vector3.new(site.x,pos.height+0.8,0)
    p.Shape=Enum.PartType.Ball
    p:SetAttribute("ResourceType",site.item)
    p:SetAttribute("SourceId",site.id)
    local gui,label=textTag(p,site.item.." | "..tostring(site.remaining))
    gui.MaxDistance=23
    gui.Size=UDim2.fromOffset(110,24)
    siteDisplays[site.id]=gui
    label.Name="Remaining"
end

local function syncR3Hud(player: Player)
    local data=R3.summary(state)
    player:SetAttribute("ER_R3Wallet",data.wallet)
    player:SetAttribute("ER_R3Arrows",data.arrows)
    player:SetAttribute("ER_R3Day",data.day)
    player:SetAttribute("ER_R3Night",data.night)
    player:SetAttribute("ER_R3Raid",data.raidActive)
    player:SetAttribute("ER_R3Enemies",data.enemies)
    player:SetAttribute("ER_R3Phase",data.phase)
    player:SetAttribute("ER_R3Warning",data.warning)
    Lighting.ClockTime=((state.elapsed%R3.DAY)/10+6)%24
end

local function draw()
    if not state then return end
    for _,npc in ipairs(state.npcs) do
        syncNPC(npc)
    end
    for _,b in ipairs(state.buildings) do
        syncBuild(b)
    end
    for _,site in ipairs(state.sites) do
        local g=siteDisplays[site.id]
        local info=if g then g:FindFirstChild("Remaining") else nil
        if info and info:IsA("TextLabel") then
            info.Text=site.item.." | "..tostring(site.remaining)
        end
    end
end

function Service.snapshot(player: Player): any
    if owner~=player or not state then return nil end
    return Living.clone(state)
end

function Service.start(player: Player, worldRecord: any, onProgress: ((number, string) -> ())?): (boolean, string?)
    if owner then return false,"population_already_active" end
    local loaded=Living.restore(worldRecord.living,worldRecord.seed)
    if not loaded then return false,"population_schema_conflict" end
    local upgraded,r3Result=pcall(R3.ensure,loaded,worldRecord.living==nil)
    if not upgraded then
        warn("[EntreReinos][R3] Cannot migrate existing world: ",r3Result)
        return false,"r3_schema_conflict"
    end
    owner=player
    state=loaded
    local folder=Instance.new("Folder")
    folder.Name="ER_LivingWorld"
    folder:SetAttribute("ER_Saveable",true)
    folder.Parent=workspace
    visualization=folder
    local prepared, prepareError=pcall(function()
        for _,site in ipairs(state.sites) do createSiteVisual(site) end
        for i,npc in ipairs(state.npcs) do
            if onProgress then
                onProgress((i-1)/#state.npcs,
                    "Preparando morador "..tostring(i).."/"..tostring(#state.npcs))
            end
            local model=createActor(npc)
            if model then figures[npc.id]=model end
        end
        if onProgress then onProgress(1,"Moradores preparados") end
        for _,b in ipairs(state.buildings) do buildVisual(b) end
        Combat.start(player,state,folder)
        draw()
        syncR3Hud(player)
    end)
    if not prepared then
        warn("[EntreReinos][Living] Preparation failed; rolling back visual state: ",prepareError)
        owner=nil
        state=nil
        figures={}
        buildings={}
        siteDisplays={}
        visualization=nil
        Combat.stop()
        folder:Destroy()
        return false,"living_visual_setup_failed"
    end

    -- A fixed, bounded tick keeps worker jobs deterministic and avoids
    -- a heavy per-frame task per NPC; presentation is LOD-throttled.
    connection=RunService.Heartbeat:Connect(function(dt: number)
        if not owner or not state or player.Parent~=Players
            or player:GetAttribute("ER_WorldLoaded")~=true then return end
        simulationAccumulator+=math.min(dt,0.25)
        local ticks=0
        while simulationAccumulator>=0.1 and ticks<3 do
            Work.step(state,0.1)
            local currentRoot=if player.Character then
                player.Character:FindFirstChild("HumanoidRootPart") else nil
            local x=if currentRoot and currentRoot:IsA("BasePart")
                then currentRoot.Position.X else 0
            local damage=R3.step(state,0.1,x)
            if damage>0 and player.Character then
                local h=player.Character:FindFirstChildOfClass("Humanoid")
                if h and h.Health>0 then h:TakeDamage(damage) end
            end
            simulationAccumulator-=0.1
            ticks+=1
        end
        Combat.tick(dt)
        drawAccumulator+=dt
        if drawAccumulator>=0.12 then
            -- Expose the real interval to the pose velocity estimator;
            -- update only once per ~0.12 seconds to avoid network floods.
            local elapsed=drawAccumulator
            drawAccumulator=0
            drawAccumulator=math.max(elapsed,0.01)
            -- Workers can reach the west before the player; the same
            -- deterministic streaming contract must apply to NPC movement.
            for _,npc in ipairs(state.npcs) do
                if npc.x < -24 then
                    local streamed,reason=WorldService.ensureNear(state.seed,npc.x)
                    if not streamed and reason~="world_generation_in_progress" then
                        warn("[EntreReinos][Living] Worker chunk load: ",reason)
                    end
                    break
                end
            end
            draw()
            syncR3Hud(player)
            drawAccumulator=0
        end
    end)
    player:SetAttribute("ER_NPCCount",#state.npcs)
    player:SetAttribute("ER_LivingVersion",Living.VERSION)
    return true,nil
end

function Service.stop(player: Player)
    if owner~=player then return end
    if connection then connection:Disconnect() end
    connection=nil
    Combat.stop()
    owner=nil
    state=nil
    figures={}
    buildings={}
    siteDisplays={}
    if visualization then visualization:Destroy() end
    visualization=nil
end

actions.OnServerInvoke=function(player: Player,action: any,typeId: any): any
    if owner~=player or not state or player:GetAttribute("ER_WorldLoaded")~=true then
        return {ok=false,error="world_not_loaded"}
    end
    if action=="status" then
        return {ok=true,data=Work.summary(state)}
    end
    if action=="attack" or action=="bow" or action=="drop_coin"
        or action=="pickup_coin" or action=="arm_defender"
        or action=="trade" or action=="prologue" or action=="r3_status" then
        return Combat.action(player,action,typeId)
    end
    if action~="build" then return {ok=false,error="invalid_action"} end
    if type(typeId)~="string" or not Structures.get(typeId) then
        return {ok=false,error="invalid_structure"}
    end
    local now=os.clock()
    if lastActionAt[player] and now-lastActionAt[player]<0.65 then
        return {ok=false,error="rate_limited"}
    end
    local character=player.Character
    local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
    if not root or not root:IsA("BasePart") then
        return {ok=false,error="character_not_ready"}
    end
    -- The client sends only the structure type. Search from the player's
    -- real, server-observed position; never accept a client supplied X.
    if math.abs(root.Position.Z-Profile.LANE_Z)>4 then
        return {ok=false,error="outside_playable_lane"}
    end
    local available,site=Work.findPlacement(state,typeId,root.Position.X+15)
    if not available then return {ok=false,error=site} end
    local placed,result=Work.place(state,typeId,site)
    if not placed then return {ok=false,error=result} end
    -- Failed placement is never rate limited. Only successful orders enter
    -- cooldown, so the user may retry an unavailable spot immediately.
    lastActionAt[player]=now
    buildVisual(result)
    return {ok=true,buildingId=result.id,x=result.x,typeId=typeId}
end
return Service
