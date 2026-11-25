--!strict
-- T1-R2: server-owned NPC population, physical 3D representations, site stocks,
-- building progress, and world-snapshot integration. No loops run in the lobby.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local PhysicsService=game:GetService("PhysicsService")
local Lighting=game:GetService("Lighting")
local shared=ReplicatedStorage:WaitForChild("Game")
local Profile=require(shared:WaitForChild("RegionalProfile"))
local Regions=require(shared:WaitForChild("RegionalWorld"))
local BridgeScene=require(script.Parent:WaitForChild("BridgeScene"))
local Travel=require(script.Parent:WaitForChild("TravelService"))
local Saves=require(script.Parent:WaitForChild("SaveSlotService"))
local Living=require(shared:WaitForChild("Living"):WaitForChild("LivingModel"))
local Work=require(shared:WaitForChild("Living"):WaitForChild("WorkEngine"))
local Production=require(shared:WaitForChild("Living"):WaitForChild("Production"))
local Market=require(shared:WaitForChild("Living"):WaitForChild("Market"))
local R3=require(shared:WaitForChild("Living"):WaitForChild("R3Engine"))
local Combat=require(script.Parent:WaitForChild("CombatService"))
local Structures=require(shared:WaitForChild("Living"):WaitForChild("StructureDefs"))
local Professions=require(shared:WaitForChild("Living"):WaitForChild("ProfessionDefs"))
local Inventory=require(shared:WaitForChild("Living"):WaitForChild("Inventory"))
local WorldService=require(script.Parent:WaitForChild("WorldService"))
local Service={}
local owner: Player?=nil
local state: any=nil
local regional: any=nil
local bridgeFolder: Folder?=nil
local visualization: Folder?=nil
local figures: {[number]: Model}={}
local animals: {[number]: Model}={}
local buildings: {[number]: Model}={}
local siteVisuals: {[string]: BasePart}={}
local treePress: any=nil
local treeSerial=0
local lastTreePress=0
local Ballistics=require(shared:WaitForChild("Living"):WaitForChild("Ballistics"))
local connection: RBXScriptConnection?=nil
local simulationAccumulator=0
local drawAccumulator=0
local lastActionAt=0
local lastPreviewAt=0
local buildPreview: any=nil
local previewId=0
-- Non-physical R6 residents. Logical work coordinates remain untouched.
local GHOST_GROUP="ER_GhostNPC"
if not PhysicsService:IsCollisionGroupRegistered(GHOST_GROUP) then
    PhysicsService:RegisterCollisionGroup(GHOST_GROUP)
end
PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP,GHOST_GROUP,false)
PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP,"Default",false)

-- Real persisted simulation coordinates: a resident is free to cross depth.
-- No modulo-ID lanes or fixed per-person offsets.
local function actorX(npc: any): number
    return npc.x
end
local function actorZ(npc: any): number
    return npc.z or 0
end

