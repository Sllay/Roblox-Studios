-- Server-owned resource physics; living avatars alone bypass small resources.
-- Runtime changes only. The future environment writer must persist the same policy.
local W=workspace
local Players=game:GetService("Players")
local Physics=game:GetService("PhysicsService")
local PLAYER="RSPlayerBody"
local RESOURCE="RSNaturalResource"
local function configure(world)
    -- Prefer current per-world API; retain the supported legacy Workspace adapter
    -- only if this engine context does not expose it.
    local ok=pcall(function() return world:GetRegisteredCollisionGroups() end)
    local api=if ok then world else Physics
    for _,name in {PLAYER,RESOURCE} do
        if not api:IsCollisionGroupRegistered(name) then api:RegisterCollisionGroup(name) end
    end
    for _,g in api:GetRegisteredCollisionGroups() do
        local name=g.name
        if name~=PLAYER and name~=RESOURCE then
            api:CollisionGroupSetCollidable(PLAYER,name,api:CollisionGroupsAreCollidable("Default",name))
            api:CollisionGroupSetCollidable(RESOURCE,name,true)
        end
    end
    api:CollisionGroupSetCollidable(PLAYER,PLAYER,api:CollisionGroupsAreCollidable("Default","Default"))
    api:CollisionGroupSetCollidable(PLAYER,RESOURCE,false)
    api:CollisionGroupSetCollidable(RESOURCE,RESOURCE,true)
    assert(api:CollisionGroupsAreCollidable(PLAYER,"Default"),"Player world collision")
    assert(api:CollisionGroupsAreCollidable(RESOURCE,world.Terrain.CollisionGroup),"Resource terrain collision")
    assert(not api:CollisionGroupsAreCollidable(PLAYER,RESOURCE),"Resource player filter")
    return api,if ok then "WorldRoot" else "PhysicsService"
end
local function applyResources(world)
    local root=world:FindFirstChild("RSResourcesP45")
    assert(root and root:GetAttribute("RSOwner")=="RSResourcesP45V1","Managed resource root")
    local models=root:FindFirstChild("Models")
    assert(models,"Resource models")
    local stone,stick,large=0,0,0
    for _,m in models:GetChildren() do
        if not m:IsA("Model") then continue end
        local kind=m:GetAttribute("RSResourceType")
        assert(kind=="Stone" or kind=="Stick","Unknown resource type")
        local part=m:FindFirstChildWhichIsA("MeshPart",true)
        assert(part and m:GetAttribute("RSResourceState")=="decorative","Resource geometry")
        -- Do not force anchoring here: dynamic resources may later use this group.
        part.CollisionGroup=RESOURCE;part.CanCollide=true;part.CanQuery=true
        if kind=="Stone" then stone+=1 else stick+=1 end
    end
    local detail=world:FindFirstChild("RSEnvironmentP4Detail")
    local props=detail and detail:FindFirstChild("Models")
    assert(props,"Detail models")
    for _,m in props:GetChildren() do
        if not m:IsA("Model") or m:GetAttribute("RSSpecies")~="Mossy_Rock1_M_Mossy_Rock_0_Node" then continue end
        for _,part in m:GetDescendants() do
            if part:IsA("MeshPart") then
                part.CollisionGroup="Default";part.CanCollide=true;part.CanQuery=true
            end
        end
        large+=1
    end
    return stone,stick,large
end
-- __RS_RESOURCE_RUNTIME__
if game.PlaceId~=93428341652658 then return end
local api,backend=configure(W)
local stone,stick,large=applyResources(W)
local function watch(character)
    local function assign(part)
        if not part:IsA("BasePart") then return end
        local hum=character:FindFirstChildOfClass("Humanoid")
        -- Never override the dedicated corpse group or ragdoll's proxies.
        if not hum or hum.Health<=0 or part.CollisionGroup=="RSDeadBody" then return end
        if part.CollisionGroup=="Default" then part.CollisionGroup=PLAYER end
    end
    character.DescendantAdded:Connect(function(part)
        if part:IsA("Humanoid") then
            for _,v in character:GetDescendants() do assign(v) end
        else assign(part) end
    end)
    for _,part in character:GetDescendants() do assign(part) end
end
local function onPlayer(p)
    p.CharacterAdded:Connect(watch)
    if p.Character then watch(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _,p in Players:GetPlayers() do onPlayer(p) end
local root=W:FindFirstChild("RSResourcesP45")
root:SetAttribute("RSPhysicsBackend",backend)
root:SetAttribute("RSPhysicsStoneCount",stone)
root:SetAttribute("RSPhysicsStickCount",stick)
root:SetAttribute("RSPhysicsLargeRockCount",large)
root:SetAttribute("RSPhysicsMatrixOK",not api:CollisionGroupsAreCollidable(PLAYER,RESOURCE) and api:CollisionGroupsAreCollidable(RESOURCE,RESOURCE) and api:CollisionGroupsAreCollidable(RESOURCE,W.Terrain.CollisionGroup))
