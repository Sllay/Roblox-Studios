-- Real engine objects, synthetic player identity and explicit input pump.
local function probeTravel(Travel,BridgeScene,seed)
    local Profile=loadCandidate("RegionalProfile")
    local Regions=loadCandidate("RegionalWorld")
    local Living=loadCandidate("LivingModel")
    local Inventory=loadCandidate("Inventory")
    local R3=loadCandidate("R3Engine")
    local Work=loadCandidate("WorkEngine")
    local Structures=loadCandidate("StructureDefs")
    local home=Living.new(seed)
    R3.ensure(home,false)
    home.r3.wallet=12
    assert(Inventory.add(home.r3.playerBag,"wood",3))
    local session=assert(Regions.new(seed,home,nil,Profile.spawn(seed)))
    session.record.discovered["2"]=true
    local folder=Instance.new("Folder")
    folder.Parent=workspace
    local players=game:GetService("Players")
    local description=Instance.new("HumanoidDescription")
    local model=players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R6)
    description:Destroy()
    local root=model:FindFirstChild("HumanoidRootPart")
    local human=model:FindFirstChildOfClass("Humanoid")
    model.Parent=workspace
    local player={Character=model,attributes={}}
    function player:SetAttribute(key,value) self.attributes[key]=value end
    local function place(x,y)
        model:PivotTo(CFrame.new(x,y,0))
        root.AssemblyLinearVelocity=Vector3.zero
    end
    place(18,Profile.sample(seed,18,0).height+3.5)
    local writes=0
    Travel.start(player,session,folder,function(_,position)
        writes+=1
        if writes==1 then return false,"save_busy" end
        session.record.position=position
        return true
    end)
    assert(session.record.boat and session.record.boat.cargo.maxMass==36)
    assert(not Travel.steer(player,1))
    assert(not Travel.action({}, "buy_mount").ok)
    assert(Travel.action(player,"buy_mount").ok)
    assert(home.r3.wallet==0 and session.record.mount.id=="horse:1")
    task.wait(0.52)
    assert(Travel.action(player,"mount").ok)
    task.wait(0.15)
    local horseSeat=human.SeatPart
    assert(horseSeat and horseSeat.Occupant==human,"engine did not create horse seat weld")
    assert(not Travel.steer({},1) and not Travel.steer(player,math.huge))
    local function drive(ticks,target,vehicle)
        local accepted=0
        for index=1,ticks do
            if Travel.steer(player,1) then accepted+=1 end
            Travel.tick(0.1)
            task.wait(0.065)
            assert(player.attributes.ER_Riding==vehicle,
                string.format("rider lost: vehicle=%s target=%.2f tick=%d position=%.2f rider=%s seat=%s sit=%s",
                    vehicle,target,index,session.record[vehicle].position.x,tostring(root.Position),
                    tostring(human.SeatPart),tostring(human.Sit)))
            if session.record[vehicle].position.x>=target then break end
        end
        assert(accepted>0,"server rejected every steering input for "..vehicle)
    end
    drive(12,35,"mount")
    assert(session.record.mount.position.x>20 and session.record.mount.energy<100)
    assert(math.abs(root.Position.X-session.record.mount.position.x)<2,
        "saddle moved without the rider")
    local crossing=session.graph.crossings[3]
    drive(30,crossing.east.x+7,"mount")
    assert(session.record.mount.position.x<=crossing.west.x+0.1,
        "horse passed the supported entrance without a reinforced deck")
    local built,bridge=Work.place(home,"bridge_reinforced",crossing.west.x+1)
    assert(built)
    local def=Structures.get("bridge_reinforced")
    -- Construction and payment are exercised by probeRegionalModels.
    bridge.progress,bridge.state,bridge.delivered=def.buildSeconds,"complete",table.clone(def.cost)
    BridgeScene.sync(folder,bridge,crossing,def.buildSeconds)
    drive(90,crossing.east.x+6,"mount")
    assert(session.record.mount.position.x>crossing.east.x and root.Position.X>crossing.east.x,
        string.format("reinforced bridge failed to carry the horse and rider: mount=(%.2f, %.2f) rider=%s east=%.2f",
            session.record.mount.position.x, session.record.mount.position.y, tostring(root.Position),crossing.east.x))
    assert(Travel.action(player,"dismount").ok)
    assert(R3.damageStructure(home,bridge,300))
    BridgeScene.sync(folder,bridge,crossing,def.buildSeconds)
    task.wait(0.52)

    local edge=529
    local elevation=Profile.sample(seed,edge,0).height
    session.record.mount.position={x=edge,y=elevation,z=0}
    place(edge,elevation+4)
    local remount=Travel.action(player,"mount")
    assert(remount.ok, "could not remount at regional boundary: "..tostring(remount.error))
    task.wait(0.15)
    drive(90,560,"mount")
    assert(Profile.regionAt(root.Position.X)==1,
        "mounted rider failed to traverse the legacy region boundary")
    assert(Travel.action(player,"dismount").ok)
    task.wait(0.52)

    local boat=session.record.boat
    local original=table.clone(boat.position)
    place(original.x,original.y+4)
    assert(Travel.cargo(player,"load").ok)
    assert(Inventory.count(boat.cargo,"wood")==1 and Inventory.count(home.r3.playerBag,"wood")==2)
    task.wait(0.52)
    assert(Travel.action(player,"board").ok)
    task.wait(0.15)
    assert(human.SeatPart and human.SeatPart~=horseSeat and human.SeatPart.Occupant==human)
    local waterline=assert(session.graph.crossings[3]).east.x
    drive(90,waterline,"boat")
    assert(boat.position.x>original.x+15)
    assert(Travel.action(player,"disembark").ok)
    assert(Inventory.count(boat.cargo,"wood")==1)
    task.wait(0.52)
    place(0,Profile.sample(seed,0,0).height+4)
    local denied=Travel.action(player,"travel")
    assert(not denied.ok and denied.error=="save_busy" and math.abs(root.Position.X)<2,
        string.format("failed fast travel changed state: ok=%s error=%s x=%s seat=%s writes=%d",
            tostring(denied.ok),tostring(denied.error),tostring(root.Position.X),
            tostring(human.SeatPart),writes))
    task.wait(0.52)
    local arrived=Travel.action(player,"travel")
    assert(arrived.ok and root.Position.X>1100 and writes==2,
        string.format("fast travel rejected: error=%s x=%s writes=%d",tostring(arrived.error),
            tostring(root.Position.X),writes))
    task.wait(0.52)
    place(boat.position.x,boat.position.y+4)
    assert(Travel.action(player,"board").ok)
    local boatSeat=assert(human.SeatPart)
    local cargoBefore=Inventory.count(boat.cargo,"wood")
    assert(boatSeat:FindFirstChild("SeatWeld") and session.record.rider=="boat")
    human.Health=0
    Travel.playerDied(player)
    assert(not boatSeat:FindFirstChild("SeatWeld") and not player.attributes.ER_Riding)
    assert(session.record.rider==nil and Inventory.count(boat.cargo,"wood")==cargoBefore)
    Travel.stop()
    model:Destroy()
    folder:Destroy()
    return {movedHorse=true,deepWaterBlocked=true,mountedBridge=true,regionalRide=true,sailed=true,cargo=true,failedTravelRecovered=true,authorizedSteering=true,deathDetachesRider=true}
end
