--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Structures=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("StructureDefs"))
local Scene={}
local DECK_WIDTH=Structures.BRIDGE_DECK_WIDTH
local DECK_THICKNESS=Structures.BRIDGE_DECK_THICKNESS
local MOUNTED_CLEARANCE=7
local NATIVE_SURFACE_TOLERANCE=3

local function deckPose(crossing: any): (CFrame,number)
    local from=Vector3.new(crossing.west.x,crossing.deckWestY-DECK_THICKNESS/2,0)
    local to=Vector3.new(crossing.east.x,crossing.deckEastY-DECK_THICKNESS/2,0)
    return CFrame.new((from+to)/2)*CFrame.Angles(0,0,math.atan2(to.Y-from.Y,to.X-from.X)),(to-from).Magnitude
end

local function placementRole(part: BasePart): string
    local node: Instance?=part
    while node and node~=workspace do
        local role=node:GetAttribute("ER_PlacementRole")
        if type(role)=="string" then return role end
        if node:IsA("Model") and (node:FindFirstChildOfClass("Humanoid")
            or node:GetAttribute("ER_GaitKind")) then return "mobile_entity" end
        node=node.Parent
    end
    return if part.CanCollide then "structure" else "decoration"
end

local function vector(v: Vector3): {number}
    return {v.X,v.Y,v.Z}
end

local function partEvidence(part: BasePart, role: string): any
    return {name=part.Name,path=part:GetFullName(),class=part.ClassName,category=role,
        collisionGroup=part.CollisionGroup,canCollide=part.CanCollide,canQuery=part.CanQuery,
        size=vector(part.Size),position=vector(part.Position)}
end

function Scene.validatePlacement(crossing: any,ignored: {Instance}): (boolean,string?,any?)
    local pose,span=deckPose(crossing)
    local passage=pose*CFrame.new(0,MOUNTED_CLEARANCE/2,0)
    local size=Vector3.new(span,MOUNTED_CLEARANCE+DECK_THICKNESS,DECK_WIDTH)
    local evidence={crossing=crossing.id,volume={frame={passage:GetComponents()},size=vector(size)},parts={}}
    local terrain=workspace.Terrain
    local support=RaycastParams.new()
    support.FilterType=Enum.RaycastFilterType.Include
    support.FilterDescendantsInstances={terrain}
    for _,bank in ipairs({crossing.west,crossing.east}) do
        for _,z in ipairs({-DECK_WIDTH/2,0,DECK_WIDTH/2}) do
            local hit=workspace:Raycast(Vector3.new(bank.x,70,z),Vector3.new(0,-120,0),support)
            if not hit then return false,"terrain_not_ready",evidence end
            if hit.Material==Enum.Material.Water or math.abs(hit.Position.Y-bank.y)>NATIVE_SURFACE_TOLERANCE then
                return false,"invalid_bridge_banks",evidence
            end
        end
    end

    local overlap=OverlapParams.new()
    overlap.RespectCanCollide=true
    overlap.FilterType=Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances=ignored
    local fixed: {Instance}={}
    local candidates=workspace:GetPartBoundsInBox(passage,size,overlap)
    for _,part in ipairs(candidates) do
        local role=placementRole(part)
        if role~="mobile_entity" and role~="decoration" and role~="control" then
            table.insert(fixed,part)
        end
    end
    if #fixed==0 then return true,nil,evidence end

    -- Exact volume query for structural candidates. Bounding boxes alone can
    -- intersect the passage at empty corners of sloped or hollow geometry.
    local volume=Instance.new("Part")
    volume.Name="ER_BridgePlacementVolume"
    volume.CFrame=passage
    volume.Size=size
    volume.Transparency=1
    volume.Anchored=true
    volume.CanCollide=false
    volume.CanTouch=false
    volume.CanQuery=false
    volume.Parent=workspace
    overlap.FilterType=Enum.RaycastFilterType.Include
    overlap.FilterDescendantsInstances=fixed
    local blocked=workspace:GetPartsInPart(volume,overlap)
    volume:Destroy()
    for _,part in ipairs(blocked) do
        table.insert(evidence.parts,partEvidence(part,placementRole(part)))
        if #evidence.parts==8 then break end
    end
    return #blocked==0,if #blocked>0 then "solid_obstruction" else nil,evidence
end
local function timber(model: Model,name: string,size: Vector3,pose: CFrame,stone: boolean): Part
    local p=Instance.new("Part")
    p.Name=name
    p.Size=size
    p.CFrame=pose
    p.Anchored=true
    p.CanCollide=false
    p.CanTouch=false
    p.Material=if stone then Enum.Material.Cobblestone else Enum.Material.WoodPlanks
    p.Color=if stone then Color3.fromRGB(121,121,110) else Color3.fromRGB(122,83,51)
    p.Parent=model
    return p
end

function Scene.sync(folder: Folder,bridge: any,crossing: any,buildSeconds: number)
    local key=bridge.typeId..":"..bridge.state..":"..math.floor(bridge.progress/buildSeconds*8)
    local model=folder:FindFirstChild(crossing.id)
    if model and model:GetAttribute("Appearance")==key then return end
    if model then model:Destroy() end
    local new=Instance.new("Model")
    new.Name=crossing.id
    new:SetAttribute("Appearance",key)
    local reinforced=bridge.typeId=="bridge_reinforced"
    local open=bridge.state=="complete" or bridge.state=="damaged"
    local pose,span=deckPose(crossing)
    local slices=math.ceil(span/6)
    local progress=if open then slices elseif bridge.state=="ruined" then 2
        else math.max(1,math.floor(slices*bridge.progress/buildSeconds))
    for index=1,progress do
        local x=-span/2+(index-0.5)*span/slices
        local plank=timber(new,"Tabuleiro",Vector3.new(span/slices+0.03,DECK_THICKNESS,DECK_WIDTH),
            pose*CFrame.new(x,0,0),false)
        plank.CanCollide=open and reinforced
        if not open then plank.Transparency=0.4 end
        if reinforced and index%3==1 then
            for _,side in ipairs({-1,1}) do
                timber(new,"Parapeito",Vector3.new(span/slices*3,0.34,0.34),
                    pose*CFrame.new(x+span/slices,1.25,side*3.05),true)
                timber(new,"Pilar",Vector3.new(0.52,3.1,0.55),pose*CFrame.new(x,0.45,side*3.05),true)
            end
        end
    end
    new.Parent=folder
end
return Scene
