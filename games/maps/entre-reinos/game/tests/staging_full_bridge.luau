-- Full world initialization path used by Boot, in a disposable Roblox server.
local function probeFullBridge(world,living,bridgeScene)
    local profile=loadCandidate("RegionalProfile")
    local slots=loadCandidate("SlotModel")
    local seed=516639272
    local crossing=loadCandidate("RegionalCrossings").compile(seed).crossings[3]
    local record=slots.newWorld(seed,100,{x=crossing.west.x-3,y=crossing.west.y+4,z=0})
    local domain=loadCandidate("LivingModel").new(seed)
    assert(loadCandidate("WorkEngine").initializeVillage(domain))
    local inventory=loadCandidate("Inventory")
    assert(inventory.add(domain.buildings[2].stored,"wood",44))
    assert(inventory.add(domain.buildings[2].stored,"stone",16))
    local savedTree=domain.sites[1]
    savedTree.z=2
    savedTree.remaining=17
    savedTree.marked=true
    domain.npcs[3].x=crossing.west.x-4
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
    local resourceTree=assert(village:FindFirstChild("HarvestableTree_wood_a"))
    local trunk=resourceTree:FindFirstChild("Trunk")
    local foliage=false
    for _,part in ipairs(resourceTree:GetChildren()) do
        if part:IsA("MeshPart") then
            local cf,sz=part.CFrame,part.Size
            local front=cf.Z+(math.abs(cf.RightVector.Z)*sz.X+math.abs(cf.UpVector.Z)*sz.Y
                +math.abs(cf.LookVector.Z)*sz.Z)/2
            assert(front<=-1+0.01,"resource tree leaks onto the camera side")
            foliage=true
        end
    end
    assert(foliage and trunk.Position.Z==savedTree.z and trunk:GetAttribute("SourceId")==savedTree.id)
    local savedPopulation=living.snapshot(player)
    assert(savedPopulation.sites[1].z==2 and savedPopulation.sites[1].remaining==17 and savedPopulation.sites[1].marked)
    local parts=#village:GetDescendants()
    local clearance=loadCandidate("StructureDefs").BRIDGE_DECK_WIDTH/2
    for _,landing in ipairs(village.ER_Travel:GetChildren()) do
        if landing:GetAttribute("ER_PlacementRole")~="dock" then continue end
        local deck=landing:FindFirstChild("Píer")
        assert(deck and deck.CanCollide and deck.Position.Z+deck.Size.Z/2 < -clearance)
    end
    local approach=crossing.west.x-3
    local preview=living.probeAction(player,"build_preview","bridge_light",approach)
    assert(preview.ok and preview.bridge.id==crossing.id, tostring(preview.error))
    local center=(crossing.west.x+crossing.east.x)/2
    local blocker=Instance.new("Part")
    blocker.Name="FixedBridgeObstruction"
    blocker.Size=Vector3.new(2,2,2)
    blocker.Anchored=true
    blocker.Position=Vector3.new(center,preview.y+2,0)
    blocker.Parent=workspace
    local rejected=living.probeAction(player,"build",preview.previewId)
    assert(not rejected.ok and rejected.error=="solid_obstruction")
    local clear,code,details=bridgeScene.validatePlacement(crossing,{workspace.Terrain,rig})
    assert(not clear and code=="solid_obstruction" and details.parts[1].path==blocker:GetFullName())
    blocker:Destroy()
    task.wait(0.67)

    -- A physically solid moving resident is classified separately.
    local subject=village.NPC_1_Ari:Clone()
    subject.Name="ResidentCrossing"
    subject.Parent=workspace
    subject:PivotTo(CFrame.new(center,preview.y+2,0))
    local torso=subject:FindFirstChild("Torso")
    torso.CollisionGroup="Default"
    torso.CanCollide=true
    assert(bridgeScene.validatePlacement(crossing,{workspace.Terrain,rig}))
    subject:Destroy()
    local function finish(tier)
        local draft=living.probeAction(player,"build_preview",tier,approach)
        assert(draft.ok and draft.bridge.id==crossing.id, tostring(draft.error))
        local ordered=living.probeAction(player,"build",draft.previewId)
        assert(ordered.ok and ordered.x==center,tostring(ordered.error))
        for tick=1,5000 do
            living.probeStep(0.1)
            if tick%25==0 then
                local live=living.snapshot(player)
                for _,b in ipairs(live.buildings) do
                    if b.id==ordered.buildingId and b.state=="complete" then
                        return b,tick
                    end
                end
            end
        end
        error("deliveries or work did not finish for "..tier)
    end
    local light,lightTicks=finish("bridge_light")
    assert(light.delivered.wood==12)
    local physical=RaycastParams.new()
    physical.FilterType=Enum.RaycastFilterType.Include
    physical.RespectCanCollide=true
    local function deckAt()
        physical.FilterDescendantsInstances={village.ER_Bridges[crossing.id]}
        return workspace:Raycast(Vector3.new(center,70,0),Vector3.new(0,-120,0),physical)
    end
    assert(not deckAt(),"light bridge blocked the player")
    task.wait(0.67)
    local reinforced,reinforcedTicks=finish("bridge_reinforced")
    assert(reinforced.id==light.id and reinforced.delivered.wood==20 and reinforced.delivered.stone==12)
    assert(deckAt(),"reinforced bridge lacks physical deck")
    local live,region=living.snapshot(player)
    local save=slots.newWorld(seed,100,profile.spawn(seed))
    save.living=live
    save.regionWorld=region
    save.rulesetVersion=5
    assert(slots.validWorld(save) and slots.COUNT==6)
    local dockZ=dock["Píer"].Position.Z
    living.stop(player)
    rig:Destroy()
    return {result="built_both",crossing=crossing.id,blocker=details.parts[1],
        reviewVolume=details.volume,villageParts=parts,lightTicks=lightTicks,reinforcedTicks=reinforcedTicks,
        dockZ=dockZ,foregroundSourcePreserved=true}
end
