-- Full world initialization path used by Boot, in a disposable Roblox server.
local function probeFullBridge(world,living,bridgeScene)
    local profile=loadCandidate("RegionalProfile")
    local slots=loadCandidate("SlotModel")
    local seed=516639272
    local crossing=loadCandidate("RegionalCrossings").compile(seed).crossings[3]
    local record=slots.newWorld(seed,100,{x=crossing.west.x-3,y=crossing.west.y+4,z=0})
    local domain=loadCandidate("LivingModel").new(seed)
    assert(loadCandidate("WorkEngine").initializeVillage(domain))
    record.living=domain
    local rig=Instance.new("Model")
    local root=Instance.new("Part")
    root.Name="HumanoidRootPart"
    root.Anchored=true
    root.Position=Vector3.new(crossing.west.x-3,crossing.west.y+4,0)
    root.Parent=rig
    Instance.new("Humanoid").Parent=rig
    rig.Parent=workspace
    local attributes={ER_WorldLoaded=true}
    local player={Character=rig,Parent=game:GetService("Players")}
    function player:GetAttribute(key) return attributes[key] end
    function player:SetAttribute(key,value) attributes[key]=value end
    assert(living.start(player,record))
    living.probeStep(0.04)
    living.probeStep(0.04)
    local village=assert(workspace:FindFirstChild("ER_LivingWorld"))
    local dock=assert(village.ER_Travel:FindFirstChild("Ancoradouro do Vale"))
    assert(village:FindFirstChild("Building_1_castle") and village:FindFirstChild("NPC_1_Ari"))
    local result=living.probeAction(player,"build_preview","bridge_light",crossing.west.x-3)
    assert(not result.ok and result.error=="solid_obstruction","v22 failure not reproduced: "..tostring(result.error))
    local thickness=0.7
    local span=Vector3.new(crossing.span,crossing.deckEastY-crossing.deckWestY,0).Magnitude
    local pose=CFrame.new((crossing.west.x+crossing.east.x)/2,(crossing.deckWestY+crossing.deckEastY)/2-thickness/2,0)
        *CFrame.Angles(0,0,math.atan2(crossing.deckEastY-crossing.deckWestY,crossing.span))
        *CFrame.new(0,3.5,0)
    local overlap=OverlapParams.new()
    overlap.RespectCanCollide=true
    overlap.FilterDescendantsInstances={workspace.Terrain,rig}
    local hits={}
    for _,part in ipairs(workspace:GetPartBoundsInBox(pose,Vector3.new(span,7+thickness,6.7),overlap)) do
        table.insert(hits,{path=part:GetFullName(),class=part.ClassName,collisionGroup=part.CollisionGroup,
            canCollide=part.CanCollide,canQuery=part.CanQuery,size={part.Size.X,part.Size.Y,part.Size.Z},
            position={part.Position.X,part.Position.Y,part.Position.Z},
            category=if part:IsDescendantOf(dock) then "dock" else "other"})
    end
    assert(#hits>0 and hits[1].category=="dock","dock intersection missing")
    living.stop(player)
    rig:Destroy()
    return {stage="preview",result=result.error,crossing=crossing.id,hits=hits,center={pose.X,pose.Y,pose.Z},
        size={span,7+thickness,6.7},villageParts=#village:GetDescendants()}
end
