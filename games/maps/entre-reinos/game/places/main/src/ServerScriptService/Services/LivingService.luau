--!strict
-- T1-R2: server-owned NPC population, physical 3D representations, site stocks,
-- building progress, and world-snapshot integration. No loops run in the lobby.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local shared=ReplicatedStorage:WaitForChild("Game")
local Profile=require(shared:WaitForChild("WorldProfile"))
local Living=require(shared:WaitForChild("Living"):WaitForChild("LivingModel"))
local Work=require(shared:WaitForChild("Living"):WaitForChild("WorkEngine"))
local Structures=require(shared:WaitForChild("Living"):WaitForChild("StructureDefs"))
local Professions=require(shared:WaitForChild("Living"):WaitForChild("ProfessionDefs"))
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
    bill.AlwaysOnTop=true
    bill.MaxDistance=110
    bill.Size=UDim2.fromOffset(180,50)
    bill.StudsOffset=Vector3.new(0,4,0)
    bill.Adornee=part
    bill.Parent=part
    local caption=Instance.new("TextLabel")
    caption.Name="Info"
    caption.BackgroundColor3=Color3.fromRGB(17,25,19)
    caption.BackgroundTransparency=0.18
    caption.BorderSizePixel=0
    caption.Size=UDim2.fromScale(1,1)
    caption.Text=label
    caption.TextColor3=Color3.fromRGB(244,242,224)
    caption.Font=Enum.Font.GothamSemibold
    caption.TextSize=13
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
            item.CanCollide=false
            item.CanQuery=false
            item.CanTouch=false
            item.CastShadow=true
        end
    end
    local root=model:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then root.Anchored=true end
    model.Parent=visualization
    return model
end

local function syncNPC(npc: any)
    local model=figures[npc.id]
    if not model then return end
    local pos=Profile.sample(state.seed,npc.x,0)
    local y=pos.height+3.15
    local current=model:GetPivot()
    local desired=CFrame.new(npc.x,y,0)
    local direction=npc.targetX
    if type(direction)=="number" and direction<npc.x then
        desired*=CFrame.Angles(0,math.pi/2,0)
    elseif type(direction)=="number" and direction>npc.x then
        desired*=CFrame.Angles(0,-math.pi/2,0)
    end
    if (current.Position-desired.Position).Magnitude>0.06 then
        model:PivotTo(desired)
    end
    local h=model:FindFirstChildOfClass("Humanoid")
    if h then
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
    base.Position=Vector3.new(b.x,b.y+0.35,0)
    local wall=makePart(model,"Structure",Vector3.new(
        def.footprint-1,def.height,5),Color3.fromRGB(146,115,80))
    wall.Position=Vector3.new(b.x,b.y+def.height/2+1,0)
    wall.Transparency=0.80
    local tagPart=makePart(model,"InfoAnchor",
        Vector3.new(1,1,1),Color3.fromRGB(30,49,35))
    tagPart.Position=Vector3.new(b.x,b.y+def.height+3,0)
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
    siteDisplays[site.id]=gui
    label.Name="Remaining"
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
    owner=player
    state=loaded
    local folder=Instance.new("Folder")
    folder.Name="ER_LivingWorld"
    folder:SetAttribute("ER_Saveable",true)
    folder.Parent=workspace
    visualization=folder
    for _,site in ipairs(state.sites) do createSiteVisual(site) end
    for i,npc in ipairs(state.npcs) do
        if onProgress then
            onProgress((i-1)/#state.npcs,"Preparando morador "..tostring(i).."/"..tostring(#state.npcs))
        end
        local model=createActor(npc)
        if model then figures[npc.id]=model end
    end
    if onProgress then onProgress(1,"Moradores preparados") end
    for _,b in ipairs(state.buildings) do buildVisual(b) end
    draw()

    -- A fixed, bounded tick keeps worker jobs deterministic and avoids
    -- a heavy per-frame task per NPC; presentation is LOD-throttled.
    connection=RunService.Heartbeat:Connect(function(dt: number)
        if not owner or not state or player.Parent~=Players
            or player:GetAttribute("ER_WorldLoaded")~=true then return end
        simulationAccumulator+=math.min(dt,0.25)
        local ticks=0
        while simulationAccumulator>=0.1 and ticks<3 do
            Work.step(state,0.1)
            simulationAccumulator-=0.1
            ticks+=1
        end
        drawAccumulator+=dt
        if drawAccumulator>=0.12 then
            drawAccumulator=0
            draw()
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
    if action~="build" then return {ok=false,error="invalid_action"} end
    if type(typeId)~="string" or not Structures.get(typeId) then
        return {ok=false,error="invalid_structure"}
    end
    local now=os.clock()
    if lastActionAt[player] and now-lastActionAt[player]<0.65 then
        return {ok=false,error="rate_limited"}
    end
    lastActionAt[player]=now
    local character=player.Character
    local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
    if not root or not root:IsA("BasePart") then
        return {ok=false,error="character_not_ready"}
    end
    -- Server chooses the placement position from the real character,
    -- never from a client-supplied X coordinate.
    local x=math.round((root.Position.X+15)/2)*2
    if math.abs(root.Position.Z)>4 then return {ok=false,error="outside_playable_lane"} end
    local placed,result=Work.place(state,typeId,x)
    if not placed then return {ok=false,error=result} end
    buildVisual(result)
    return {ok=true,buildingId=result.id,x=result.x,typeId=typeId}
end
return Service
