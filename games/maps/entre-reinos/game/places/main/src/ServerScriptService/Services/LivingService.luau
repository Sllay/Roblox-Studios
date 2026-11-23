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
local function buildPiece(model: Model,b: any,name: string,
        size: Vector3,offset: Vector3,color: Color3,tilt: number?): Part
    local p=makePart(model,name,size,color)
    p.CFrame=CFrame.new(b.x+offset.X,b.y+offset.Y,-10+offset.Z)
        *CFrame.Angles(0,0,tilt or 0)
    p:SetAttribute("ER_StructurePiece",true)
    p.CastShadow=true
    return p
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
    local stone=Color3.fromRGB(133,133,122)
    local wood=Color3.fromRGB(104,73,48)
    local warm=Color3.fromRGB(205,180,130)
    local roof=Color3.fromRGB(104,69,57)
    local pale=Color3.fromRGB(189,176,149)
    local foundation=makePart(model,"Foundation",
        Vector3.new(def.footprint,0.7,7),stone)
    foundation.Position=Vector3.new(b.x,b.y+0.22,-10)
    if b.typeId=="shelter" then
        -- A-frame canvas shelter: the first home is not a wooden cube.
        buildPiece(model,b,"TentFront",Vector3.new(6,4,5),
            Vector3.new(0,2.4,0),Color3.fromRGB(159,142,100))
        buildPiece(model,b,"CanvasLeft",Vector3.new(0.55,6.7,7),
            Vector3.new(-2.65,5,0),warm,-0.65)
        buildPiece(model,b,"CanvasRight",Vector3.new(0.55,6.7,7),
            Vector3.new(2.65,5,0),warm,0.65)
        buildPiece(model,b,"Entrance",Vector3.new(2,3,0.35),
            Vector3.new(0,2,-3.05),Color3.fromRGB(65,54,44))
    elseif b.typeId=="house" then
        buildPiece(model,b,"PlasterWalls",Vector3.new(def.footprint-2,9,5),
            Vector3.new(0,5,0),Color3.fromRGB(199,181,144))
        for _,side in ipairs({-1,1}) do
            buildPiece(model,b,"RoofPitch",Vector3.new(def.footprint*0.62,0.85,7),
                Vector3.new(side*def.footprint*0.225,11,0),roof,side*0.48)
            buildPiece(model,b,"Window",Vector3.new(1.7,1.7,0.18),
                Vector3.new(side*3,6,-2.7),Color3.fromRGB(103,154,153))
        end
        buildPiece(model,b,"Door",Vector3.new(2.6,5,0.27),
            Vector3.new(0,3.1,-2.68),wood)
    elseif b.typeId=="stockpile" then
        -- Open timber galpão: four pillars, visible crates, and wide roof.
        for _,dx in ipairs({-1,1}) do
            for _,dz in ipairs({-1,1}) do
                buildPiece(model,b,"Support",Vector3.new(0.85,8.5,0.85),
                    Vector3.new(dx*(def.footprint/2-1),4.8,dz*2.7),wood)
            end
        end
        buildPiece(model,b,"WarehouseRoof",Vector3.new(def.footprint+2,1.3,9),
            Vector3.new(0,9.8,0),Color3.fromRGB(115,83,57))
        for i=-1,1 do
            buildPiece(model,b,"SupplyCrate",Vector3.new(2.5,2.4,2.4),
                Vector3.new(i*3,1.7,-0.2),Color3.fromRGB(155,112,70))
        end
    elseif b.typeId=="fence" then
        for i=-2,2 do
            buildPiece(model,b,"Palisade",Vector3.new(0.75,5.8,1.2),
                Vector3.new(i*1.16,3.2,0),wood)
        end
        for _,height in ipairs({2.4,4.5}) do
            buildPiece(model,b,"FenceRail",Vector3.new(def.footprint-0.5,0.6,1),
                Vector3.new(0,height,-0.6),Color3.fromRGB(146,102,61))
        end
    elseif b.typeId=="wall" then
        buildPiece(model,b,"StoneCurtain",Vector3.new(def.footprint-0.6,9,4),
            Vector3.new(0,5,0),Color3.fromRGB(130,132,130))
        for i=-2,2 do
            buildPiece(model,b,"Battlement",Vector3.new(1.3,2.8,4.5),
                Vector3.new(i*1.6,10.5,0),pale)
        end
        buildPiece(model,b,"WallBanner",Vector3.new(1.6,3,0.2),
            Vector3.new(0,7,-2.2),Color3.fromRGB(78,105,81))
    end
    local tagPart=makePart(model,"InfoAnchor",
        Vector3.new(1,1,1),Color3.fromRGB(30,49,35))
    tagPart.Position=Vector3.new(b.x,b.y+def.height+2,-10)
    tagPart.Transparency=1
    textTag(tagPart,def.label.." · obra")
    model.Parent=visualization
    buildings[b.id]=model
