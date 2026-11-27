-- Native regressions in an unsaved Open Cloud server with candidate Terrain.
local function probeWaterBridge(world,profile,routes,scene)
    local seed=516639272
    local graph=routes.compile(seed)
    local terrain=workspace.Terrain
    local wet=RaycastParams.new()
    wet.FilterType=Enum.RaycastFilterType.Include
    wet.FilterDescendantsInstances={terrain}
    local dry=RaycastParams.new()
    dry.FilterType=Enum.RaycastFilterType.Include
    dry.FilterDescendantsInstances={terrain}
    dry.IgnoreWater=true

    local function cast(x,z,params)
        return workspace:Raycast(Vector3.new(x,142,z),Vector3.new(0,-174,0),params)
    end
    local riverX=76
    local checkedWater=0
    local previous=math.huge
    for z=-230,106,4 do
        local surface=cast(riverX,z,wet)
        local bed=cast(riverX,z,dry)
        assert(surface and surface.Material==Enum.Material.Water and bed and bed.Position.Y<surface.Position.Y,
            "river lost a native water column at Z "..z)
        assert(surface.Position.Y<=previous+0.4,"native river climbs in the flow direction at Z "..z)
        previous=surface.Position.Y
        checkedWater+=1
    end
    local seamTests=0
    for _,edge in ipairs({-176,-112,-48,48}) do
        local a,b=cast(riverX,edge-0.08,wet),cast(riverX,edge+0.08,wet)
        assert(a and b and a.Material==b.Material and math.abs(a.Position.Y-b.Position.Y)<0.4)
        seamTests+=1
    end
    for _,edge in ipairs({-96,-32,32,96}) do
        local a,b=cast(edge-0.08,94,wet),cast(edge+0.08,94,wet)
        assert(a and b and a.Material==Enum.Material.Water and b.Material==Enum.Material.Water
            and math.abs(a.Position.Y-b.Position.Y)<0.1,"foreground line at X "..edge)
        seamTests+=1
    end
    assert(not workspace.ER_World_3D:FindFirstChild("WaterSheet",true))
    assert(not workspace.ER_World_3D:FindFirstChild("FeederCascade",true))

    local readyBanks=0
    for _,crossing in ipairs(graph.crossings) do
        if not crossing.buildable then continue end
        for _,side in ipairs({"west","east"}) do
            local bank=crossing[side]
            assert(world.ensureNear(seed,bank.x))
            local approach=bank.x+(if side=="west" then -2 else 2)
            assert(routes.bridgePlan(graph,approach,36)==crossing)
            readyBanks+=1
        end
        assert(scene.validatePlacement(crossing,{terrain}))
    end
    local crossing=graph.crossings[3]
    local center=(crossing.west.x+crossing.east.x)/2
    local height=(crossing.deckWestY+crossing.deckEastY)/2
    local blocker=Instance.new("Part")
    blocker.Anchored=true
    blocker.CanCollide=false
    blocker.Size=Vector3.new(2,3,2)
    blocker.Position=Vector3.new(center,height+1.5,0)
    blocker.Parent=workspace
    -- A decorative object is harmless even if it overlaps the bridge query.
    assert(scene.validatePlacement(crossing,{terrain}))
    blocker.CanCollide=true
    local clear,reason=scene.validatePlacement(crossing,{terrain})
    assert(not clear and reason=="solid_obstruction","confirmation accepted an obstacle after preview")
    blocker:Destroy()
    assert(scene.validatePlacement(crossing,{terrain}),"removing the obstruction should restore placement")

    local Work=loadCandidate("WorkEngine")
    local Living=loadCandidate("LivingModel")
    local Regions=loadCandidate("RegionalWorld")
    local Inventory=loadCandidate("Inventory")
    local Slots=loadCandidate("SlotModel")
    local Production=loadCandidate("Production")
    local home=Living.new(seed)
    home.npcs={home.npcs[3]}
    home.sites={}
    local worker=home.npcs[1]
    worker.x=crossing.west.x-5
    worker.z=-4.4
    local store={id=1,typeId="stockpile",x=worker.x-4,y=17,state="complete",progress=30,
        health=150,delivered={},claimed={},stored=Inventory.new(250)}
    home.buildings={store}
    home.nextBuildingId=2
    local region=assert(Regions.new(seed,home,nil,profile.spawn(seed),world.isLoadedAt))
    assert(Inventory.add(store.stored,"wood",44) and Inventory.add(store.stored,"stone",16))
    Production.ensure(home)
    local folder=Instance.new("Folder")
    folder.Parent=workspace
    local buildTicks=0
    local work
    for _,tier in ipairs({"bridge_light","bridge_reinforced"}) do
        local snapped=assert(Work.bridgePlan(home,crossing.west.x-2,36))
        assert(snapped.id==crossing.id)
        local existing=folder:FindFirstChild(crossing.id)
        local exempt=if existing then {terrain,existing} else {terrain}
        assert(Work.canPlace(home,tier,center) and scene.validatePlacement(snapped,exempt))
        local placed
        placed,work=Work.place(home,tier,center,height)
        assert(placed and work.state=="blueprint" and work.x==center and work.crossingId==crossing.id)
        local def=loadCandidate("StructureDefs").get(tier)
        scene.sync(folder,work,crossing,def.buildSeconds)
        assert(folder:FindFirstChild(crossing.id))
        assert(not Work.deckAt(home,center,0,"mount"))
        for _=1,6000 do
            Work.step(home,0.1)
            buildTicks+=1
            if work.state=="complete" then break end
        end
        assert(work.state=="complete","workers failed to finish "..tier)
        assert(Work.deckAt(home,center,0,"worker"))
        scene.sync(folder,work,crossing,def.buildSeconds)
        local model=folder:FindFirstChild(crossing.id)
        local deckRay=RaycastParams.new()
        deckRay.FilterType=Enum.RaycastFilterType.Include
        deckRay.FilterDescendantsInstances={model}
        deckRay.RespectCanCollide=true
        local physical=cast(center,0,deckRay)
        if tier=="bridge_light" then
            assert(not physical and not Work.deckAt(home,center,0,"mount"))
        else
            assert(physical and Work.deckAt(home,center,0,"mount"))
        end
    end
    local rider={x=crossing.west.x-5,y=profile.sample(seed,crossing.west.x-5,0).height,z=0}
    local destination=crossing.east.x+5
    for _=1,90 do
        local x,y=Work.mountStep(home,rider,math.min(rider.x+2.6,destination))
        assert(x and y and x>rider.x)
        rider={x=x,y=y,z=0}
        if x==destination then break end
    end
    assert(rider.x==destination)
    local save=Slots.newWorld(seed,100,profile.spawn(seed))
    save.rulesetVersion=5
    save.living=home
    save.regionWorld=Regions.snapshot(region)
    assert(Slots.validWorld(save) and Slots.COUNT==6)
    assert(Regions.new(seed,assert(Living.restore(home,seed)),save.regionWorld,profile.spawn(seed)))
    folder:Destroy()
    return {nativeWaterColumns=checkedWater,seams=seamTests,readyBanks=readyBanks,
        solidOnlyObstruction=true,lightBuilt=true,reinforcedBuilt=true,mountedRoute=true,
        ticks=buildTicks,stableCrossingId=crossing.id,ruleset=save.rulesetVersion}
end