local SKIN_TONES={
    Color3.fromRGB(233,194,158), Color3.fromRGB(218,170,132),
    Color3.fromRGB(201,145,104), Color3.fromRGB(185,126,91),
    Color3.fromRGB(167,110,78), Color3.fromRGB(147,95,67),
    Color3.fromRGB(124,80,57), Color3.fromRGB(104,67,50),
    Color3.fromRGB(85,57,43),
}
local function skinFor(seed: number,id: number): Color3
    return SKIN_TONES[1+((seed%157+id*71)%#SKIN_TONES)]
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
    local torso=model:FindFirstChild("Torso")
    if torso and torso:IsA("BasePart") then
        local palette={
            carpenter=Color3.fromRGB(124,85,57),builder=Color3.fromRGB(133,111,63),
            miner=Color3.fromRGB(81,104,118),common=Color3.fromRGB(99,124,84),
        }
        torso.Color=palette[npc.profession] or palette.common
    end
    local skin=skinFor(state.seed,npc.id)
    local body=model:FindFirstChildOfClass("BodyColors")
    if not body then
        body=Instance.new("BodyColors")
        body.Parent=model
    end
    body.HeadColor3=skin
    body.LeftArmColor3=skin
    body.RightArmColor3=skin
    body.LeftLegColor3=skin
    body.RightLegColor3=skin
    -- Keep professional clothing distinguishable from human skin.
    body.TorsoColor3=if torso and torso:IsA("BasePart") then torso.Color
        else skin
    if humanoid then
        humanoid.DisplayName=npc.name.." · "..prof.label
        humanoid.AutoRotate=false
        if not humanoid:FindFirstChildOfClass("Animator") then
            Instance.new("Animator").Parent=humanoid
        end
    end
    model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
    model:SetAttribute("ER_NativeR6",true)
    model:SetAttribute("ER_SkinPalette",1+((state.seed%157+npc.id*71)%#SKIN_TONES))
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
    model:SetAttribute("ER_NPCVelocityZ",0)
    local x,z=actorX(npc),actorZ(npc)
    local target=Vector3.new(x,groundHeight(x,z)+feetOffset+0.14,z)
    model:SetAttribute("ER_NPCPose",target)
    model:SetAttribute("ER_NPCFacing",0)
    model:PivotTo(CFrame.new(target))
    model.Parent=visualization
    return model
end

local function attachment(model: Model, name: string, key: string, limb: string,
        size: Vector3, color: Color3, offset: CFrame)
    if model:GetAttribute(name)==key then return end
    model:SetAttribute(name,key)
    local previous=model:FindFirstChild(name)
    if previous then previous:Destroy() end
    if key=="" then return end
    local holder=model:FindFirstChild(limb)
    if not holder or not holder:IsA("BasePart") then return end
    local piece=makePart(model,name,size,color)
    piece.CFrame=holder.CFrame*offset
    piece.Material=Enum.Material.Wood
    piece.Anchored=false
    piece.Massless=true
    local weld=Instance.new("WeldConstraint")
    weld.Part0=holder
    weld.Part1=piece
    weld.Parent=piece
    if key=="bow" then
        for side=-1,1,2 do
            local endPiece=makePart(piece,"BowLimb",Vector3.new(0.16,0.95,0.2),color)
            endPiece.CFrame=piece.CFrame*CFrame.new(0,1.1*side,-0.21)
                *CFrame.Angles(side*0.56,0,0)
            endPiece.Anchored=false
            endPiece.Massless=true
            local join=Instance.new("WeldConstraint")
            join.Part0=piece
            join.Part1=endPiece
            join.Parent=endPiece
        end
    end
end

local activities={
    collect="Coletando",load="Retirando estoque",build="Construindo",fabricate="Fabricando",farm="Cultivando",hunt="Caçando",rest="Descansando",freight="Em transporte comercial",
    flee="Em fuga",sheltered="Em abrigo",strike="Defendendo",
}

local function syncNPC(npc: any)
    local model=figures[npc.id]
    if not model then return end
    if npc.health<=0 then
        model:Destroy()
        figures[npc.id]=nil
        return
    end
    local x,z=actorX(npc),actorZ(npc)
    local offset=model:GetAttribute("ER_FeetOffset")
    if type(offset)~="number" then return end
    local last=model:GetAttribute("ER_NPCPose")
    local deck=Work.deckAt(state,x,z,if Inventory.weight(npc.inventory)>0 then "carrier" else "worker")
    local y=(deck or (if typeof(last)=="Vector3" and last.X==x and last.Z==z
        then last.Y-offset-0.14 else groundHeight(x,z)))+offset+0.14
    local target=Vector3.new(x,y,z)
    local motion=if type(npc.motionX)=="number" then npc.motionX else 0
    local motionZ=if type(npc.motionZ)=="number" then npc.motionZ else 0
    local vx=math.clamp(motion,-9,9)
    local vz=math.clamp(motionZ,-9,9)
    -- A single replicated pose is atomic; clients do their own frame-level
    -- interpolation from this logical position. No low-FPS PivotTo on server.
    model:SetAttribute("ER_NPCPose",target)
    model:SetAttribute("ER_NPCVelocityX",vx)
    model:SetAttribute("ER_NPCVelocityZ",vz)
    local facing=model:GetAttribute("ER_NPCFacing")
    -- Target yaw turns to real 2D velocity instead of swapping sideways
    -- when a citizen walks toward/away from the camera.
    if math.sqrt(vx*vx+vz*vz)>0.12 then
        facing=math.atan2(-vx,-vz)
    end
    if type(facing)=="number" then model:SetAttribute("ER_NPCFacing",facing) end
    local activity=if npc.defenseClock and npc.defenseClock>1.04 then "strike" else npc.activity or ""
    model:SetAttribute("ER_NPCActivity",activity)
    model:SetAttribute("Profession",npc.profession)
    local h=model:FindFirstChildOfClass("Humanoid")
    if h then h.DisplayName=npc.name.." · "..(activities[activity] or Professions.get(npc.profession).label) end
    local working=activity=="collect" or activity=="build" or activity=="fabricate" or activity=="farm"
    local weapon=if activity=="strike" then npc.defense or ""
        elseif working and npc.tool then npc.tool.item
        elseif not state.production then npc.defense or "" else ""
    attachment(model,"HeldItem",weapon,"Right Arm",
        if weapon=="spear" then Vector3.new(0.17,4.4,0.17)
            elseif weapon=="bow" then Vector3.new(0.2,1.65,0.24)
            else Vector3.new(0.35,1.45,0.35),
        Color3.fromRGB(115,78,50),CFrame.new(0,-0.6,-0.5))
    attachment(model,"Cargo",if npc.tradeLoad or Inventory.weight(npc.inventory)>0 then "bag" else "",
        "Torso",Vector3.new(1.65,1.3,0.72),Color3.fromRGB(156,125,77),CFrame.new(0,0,0.82))

end
local function buildPiece(model: Model,b: any,name: string,
        size: Vector3,offset: Vector3,color: Color3,tilt: number?): Part
    local p=makePart(model,name,size,color)
    p.CFrame=CFrame.new(b.x+offset.X,b.y+offset.Y,Structures.DEPTH_Z+offset.Z)
        *CFrame.Angles(0,0,tilt or 0)
    p:SetAttribute("ER_StructurePiece",true)
    p.CastShadow=true
    return p
end
local function buildVisual(b: any)
    if not visualization or b.crossingId then return end
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
    foundation.Position=Vector3.new(b.x,b.y+0.22,if b.typeId=="gate" then 0 else -10)
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
    elseif b.typeId=="workshop" or b.typeId=="forge" then
        buildPiece(model,b,"Bench",Vector3.new(7,1,4),Vector3.new(0,2.7,0),wood)
        buildPiece(model,b,"Roof",Vector3.new(11,0.9,7),Vector3.new(0,7,0),roof)
        for _,side in ipairs({-1,1}) do
            buildPiece(model,b,"Post",Vector3.new(0.8,6.5,0.8),Vector3.new(side*4,3.5,1.9),wood)
        end
        if b.typeId=="forge" then
            buildPiece(model,b,"Chimney",Vector3.new(3,10,3),Vector3.new(3,5,-1),stone)
            buildPiece(model,b,"FurnaceOpening",Vector3.new(1.6,1.25,0.2),
                Vector3.new(3,2,0.55),Color3.fromRGB(214,101,48))
        end
    elseif b.typeId=="farm" then
        for row=-1,1 do
            buildPiece(model,b,"Soil",Vector3.new(12,0.3,1.4),
                Vector3.new(0,0.75,row*2),Color3.fromRGB(117,81,48))
            for column=-2,2 do
                local plant=buildPiece(model,b,"Crop",Vector3.new(0.55,1.1,0.58),
                    Vector3.new(column*2,1.4,row*2),Color3.fromRGB(132,151,67))
                plant.CanCollide=false
            end
        end
    elseif b.typeId=="castle" then
        buildPiece(model,b,"Keep",Vector3.new(12,14,7),Vector3.new(0,7,0),stone)
        for _,side in ipairs({-1,1}) do
            buildPiece(model,b,"Tower",Vector3.new(4.4,18,8),
                Vector3.new(side*6,9,0),pale)
            for notch=-1,1 do
                buildPiece(model,b,"Merlon",Vector3.new(1,2,1.2),
                    Vector3.new(side*6+notch*1.35,19,4),stone)
            end
        end
        buildPiece(model,b,"Gate",Vector3.new(3.2,6,0.8),Vector3.new(0,3,3.7),wood)
        buildPiece(model,b,"Pennant",Vector3.new(2,3,0.25),Vector3.new(0,15.5,3.7),
            Color3.fromRGB(116,53,48))
    elseif b.typeId=="fence" then
        for i=-2,2 do
            buildPiece(model,b,"Palisade",Vector3.new(0.75,5.8,1.2),
                Vector3.new(i*1.16,3.2,0),wood)
        end
        for _,height in ipairs({2.4,4.5}) do
            buildPiece(model,b,"FenceRail",Vector3.new(def.footprint-0.5,0.6,1),
                Vector3.new(0,height,-0.6),Color3.fromRGB(146,102,61))
        end
    elseif b.typeId=="gate" then
        for _,edge in ipairs({-1,1}) do
            buildPiece(model,b,"Pilar",Vector3.new(1.1,8.8,1.1),Vector3.new(0,4.4,10+edge*3.8),stone)
        end
        buildPiece(model,b,"Trave",Vector3.new(1.9,0.7,9.2),Vector3.new(0,8.4,10),stone)
        buildPiece(model,b,"Folha",Vector3.new(0.84,7.2,6.9),Vector3.new(0,3.7,10),wood)
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
    tagPart:SetAttribute("ER_Inspectable",true)
    model.Parent=visualization
    buildings[b.id]=model
end
local function syncBuild(b: any)
    if not buildings[b.id] then buildVisual(b) end
    local model=buildings[b.id]
    if not model then return end
    local def=Structures.get(b.typeId)
    if not def then return end
    local ratio=b.health/def.health
    local progress=math.clamp(math.floor(6*b.progress/def.buildSeconds),0,6)
    local stock=if b.typeId=="stockpile" and b.stored then Inventory.weight(b.stored) else 0
    local cargo=math.clamp(math.ceil(stock/30),0,3)
    local damage=if ratio<=0.35 then 2 elseif ratio<=0.68 then 1 else 0
    local visual=b.state..":"..tostring(progress)..":"..tostring(damage)..":"..tostring(cargo)
        ..":"..tostring(b.open==true)..":"..tostring(b.plot and b.plot.stage)
    if model:GetAttribute("ER_LastVisualState")~=visual then
        model:SetAttribute("ER_LastVisualState",visual)
        local index,crate=0,0
        for _,p in ipairs(model:GetChildren()) do
            if not p:IsA("BasePart") or p:GetAttribute("ER_StructurePiece")~=true then continue end
            index+=1
            if p.Name=="SupplyCrate" then crate+=1 end
            local section=math.clamp(math.floor((p.Position.Y-b.y)/def.height*6),0,5)
            if p.Name=="Crop" then
                local crop=b.state=="complete" and b.plot and (b.plot.stage=="grow" or b.plot.stage=="harvest")
                p.Transparency=if crop then 0 else 1
                p.Color=if b.plot and b.plot.stage=="harvest" then Color3.fromRGB(222,178,70) else Color3.fromRGB(132,151,67)
            elseif b.state=="blueprint" then
                p.Transparency=if section<=1 then 0.48 else 1
            elseif b.state=="building" then
                p.Transparency=if section<=progress then 0.08 else 1
            elseif b.state=="ruined" then
                p.Transparency=if section<=1 then 0.28 else 1
            elseif p.Name=="SupplyCrate" then
                p.Transparency=if crate<=cargo then 0 else 1
            elseif damage==2 and section>=3 and index%3==0 then
                p.Transparency=0.88
            else
                p.Transparency=0
            end
            if p.Name=="Folha" and b.typeId=="gate" then
                local active=b.state=="complete" or b.state=="damaged"
                p.CanCollide=active and not b.open
                p.Position=Vector3.new(b.x,b.y+(if active and b.open then 11.1 else 3.7),0)
            end
            local base=p:GetAttribute("ER_UndamagedColor")
            if typeof(base)~="Color3" then
                base=p.Color
                p:SetAttribute("ER_UndamagedColor",base)
            end
            if p.Name~="Crop" then p.Color=base:Lerp(Color3.fromRGB(54,42,38),damage*0.20) end
        end
    end

end

local function createSiteVisual(site: any)
    if not visualization then return end
    local z=site.z or (if site.item=="wood" then -6 else -4)
    local pos=Profile.sample(state.seed,site.x,if site.z then z else 0)
    local anchor: BasePart
    if site.item=="wood" and not site.salvage and not string.match(site.id,"salvage_") then
        -- Distinct harvestable tree; background trees remain decoration.
        local tree=Instance.new("Model")
        tree.Name="HarvestableTree_"..tostring(site.id)
        tree:SetAttribute("ER_Harvestable",true)
        tree:SetAttribute("ER_SourceId",site.id)
        local trunk=makePart(tree,"Trunk",
            Vector3.new(2.1,7.2,2.1),Color3.fromRGB(112,75,47))
        trunk.Position=Vector3.new(site.x,pos.height+3.6,z)
        for k=1,3 do
            local leaves=makePart(tree,"LeafCrown",
                Vector3.new(7.5-k*1.1,3.8,7.5-k*1.1),
                Color3.fromRGB(63,116,77))
            leaves.Shape=Enum.PartType.Ball
            leaves.Position=Vector3.new(site.x,pos.height+7.1+k*1.8,z)
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
    else
        -- Each resource has its own recognizable shape and palette.
        local color=if site.item=="stone" then Color3.fromRGB(126,131,130)
            else if site.item=="iron" then Color3.fromRGB(97,116,132)
            else Color3.fromRGB(96,151,88)
        local block=makePart(visualization,"Resource_"..site.id,
            if site.item=="food" then Vector3.new(3.7,2.6,3.7)
            else Vector3.new(3.8,3,3.4),color)
        block.Shape=if site.item=="food" then Enum.PartType.Ball else Enum.PartType.Block
        block.Position=Vector3.new(site.x,pos.height+1.4,z)
        anchor=block
    end
    anchor:SetAttribute("ResourceType",site.item)
    anchor:SetAttribute("SourceId",site.id)
    siteVisuals[site.id]=anchor
end

local function syncR3Hud(player: Player)
    local data=R3.summary(regional.home)
    player:SetAttribute("ER_R3Wallet",data.wallet)
    player:SetAttribute("ER_R3Arrows",data.arrows)
    player:SetAttribute("ER_R3Day",data.day)
    player:SetAttribute("ER_R3Night",data.night)
    player:SetAttribute("ER_R3Raid",data.raidActive)
    player:SetAttribute("ER_R3Enemies",data.enemies)
    player:SetAttribute("ER_R3Phase",data.phase)
    player:SetAttribute("ER_R3Warning",data.warning)
    player:SetAttribute("ER_R3Forecast",data.raidForecast)
    player:SetAttribute("ER_PlayerDeaths",data.deaths)
    Lighting.ClockTime=((regional.home.elapsed%R3.DAY)/10+6)%24
end

local function drawAnimals(observerX: number)
    local live={}
    local population=if state.production then state.production.fauna else nil
    for _,a in ipairs(population or {}) do
        if math.abs(a.x-observerX)>145 or not WorldService.isLoadedAt(a.x) then continue end
        local figure=animals[a.id]
        if not figure then
            figure=Instance.new("Model")
            figure.Name="Deer_"..tostring(a.id)
            local brown=Color3.fromRGB(139,97,64)
            local function piece(name: string,size: Vector3,offset: Vector3)
                local part=makePart(figure :: Model,name,size,brown)
                part.Position=offset
                part.CanCollide=false
                part.CanQuery=false
            end
            piece("Body",Vector3.new(2.8,1.35,0.9),Vector3.new(0,1.45,0))
            piece("Head",Vector3.new(0.95,0.85,0.65),Vector3.new(1.5,2.26,0))
            piece("Neck",Vector3.new(0.55,1.1,0.6),Vector3.new(1.06,1.95,0))
            for _,dx in ipairs({-0.95,0.9}) do
                for _,z in ipairs({-0.33,0.33}) do
                    piece("Leg",Vector3.new(0.23,1.15,0.24),Vector3.new(dx,0.59,z))
                end
            end
            figure.WorldPivot=CFrame.identity
            figure.Parent=visualization
            animals[a.id]=figure
        end
        figure:PivotTo(CFrame.new(a.x,groundHeight(a.x,a.z),a.z)*CFrame.Angles(0,if a.flight<0 then math.pi else 0,0))
        live[a.id]=true
    end
    for id,model in pairs(animals) do
        if not live[id] then model:Destroy();animals[id]=nil end
    end
end

local function draw(observerX: number)
    if not state then return end
    drawAnimals(observerX)
    for _,npc in ipairs(state.npcs) do
        local distance=math.abs(npc.x-observerX)
        if distance>220 and figures[npc.id] then
            figures[npc.id]:Destroy()
            figures[npc.id]=nil
        elseif distance<175 and npc.health>0 and not figures[npc.id] and WorldService.isLoadedAt(npc.x) then
            figures[npc.id]=createActor(npc)
        end
        syncNPC(npc)
    end
    local _,courier=Market.freight(regional)
    if courier and math.abs(courier.x-observerX)<145 and courier.health>0 and WorldService.isLoadedAt(courier.x)
        and not table.find(state.npcs,courier) then
        if not figures[courier.id] then figures[courier.id]=createActor(courier) end
        syncNPC(courier)
    end
    for id,figure in pairs(figures) do
        if figure:GetAttribute("ER_ExternalCourier")==true and (not courier or courier.id~=id or math.abs(courier.x-observerX)>=145) then
            figure:Destroy()
            figures[id]=nil
        end
    end
    if courier and figures[courier.id] then
        figures[courier.id]:SetAttribute("ER_ExternalCourier",not table.find(state.npcs,courier))
    end
    for _,b in ipairs(state.buildings) do
        if not b.crossingId and WorldService.isLoadedAt(b.x) then syncBuild(b) end
    end
    for _,site in ipairs(state.sites) do
        if not siteVisuals[site.id] and WorldService.isLoadedAt(site.x) then createSiteVisual(site) end
        if site.item=="wood" and visualization then
            local tree=visualization:FindFirstChild("HarvestableTree_"..tostring(site.id))
            if tree and tree:IsA("Model") then
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

local function selectPopulation(x: number)
    local selected,changed=Regions.activate(regional,x)
    if owner:GetAttribute("ER_RegionIndex")~=regional.activeRegion then
        owner:SetAttribute("ER_RegionIndex",regional.activeRegion)
    end
    if not changed then return end
    Combat.setTownVisible(selected==regional.home)
    for _,model in pairs(figures) do model:Destroy() end
    for _,model in pairs(animals) do model:Destroy() end
    table.clear(animals)
    for _,model in pairs(buildings) do model:Destroy() end
    for _,site in pairs(siteVisuals) do
        if site.Parent and site.Parent:IsA("Model") then site.Parent:Destroy() else site:Destroy() end
    end
    table.clear(figures)
    table.clear(buildings)
    table.clear(siteVisuals)
    buildPreview=nil
    treePress=nil
    state=selected
    owner:SetAttribute("ER_Kingdom",if state==regional.home then "Vale do Duque" else "Vila do Cedro")
end

local function syncBridges()
    if not bridgeFolder then return end
    local live={}
    for _,bridge in ipairs(regional.bridges()) do
        if not WorldService.isLoadedAt(bridge.x) then continue end
        local plan=Work.bridgePlan(state,bridge.x)
        if plan then
            BridgeScene.sync(bridgeFolder,bridge,plan,Structures.get(bridge.typeId).buildSeconds)
            live[plan.id]=true
        end
    end
    for _,model in ipairs(bridgeFolder:GetChildren()) do
        if not live[model.Name] then model:Destroy() end
    end
end

function Service.playerDied(player: Player)
    if owner~=player or not regional then return end
    R3.playerDied(regional.home)
    Travel.playerDied(player)
end

function Service.playerRecovered(player: Player)
    if owner==player and regional then regional.home.r3.awaitingRecovery=false end
end

function Service.snapshot(player: Player): (any,any)
    if owner~=player or not regional then return nil,nil end
    return Living.clone(regional.home),Regions.snapshot(regional)
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
    if worldRecord.living==nil then
        Work.initializeVillage(loaded)
    end
    local Slots=require(shared:WaitForChild("SlotModel"))
    local origin=Slots.spawnPosition(worldRecord)
    regional=Regions.new(worldRecord.seed,loaded,worldRecord.regionWorld,origin,WorldService.isLoadedAt)
    if not regional then return false,"regional_schema_conflict" end
    owner=player
    state=loaded
    loaded.r3.awaitingRecovery=false -- Boot placed a reconnecting character before loading the world.
    local folder=Instance.new("Folder")
    folder.Name="ER_LivingWorld"
    folder:SetAttribute("ER_Saveable",true)
    folder.Parent=workspace
    visualization=folder
    local crossings=Instance.new("Folder")
    crossings.Name="ER_Bridges"
    crossings.Parent=folder
    bridgeFolder=crossings
    local prepared, prepareError=pcall(function()
        selectPopulation(origin.x)
        if onProgress then onProgress(1,"Moradores preparados") end
        Combat.start(player,regional.home,folder)
        Combat.setTownVisible(state==regional.home)
        Travel.start(player,regional,folder,function(traveller,destination)
            local ok,reason=Saves.save(traveller,false,destination)
            if not ok and reason=="datastore_unavailable" then return Saves.save(traveller,false,destination) end
            return ok,reason
        end)
        syncBridges()
        draw(origin.x)
        syncR3Hud(player)
    end)
    if not prepared then
        warn("[EntreReinos][Living] Preparation failed; rolling back visual state: ",prepareError)
        owner=nil
        state=nil
        figures={}
        buildings={}
        siteVisuals={}
    treePress=nil
    lastTreePress=0
        visualization=nil
        Combat.stop()
        Travel.stop()
        folder:Destroy()
        return false,"living_visual_setup_failed"
    end

    -- A fixed, bounded tick keeps worker jobs deterministic and avoids
    -- a heavy per-frame task per NPC; presentation is LOD-throttled.
    connection=RunService.Heartbeat:Connect(function(dt: number)
        if not owner or not state or player.Parent~=Players
            or player:GetAttribute("ER_WorldLoaded")~=true then return end
        local character=player.Character
        local currentRoot=if character then character:FindFirstChild("HumanoidRootPart") else nil
        if currentRoot and currentRoot:IsA("BasePart") then
            selectPopulation(currentRoot.Position.X)
        end
        local observerX=if currentRoot and currentRoot:IsA("BasePart") then currentRoot.Position.X else 0
        local hasNearbyResident=false
        for _,npc in ipairs(state.npcs) do
            if npc.health>0 and math.abs(observerX-npc.x)<160 then hasNearbyResident=true; break end
        end
        simulationAccumulator=if hasNearbyResident then simulationAccumulator+math.min(dt,0.25) else 0
        local ticks=0
        while simulationAccumulator>=0.1 and ticks<3 do
            if regional.home.r3.prologue.stage=="sandbox" then Production.ensure(state) end
            Work.step(state,0.1)
            Market.stepFreight(regional,0.1,Work)
            local currentRoot=if player.Character then
                player.Character:FindFirstChild("HumanoidRootPart") else nil
            local x=if currentRoot and currentRoot:IsA("BasePart")
                then currentRoot.Position.X else 0
            local h=if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
            local y=if currentRoot and currentRoot:IsA("BasePart") and h and h.Health>0
                then currentRoot.Position.Y else -100
            local damage=if state==regional.home then R3.step(state,0.1,x,Combat.fireResident,y) else 0
            if damage>0 and player.Character then
                local h=player.Character:FindFirstChildOfClass("Humanoid")
                if h and h.Health>0 then h:TakeDamage(damage) end
            end
            simulationAccumulator-=0.1
            ticks+=1
        end
        Combat.tick(dt)
        Travel.tick(dt)
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
                local ahead=math.clamp(npc.x+math.sign((npc.targetX or npc.x)-npc.x)*10,
                    -Profile.PLAY_EDGE,Profile.PLAY_EDGE)
                if npc.health>0 and not WorldService.isLoadedAt(ahead) then
                    local streamed,reason=WorldService.ensureNear(state.seed,npc.x)
                    if not streamed and reason~="world_generation_in_progress" then
                        warn("[EntreReinos][Living] Worker chunk load: ",reason)
                    end
                    break
                end
            end
            Combat.present()
            syncBridges()
            draw(observerX)
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
    Travel.stop()
    buildPreview=nil
    lastPreviewAt=0
    lastActionAt=0
    owner=nil
    state=nil
    regional=nil
    bridgeFolder=nil
    figures={}
    buildings={}
    siteVisuals={}
    treePress=nil
    lastTreePress=0
    if visualization then visualization:Destroy() end
    visualization=nil
end

local function placementGround(typeId: string, x: number, root: BasePart): (boolean, any, any?)
    local allowed,reason=Work.canPlace(state,typeId,x)
    if not allowed then return false,reason end
    local definition=Structures.get(typeId)
    if definition.kind=="crossing" then
        local crossing=Work.bridgePlan(state,x)
        if not crossing then return false,"invalid_bridge_banks" end
        if math.min(math.abs(root.Position.X-crossing.west.x),math.abs(root.Position.X-crossing.east.x))
            >Structures.PLACEMENT_RANGE then return false,"build_too_far" end
        local wet=RaycastParams.new()
        wet.FilterType=Enum.RaycastFilterType.Include
        wet.FilterDescendantsInstances={workspace.Terrain}
        for _,bank in ipairs({crossing.west,crossing.east}) do
            if not WorldService.ensureNear(state.seed,bank.x) then return false,"terrain_not_ready" end
            for _,z in ipairs({-2,0,2}) do
                local hit=workspace:Raycast(Vector3.new(bank.x,70,z),Vector3.new(0,-120,0),wet)
                if not hit then return false,"terrain_not_ready" end
                if hit.Material==Enum.Material.Water or math.abs(hit.Position.Y-bank.y)>3 then
                    return false,"invalid_bridge_banks"
                end
            end
        end
        return true,(crossing.deckWestY+crossing.deckEastY)/2,crossing
    end
    if math.abs(x-root.Position.X)>Structures.PLACEMENT_RANGE then
        return false,"build_too_far"
    end
    local streamed=WorldService.ensureNear(state.seed,x-definition.footprint/2)
    if not streamed then return false,"terrain_not_ready" end
    local placementDepth=if typeId=="gate" then 0 else Structures.DEPTH_Z
    local minHeight=math.huge
    local maxHeight=-math.huge
    local centerHeight=0
    for _,offset in ipairs({Vector2.zero,Vector2.new(-1,-1),Vector2.new(-1,1),
        Vector2.new(1,-1),Vector2.new(1,1)}) do
        local origin=Vector3.new(x+offset.X*definition.footprint/2,70,
            placementDepth+offset.Y*3.5)
        local hit=workspace:Raycast(origin,Vector3.new(0,-120,0),groundCast)
        if not hit or Profile.sample(state.seed,origin.X,origin.Z).wet then
            return false,"invalid_footprint_or_slope"
        end
        minHeight=math.min(minHeight,hit.Position.Y)
        maxHeight=math.max(maxHeight,hit.Position.Y)
        if offset==Vector2.zero then centerHeight=hit.Position.Y end
    end
    if maxHeight-minHeight>definition.maxSlope then return false,"invalid_footprint_or_slope" end
    local overlap=OverlapParams.new()
    overlap.RespectCanCollide=true
    overlap.MaxParts=1
    overlap.FilterType=Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances={workspace.Terrain,root.Parent :: Instance}
    local occupied=workspace:GetPartBoundsInBox(
        CFrame.new(x,centerHeight+definition.height/2+0.3,placementDepth),
        Vector3.new(definition.footprint,definition.height,7),overlap)
    if #occupied>0 then return false,"solid_obstruction" end
    return true,centerHeight
end

local function treeInReach(root: BasePart,id: any): any
    if type(id)~="string" or #id>64 then return nil end
    local anchor=siteVisuals[id]
    if not anchor or anchor.Name~="Trunk" or (root.Position-anchor.Position).Magnitude>12 then return nil end
    for _,site in ipairs(state.sites) do
        if site.id==id and site.item=="wood" and site.remaining>0 and not site.salvage then
            return site
        end
    end
    return nil
end

local function treeAction(player: Player,action: string,arg: any): any
    local character=player.Character
    local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
    local h=if character then character:FindFirstChildOfClass("Humanoid") else nil
    if not root or not root:IsA("BasePart") or not h or h.Health<=0 then
        return {ok=false,error="character_not_ready"}
    end
    local now=workspace:GetServerTimeNow()
    if action=="tree_press" then
        if now-lastTreePress<0.28 then return {ok=false,error="rate_limited"} end
        lastTreePress=now
        if not treeInReach(root,arg) then return {ok=false,error="wood_source_too_far"} end
        treeSerial+=1
        treePress={id=treeSerial,siteId=arg,root=root,at=now}
        return {ok=true,id=treeSerial,started=now}
    end
    local press=treePress
    if not press or arg~=press.id then return {ok=false,error="action_unavailable"} end
    treePress=nil
    if action=="tree_cancel" then return {ok=true} end
    local site=treeInReach(root,press.siteId)
    local duration=now-press.at
    if press.root~=root or duration>Ballistics.MAX_HOLD or not site then
        return {ok=false,error="wood_source_too_far"}
    end
    if action=="tree_mark" then
        if duration<Ballistics.MARK_HOLD then return {ok=false,error="hold_too_short"} end
        site.marked=not site.marked
        return {ok=true,marked=site.marked}
    end
    if state~=regional.home or site.z then
        if Work.sourceAvailable(state,site)<2 or not Inventory.add(regional.home.r3.playerBag,"wood",2) then
            return {ok=false,error="insufficient_wood"}
        end
        site.remaining-=2
        return {ok=true}
    end
    local ok,value=R3.takeWood(state,root.Position.X,root.Position.Y,site.id)
    return {ok=ok,error=if not ok then value else nil}
end

actions.OnServerInvoke=function(player: Player,action: any,arg: any,candidateX: any): any
    if owner~=player or not state or player:GetAttribute("ER_WorldLoaded")~=true then
        return {ok=false,error="world_not_loaded"}
    end
    if action=="status" then
        -- One read-only world overview for the whole immersive game HUD.
        -- Proximity is computed from the real server-observed character.
        local overview=Work.summary(state)
        local character=player.Character
        local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
        local nearby={kingdom=player:GetAttribute("ER_Kingdom"),wood=0,canTrade=false,canSellWood=false,canCraftArrows=false,npcId=0,coinId=0,
            nearestWoodDistance=-1,nearestWoodDirection=""}
        if root and root:IsA("BasePart") then
            local x=root.Position.X
            local y=root.Position.Y
            nearby.travel=Travel.status(player,root)
            nearby.boatCargo=Travel.cargoAvailable(player,root)
            if regional.home.r3.prologue.stage=="sandbox" and not regional.record.discovered["2"] then
                local offset=regional.center.x-x
                nearby.cedroDirection=if offset>=0 then "leste" else "oeste"
                nearby.cedroDistance=math.floor(math.abs(offset)+0.5)
            end
            nearby.district=Work.districtAt(state,x)
            nearby.storyAction=R3.storyAction(regional.home,x)
            nearby.localThreats=0
            for _,enemy in ipairs(regional.home.r3.enemies) do
                if Work.districtAt(state,enemy.x)==nearby.district then nearby.localThreats+=1 end
            end
            nearby.canTrade=state==regional.home and R3.marketNear(state,x,y)
            nearby.canSellWood=nearby.canTrade and R3.canSell(state,"wood",x,y)
            nearby.canCraftArrows=R3.arrowMaterial(regional.home,x,y)~=nil
            local closestNPC=15
            for _,npc in ipairs(state.npcs) do
                local distance=math.abs(npc.x-x)
                if npc.health>0 and distance<closestNPC then
                    closestNPC=distance
                    nearby.npcId=npc.id
                end
            end
            local nearestWood=math.huge
            local treeDistance=12
            for _,site in ipairs(state.sites) do
                local available=Work.sourceAvailable(state,site)
                local anchor=siteVisuals[site.id]
                if site.item=="wood" and site.remaining>0 and anchor and anchor.Name=="Trunk" then
                    local dist=(root.Position-anchor.Position).Magnitude
                    if dist<treeDistance then
                        treeDistance=dist
                        nearby.treeId=site.id
                        nearby.treeMarked=site.marked==true
                    end
                end
                if site.item=="wood" and available>=2 then
                    local distance=math.abs(site.x-x)
                    if distance<nearestWood then
                        nearestWood=distance
                        nearby.nearestWoodDistance=math.floor(distance+0.5)
                        nearby.nearestWoodDirection=if site.x<x then "esquerda"
                            else "direita"
                    end
                    local surface=Profile.sample(state.seed,site.x,0).height
                    if distance<=11 and math.abs(root.Position.Y-(surface+3))<=11 then
                        -- Do not claim that two depleted sources add up to
                        -- one craftable batch; use one real source at a time.
                        nearby.wood=math.max(nearby.wood,available)
                    end
                end
            end
            local buildingDistance=14
            for _,b in ipairs(state.buildings) do
                local distance=(root.Position-Vector3.new(b.x,b.y+3,if b.typeId=="gate" then 0 else Structures.DEPTH_Z)).Magnitude
                if b.typeId=="gate" and (b.state=="complete" or b.state=="damaged") and distance<=8 then
                    nearby.gate={id=b.id,open=b.open==true}
                end
                if distance<buildingDistance then
                    buildingDistance=distance
                    nearby.buildingId=b.id
                end
                if Work.usableStorage(b) and math.abs(b.x-x)<=13 then
                    if math.abs(root.Position.Y-(b.y+3))<=12 then
                        nearby.wood=math.max(nearby.wood,
                            Work.stockAvailable(state,b,"wood"))
                    end
                end
            end
            local closestCoin=6
            for _,coin in ipairs(regional.home.r3.drops) do
                local distance=math.abs(coin.x-x)
                if not coin.claimed and distance<=closestCoin then
                    closestCoin=distance
                    nearby.coinId=coin.id
                end
            end
        end
        if overview.market and root and root:IsA("BasePart") then
            local center=Market.center(state)
            nearby.marketHere=center~=nil and math.abs(root.Position.X-center.x)<=18
                and math.abs(root.Position.Y-center.y-3)<=10
            nearby.canContract=regional.record.discovered["2"]==true
            local contract=Market.freight(regional)
            if contract then
                nearby.freight={item=contract.item,units=contract.units,stage=contract.stage,returning=contract.returning}
            end
        end
        return {ok=true,data=overview,hud=R3.summary(regional.home),nearby=nearby}
    end
    if action=="travel" then return Travel.action(player,arg) end
    if action=="travel_cargo" then return Travel.cargo(player,arg) end
    if action=="gate" then
        local root=if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
        local h=if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
        if Travel.busy() or not root or not root:IsA("BasePart") or not h or h.Health<=0
            or os.clock()-lastActionAt<0.55 then return {ok=false,error="action_unavailable"} end
        for _,b in ipairs(state.buildings) do
            if b.id~=arg or b.typeId~="gate" or (b.state~="complete" and b.state~="damaged")
                or (root.Position-Vector3.new(b.x,b.y+3,0)).Magnitude>8 then continue end
            if b.open and math.abs(root.Position.X-b.x)<1.4 then
                return {ok=false,error="solid_obstruction"}
            end
            lastActionAt=os.clock()
            b.open=not b.open
            syncBuild(b)
            return {ok=true}
        end
        return {ok=false,error="action_unavailable"}
    end
    if Travel.busy() then return {ok=false,error="travel_unavailable"} end
    if action=="tree_press" or action=="tree_mark" or action=="tree_cancel" or action=="tree_take" then
        return treeAction(player,action,arg)
    end
    if action=="trade" and state.production then return {ok=false,error="invalid_market_order"} end
    if action=="arm_defender" and state~=regional.home then
        return Combat.action(player,action,arg,state)
    end
    if action=="attack" or action=="bow_begin" or action=="bow_release" or action=="bow_cancel"
        or action=="select_weapon" or action=="duke_talk" or action=="duke_accept" or action=="duke_close"
        or action=="drop_coin"
        or action=="pickup_coin" or action=="arm_defender"
        or action=="trade" or action=="craft_arrows" or action=="take_wood"
        or action=="prologue" or action=="r3_status" then
        return Combat.action(player,action,arg)
    end
    if action~="build" and action~="build_preview" and action~="build_cancel" and action~="produce" and action~="profession"
        and action~="market" and action~="freight" and action~="freight_cancel" then
        return {ok=false,error="invalid_action"}
    end
    local character=player.Character
    local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
    local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil
    if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health<=0 then
        return {ok=false,error="character_not_ready"}
    end
    if math.abs(root.Position.Z-Profile.LANE_Z)>4 then
        return {ok=false,error="outside_playable_lane"}
    end
    local now=os.clock()
    if action=="market" or action=="freight" or action=="freight_cancel" then
        if not state.production or not state.production.market or now-lastActionAt<0.55 then
            return {ok=false,error="action_unavailable"}
        end
        local center=Market.center(state)
        if not center or math.abs(root.Position.X-center.x)>18 or math.abs(root.Position.Y-center.y-3)>10 then
            return {ok=false,error="too_far_from_market"}
        end
        lastActionAt=now
        local ok,reason=false,"invalid_market_order"
        if action=="market" and type(arg)=="table" then
            ok,reason=Market.playerTrade(state,regional.home.r3,arg.id,arg.verb,arg.item,Work)
        elseif action=="freight" and type(arg)=="table" then
            ok,reason=Market.openContract(regional,arg.seller,arg.item,arg.units,arg.id,Work)
        elseif action=="freight_cancel" and regional.home.production and regional.home.production.market then
            ok=Market.cancel(regional)
        end
        return {ok=ok,error=if not ok then reason else nil}
    end
    if action=="profession" then
        if not state.production or type(arg)~="string" or #arg>30 or now-lastActionAt<0.55 then
            return {ok=false,error="action_unavailable"}
        end
        local id,role=string.match(arg,"^(%d+):([a-z]+)$")
        if role and Professions.get(role) then
            for _,npc in ipairs(state.npcs) do
                if npc.id==tonumber(id) and math.abs(root.Position.X-npc.x)<=12
                    and math.abs(root.Position.Y-groundHeight(npc.x,npc.z or 0))<8
                    and Work.changeProfession(state,npc,role) then
                    lastActionAt=now
                    return {ok=true}
                end
            end
        end
        return {ok=false,error="action_unavailable"}
    end
    if action=="produce" then
        if regional.home.r3.prologue.stage~="sandbox" or now-lastActionAt<0.55 then
            return {ok=false,error="action_unavailable"}
        end
        lastActionAt=now
        local ok,value=Production.enqueue(state,arg,root.Position.X)
        return {ok=ok,error=if not ok then value else nil}
    end
    if action=="build_preview" then
        if now-lastPreviewAt<0.15 then return {ok=false,error="rate_limited"} end
        lastPreviewAt=now
        buildPreview=nil
        local def=Structures.get(arg)
        if not def or def.buildable==false then return {ok=false,error="invalid_structure"} end
        if type(candidateX)~="number" or candidateX~=candidateX or math.abs(candidateX)>Profile.PLAY_EDGE then
            return {ok=false,error="outside_region"}
        end
        local x=math.round(candidateX)
        local available,height,crossing=placementGround(arg,x,root)
        if not available then return {ok=false,error=height} end
        previewId+=1
        buildPreview={id=previewId,x=x,typeId=arg}
        return {ok=true,previewId=previewId,
            x=if crossing then (crossing.west.x+crossing.east.x)/2 else x,
            y=height,district=Work.districtAt(state,x),bridge=crossing}
    end
    if action=="build" and buildPreview and arg==buildPreview.id and buildPreview.result then
        return buildPreview.result
    end
    if now-lastActionAt<0.65 then return {ok=false,error="rate_limited"} end
    lastActionAt=now
    if action=="build_cancel" then
        for _,b in ipairs(state.buildings) do
            if b.id==arg and math.abs(b.x-root.Position.X)>Structures.PLACEMENT_RANGE then
                return {ok=false,error="build_too_far"}
            end
        end
        local cancelled,reason=Work.cancel(state,arg)
        if cancelled and buildings[arg] then
            buildings[arg]:Destroy()
            buildings[arg]=nil
        end
        return {ok=cancelled,error=reason}
    end
    local plan=buildPreview
    if not plan or arg~=plan.id then return {ok=false,error="preview_changed"} end
    local available,height=placementGround(plan.typeId,plan.x,root)
    if not available then return {ok=false,error=height} end
    local placed,result=Work.place(state,plan.typeId,plan.x,height)
    if not placed then return {ok=false,error=result} end
    plan.result={ok=true,buildingId=result.id,x=result.x,typeId=plan.typeId}
    if result.crossingId then syncBridges() else buildVisual(result) end
    return plan.result
end
return Service