end
local function syncBuild(b: any)
    if not buildings[b.id] then buildVisual(b) end
    local model=buildings[b.id]
    if not model then return end
    local def=Structures.get(b.typeId)
    if not def then return end
    if model:GetAttribute("ER_LastVisualState")~=b.state then
        model:SetAttribute("ER_LastVisualState",b.state)
        for _,p in ipairs(model:GetChildren()) do
            if p:IsA("BasePart") and p:GetAttribute("ER_StructurePiece")==true then
                -- Only touch visual properties on state transitions, not
                -- every 10Hz physics tick of every completed building.
                p.Transparency=if b.state=="complete" then 0
                    else if b.state=="damaged" or b.state=="ruined" then 0.23
                    else if b.state=="building" then 0.28 else 0.55
            end
        end
    end
    local p=model:FindFirstChild("InfoAnchor")
    local gui=if p then p:FindFirstChild("ER_Info") else nil
    local caption=if gui then gui:FindFirstChild("Info") else nil
    if caption and caption:IsA("TextLabel") then
        local delivered={}
        for resource,cost in pairs(def.cost) do
            table.insert(delivered,resource.." "..tostring(b.delivered[resource] or 0)
                .."/"..tostring(cost))
        end
        local stored=""
        if b.typeId=="stockpile" and b.stored then
            local pieces={}
            for item,count in pairs(b.stored.items) do
                table.insert(pieces,item.." "..tostring(count))
            end
            stored=if #pieces>0 then " | estoque: "..table.concat(pieces,", ") else " | vazio"
        end
        caption.Text=def.label.." #"..tostring(b.id).." · "..b.state
            ..(if b.state=="complete" then stored
                else " "..tostring(math.floor(100*b.progress/def.buildSeconds))
                    .."% · "..table.concat(delivered,", "))
    end
end

