-- Called by the T2-R1 engine probe in the disposable v18 runtime.
local function probeNewSave(first,second,main,backups,seed,player,worldKey,http,setBackupFault,loseNextReply)
    local Slots=loadCandidate("SlotModel")
    local Living=loadCandidate("LivingModel")
    local Regions=loadCandidate("RegionalWorld")
    local Profile=loadCandidate("RegionalProfile")
    local Work=loadCandidate("WorkEngine")
    local Inventory=loadCandidate("Inventory")

    local ok,before=first.open(player,1)
    assert(ok and before.rulesetVersion==3 and Slots.spawnPosition(before).x==411)
    assert(not second.open(player,1))
    local home=assert(Living.restore(before.living,seed))
    local regional=assert(Regions.new(seed,home,nil,Slots.spawnPosition(before)))
    local town=assert(Profile.settlement(seed,2))
    local city=Regions.activate(regional,town.x)
    for _=1,900 do Work.step(city,0.1) end
    assert((city.stats.stored or 0)>0)
    local storage=Inventory.weight(city.buildings[2].stored)
    local traveller=Instance.new("Model")
    local root=Instance.new("Part")
    root.Name="HumanoidRootPart"
    root.CFrame=CFrame.new(town.x,town.y+4,0)
    root.Parent=traveller
    Instance.new("Humanoid").Parent=traveller
    player.Character=traveller
    regional.record.mount={id="horse:1",position={x=town.x,y=town.y,z=0},health=85,energy=57}
    regional.record.rider="mount"
    first.setLivingProvider(function() return home,Regions.snapshot(regional) end)

    setBackupFault(true)
    local saved,reason=first.save(player,false)
    assert(not saved and reason=="backup_unavailable")
    assert(main:GetAsync(worldKey).rulesetVersion==3)
    setBackupFault(false)
    loseNextReply()
    saved,reason=first.save(player,false)
    assert(not saved and reason=="datastore_unavailable")
    assert(first.save(player,false))
    local checkpoint=backups:GetAsync(Slots.legacyBackupKey(before))
    assert(checkpoint and checkpoint.rulesetVersion==3 and checkpoint.regionWorld==nil)
    assert(first.save(player,true))
    local reopened,record=second.open(player,1)
    assert(reopened and record.rulesetVersion==4 and Slots.spawnPosition(record).x==town.x)
    assert(record.regionWorld.mount.energy==57 and record.regionWorld.rider=="mount")
    local restored=assert(Regions.new(seed,record.living,record.regionWorld,Slots.spawnPosition(record)))
    assert(Regions.activate(restored,town.x).npcs[1].id==city.npcs[1].id)
    assert(Inventory.weight(restored.record.foreign.buildings[2].stored)==storage)
    restored.record.rider=nil
    second.setLivingProvider(function() return restored.home,Regions.snapshot(restored) end)
    local destination=Profile.spawn(seed)
    loseNextReply()
    local travelled,travelError=second.save(player,false,destination)
    assert(not travelled and travelError=="datastore_unavailable")
    assert(second.save(player,false,destination))
    assert(Slots.spawnPosition(second.get(player)).x==0)
    root.CFrame=CFrame.new(destination.x,destination.y,0)
    assert(second.save(player,true))
    traveller:Destroy()
    return {migrated=true,backup=true,retry=true,foreignReopen=true,foreignStockMass=storage,
        mountState=true,travelCheckpoint=true,recordBytes=#http:JSONEncode(record)}
end

local function probeRegionalModels(BridgeScene,Rig,routes,seed)
    local folder=Instance.new("Folder")
    folder.Parent=workspace
    local Work=loadCandidate("WorkEngine")
    local Living=loadCandidate("LivingModel")
    local Regions=loadCandidate("RegionalWorld")
    local Profile=loadCandidate("RegionalProfile")
    local Inventory=loadCandidate("Inventory")
    local R3=loadCandidate("R3Engine")
    local session=assert(Regions.new(seed,Living.new(seed),nil,Profile.spawn(seed)))
    local graph=routes.compile(seed)
    local crossing=graph.crossings[3]
    local home=session.home
    home.npcs={home.npcs[3]}
    home.sites={}
    local worker=home.npcs[1]
    worker.x=crossing.west.x-3
    local store={id=1,typeId="stockpile",x=worker.x-6,y=17,
        state="complete",progress=30,health=150,delivered={},claimed={},stored=Inventory.new(250)}
    home.buildings={store}
    home.nextBuildingId=2
    assert(Inventory.add(store.stored,"wood",27) and Inventory.add(store.stored,"stone",12))
    local placed,bridge=Work.place(home,"bridge_reinforced",crossing.west.x+1)
    assert(placed)
    for _=1,8000 do
        Work.step(home,0.1)
        if bridge.state=="complete" then break end
    end
    assert(bridge.state=="complete" and bridge.delivered.wood==20 and bridge.delivered.stone==12)
    BridgeScene.sync(folder,bridge,crossing,48)
    local model=assert(folder:FindFirstChild(crossing.id))
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances={model}
    params.RespectCanCollide=true
    task.wait()
    assert(workspace:Raycast(Vector3.new(bridge.x,66,0),Vector3.new(0,-90,0),params))
    assert(Inventory.add(worker.inventory,"wood",2))
    for _=1,3000 do
        if Work.walkResident(home,worker,crossing.east.x+6,0.1,0) then break end
    end
    assert(worker.x>crossing.east.x and Inventory.count(worker.inventory,"wood")==2)
    assert(R3.damageStructure(home,bridge,300))
    BridgeScene.sync(folder,bridge,crossing,48)
    local ruined=folder:FindFirstChild(crossing.id)
    params.FilterDescendantsInstances={ruined}
    task.wait()
    assert(not workspace:Raycast(Vector3.new(bridge.x,66,0),Vector3.new(0,-90,0),params))
    assert(not Work.deckAt(home,bridge.x,0,"mount"))

    local horse=Rig.create("mount",folder)
    local boat=Rig.create("boat",folder)
    Rig.animate(horse,"mount",1.1,14)
    Rig.animate(boat,"boat",0.6,6)
    assert(#horse.gait==8 and #boat.gait==2)
    assert(horse.seat:IsA("Seat") and boat.seat:IsA("Seat"))
    folder:Destroy()
    return {built=true,workDelivered=true,workerCrossed=true,destroyed=true,horseJoints=8,boatOars=2}
end