local function createSiteVisual(site: any)
    if not visualization then return end
    local pos=Profile.sample(state.seed,site.x,0)
    local anchor: BasePart
    if site.item=="wood" then
        -- Distinct harvestable tree; background trees remain decoration.
        local tree=Instance.new("Model")
        tree.Name="HarvestableTree_"..tostring(site.id)
        tree:SetAttribute("ER_Harvestable",true)
        tree:SetAttribute("ER_SourceId",site.id)
        local trunk=makePart(tree,"Trunk",
            Vector3.new(2.1,7.2,2.1),Color3.fromRGB(112,75,47))
        trunk.Position=Vector3.new(site.x,pos.height+3.6,-6)
        for k=1,3 do
            local leaves=makePart(tree,"LeafCrown",
                Vector3.new(7.5-k*1.1,3.8,7.5-k*1.1),
                Color3.fromRGB(63,116,77))
            leaves.Shape=Enum.PartType.Ball
            leaves.Position=Vector3.new(site.x,pos.height+7.1+k*1.8,-6)
        end
        tree.Parent=visualization
        anchor=trunk
        local high=Instance.new("Highlight")
        high.Name="MarkedForCarpenter"
        high.Adornee=tree
        high.FillColor=Color3.fromRGB(230,189,85)
        high.OutlineColor=Color3.fromRGB(255,222,120)
        high.FillTransparency=0.85
        high.OutlineTransparency=0.1
        high.Enabled=site.marked==true and site.remaining>0
        high.Parent=tree
        local prompt=Instance.new("ProximityPrompt")
        prompt.Name="MarkHarvest"
        prompt.ActionText=if site.marked==true then "Desmarcar corte" else "Marcar corte"
        prompt.ObjectText="Árvore · madeira"
        prompt.MaxActivationDistance=13
        prompt.RequiresLineOfSight=false
        prompt.HoldDuration=0.35
        prompt.Parent=trunk
        prompt.Triggered:Connect(function(player: Player)
            if owner~=player or not state or site.remaining<=0
                or player:GetAttribute("ER_WorldLoaded")~=true then return end
            local char=player.Character
            local root=if char then char:FindFirstChild("HumanoidRootPart") else nil
            if not root or not root:IsA("BasePart")
                or (root.Position-trunk.Position).Magnitude>16 then return end
            site.marked=not (site.marked==true)
            high.Enabled=site.marked and site.remaining>0
            prompt.ActionText=if site.marked then "Desmarcar corte" else "Marcar corte"
        end)
    else
        -- Each resource has its own recognizable shape and palette.
        local color=if site.item=="stone" then Color3.fromRGB(126,131,130)
            else if site.item=="iron" then Color3.fromRGB(97,116,132)
            else Color3.fromRGB(96,151,88)
        local block=makePart(visualization,"Resource_"..site.id,
            if site.item=="food" then Vector3.new(3.7,2.6,3.7)
            else Vector3.new(3.8,3,3.4),color)
        block.Shape=if site.item=="food" then Enum.PartType.Ball else Enum.PartType.Block
        block.Position=Vector3.new(site.x,pos.height+1.4,-4)
        anchor=block
    end
    anchor:SetAttribute("ResourceType",site.item)
    anchor:SetAttribute("SourceId",site.id)
    local gui,caption=textTag(anchor,site.item.." | "..tostring(site.remaining))
    gui.MaxDistance=23
    gui.Size=UDim2.fromOffset(124,26)
    caption.Name="Remaining"
    siteDisplays[site.id]=gui
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
    player:SetAttribute("ER_R3Forecast",data.raidForecast)
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
            info.Text=if site.item=="wood" then
                "MADEIRA "..tostring(site.remaining)
                    ..(if site.marked then " · CORTE MARCADO" else "")
                else site.item.." | "..tostring(site.remaining)
        end
        if site.item=="wood" and visualization then
            local tree=visualization:FindFirstChild("HarvestableTree_"..tostring(site.id))
            if tree and tree:IsA("Model") then
                local prompt=tree:FindFirstChild("MarkHarvest",true)
                if prompt and prompt:IsA("ProximityPrompt") then
                    prompt.Enabled=site.remaining>0
                end
                local high=tree:FindFirstChild("MarkedForCarpenter")
                if high and high:IsA("Highlight") then
                    high.Enabled=site.marked==true and site.remaining>0
                end
                -- A depleted tree visibly disappears; no visual fake stock.
                local prior=tree:GetAttribute("ER_Depleted")
                if prior~=(site.remaining<=0) then
                    tree:SetAttribute("ER_Depleted",site.remaining<=0)
                    for _,part in ipairs(tree:GetChildren()) do
                        if part:IsA("BasePart") and part.Name~="Trunk" then
                            part.Transparency=if site.remaining<=0 then 1 else 0
                        end
                    end
                end
            end
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
        -- One read-only world overview for the whole immersive game HUD.
        -- Proximity is computed from the real server-observed character.
        local overview=Work.summary(state)
        local character=player.Character
        local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
        local nearby={wood=0,canTrade=false,npcId=0,coinId=0,
            nearestWoodDistance=-1,nearestWoodDirection=""}
        if root and root:IsA("BasePart") then
            local x=root.Position.X
            nearby.canTrade=math.abs(x)<=24
            local closestNPC=15
            for _,npc in ipairs(state.npcs) do
                local distance=math.abs(npc.x-x)
                if distance<closestNPC then
                    closestNPC=distance
                    nearby.npcId=npc.id
                end
            end
            local nearestWood=math.huge
            for _,site in ipairs(state.sites) do
                if site.item=="wood" and site.remaining>=2 then
                    local distance=math.abs(site.x-x)
                    if distance<nearestWood then
                        nearestWood=distance
                        nearby.nearestWoodDistance=math.floor(distance+0.5)
                        nearby.nearestWoodDirection=if site.x<x then "esquerda"
                            else "direita"
                    end
                    local surface=Profile.sample(state.seed,site.x,0).height
                    if distance<=9 and math.abs(root.Position.Y-(surface+3))<=11 then
                        -- Do not claim that two depleted sources add up to
                        -- one craftable batch; use one real source at a time.
                        nearby.wood=math.max(nearby.wood,site.remaining)
                    end
                end
            end
            for _,b in ipairs(state.buildings) do
                if b.typeId=="stockpile" and b.state=="complete"
                    and b.health>0 and b.stored
                    and math.abs(b.x-x)<=12 then
                    if math.abs(root.Position.Y-(b.y+3))<=12 then
                        nearby.wood=math.max(nearby.wood,
                            b.stored.items.wood or 0)
                    end
                end
            end
            local closestCoin=6
            for _,coin in ipairs(state.r3.drops) do
                local distance=math.abs(coin.x-x)
                if not coin.claimed and distance<=closestCoin then
                    closestCoin=distance
                    nearby.coinId=coin.id
                end
            end
        end
        return {ok=true,data=overview,hud=R3.summary(state),nearby=nearby}
    end
    if action=="attack" or action=="bow" or action=="drop_coin"
        or action=="pickup_coin" or action=="arm_defender"
        or action=="trade" or action=="craft_arrows" or action=="take_wood"
        or action=="prologue" or action=="r3_status" then
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
