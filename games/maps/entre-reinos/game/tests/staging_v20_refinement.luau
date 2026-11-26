-- Native probe in an unsaved Open Cloud session, using the candidate modules.
local function probeRefinement(world,profile,scenery,combat,living,r3)
    local seed=516639272
    local memoryBefore=gcinfo()
    assert(world.activate(seed,nil,profile))
    local start=world.metrics()
    assert(start.chunks==5)
    local terrain=workspace.Terrain
    local b=profile.BOUNDS
    local original=Region3.new(Vector3.new(32,b.yMin,b.zMin),Vector3.new(96,b.yMax,b.zMax))
    local channels={"SolidOccupancy","LiquidOccupancy","SolidMaterial"}
    local legacy=terrain:ReadVoxelChannels(original,4,channels)
    local begin=os.clock()
    assert(world.prefetch(seed,0,0,true))
    local startupMS=(os.clock()-begin)*1000
    local around=world.metrics()
    assert(around.sceneryVolumes>20 and around.chunks<profile.CHUNK_COUNT)
    local same=terrain:ReadVoxelChannels(original,4,channels)
    local checked=0
    for ix,ys in ipairs(legacy.SolidOccupancy) do
        for iy,zs in ipairs(ys) do
            for iz,occupancy in ipairs(zs) do
                assert(occupancy==same.SolidOccupancy[ix][iy][iz])
                assert(legacy.LiquidOccupancy[ix][iy][iz]==same.LiquidOccupancy[ix][iy][iz])
                assert(legacy.SolidMaterial[ix][iy][iz]==same.SolidMaterial[ix][iy][iz])
                checked+=1
            end
        end
    end
    local geometry=RaycastParams.new()
    geometry.FilterType=Enum.RaycastFilterType.Include
    geometry.FilterDescendantsInstances={terrain}
    local water=workspace:Raycast(Vector3.new(0,100,94),Vector3.new(0,-130,0),geometry)
    assert(water and water.Material==Enum.Material.Water,"foreground has no native water")
    local hill=workspace:Raycast(Vector3.new(0,142,-226),Vector3.new(0,-170,0),geometry)
    assert(hill and hill.Position.Y>50,"back row is missing elevated native Terrain")
    for _,side in ipairs({1,-1}) do
        assert(world.prefetch(seed,side*profile.PLAY_EDGE,side*24,true))
        local edge=side*(profile.CHUNK_RADIUS+scenery.EDGE_CHUNKS)
        local outer=scenery.bounds(edge,0)
        local hit=workspace:Raycast(Vector3.new((outer.xMin+outer.xMax)/2,142,0),Vector3.new(0,-170,0),geometry)
        assert(hit and not world.isLoadedAt(hit.Position.X),"decorative edge must exist outside playable regions")
        local wall=workspace.ER_World_3D["RegionEdge_"..side]
        assert(wall and wall.CanCollide and wall.Transparency==1)
    end
    local state=living.new(seed)
    r3.ensure(state,true)
    local folder=Instance.new("Folder")
    folder.Parent=workspace
    combat.start(nil,state,folder)
    local duke=assert(folder:FindFirstChild("Story_duke"))
    local avatar=Instance.new("Part")
    avatar.Anchored=true
    avatar.Position=Vector3.new(0,155,0)
    avatar.Parent=folder
    local ghostParts=0
    for _,part in ipairs(duke:GetDescendants()) do
        if part:IsA("BasePart") then
            assert(part.CollisionGroup=="ER_StoryAndEnemies" and not part:CanCollideWith(avatar),
                part.Name.." collided with the player collision group")
            ghostParts+=1
        end
    end
    avatar:Destroy()
    state.r3.prologue.stage="hesitation"
    combat.present()
    assert(math.abs(folder.Story_guard_one:GetAttribute("ER_NPCFacing")-math.pi/2)<1e-5)
    assert(folder.Story_guard_one:GetAttribute("ER_NPCActivity")=="stagger")
    state.r3.enemies={{id=900,x=16,hp=24,side=-1,attackClock=0}}
    combat.present()
    local pose=assert(folder.Raider_900:GetAttribute("ER_NPCPose"))
    local startPoint=pose+Vector3.new(-11,0,0)
    local endPoint=pose+Vector3.new(11,0,0)
    assert(combat.trace(startPoint,endPoint)==900,"fast shot missed R6 torso")
    assert(combat.trace(startPoint+Vector3.new(0,1.4,0),endPoint+Vector3.new(0,1.4,0))==900,"shot missed R6 head")
    assert(combat.trace(startPoint+Vector3.new(0,0,3),endPoint+Vector3.new(0,0,3))==nil,"empty lane counted as hit")
    local wall=Instance.new("Part")
    wall.Anchored=true
    wall.Size=Vector3.new(1,8,8)
    wall.Position=pose+Vector3.new(-6,0,0)
    wall.Parent=folder
    local target,alpha=combat.trace(startPoint,endPoint)
    assert(not target and alpha<0.45,"wall failed to stop hit before body")
    combat.stop()
    folder:Destroy()
    return {nativeLegacyUnchanged=checked,scenery=around,fullMetrics=world.metrics(),
        startupMS=startupMS,luauHeapBeforeKB=memoryBefore,luauHeapAfterKB=gcinfo(),ghostParts=ghostParts,
        nativeWater=true,physicalOcclusion=true}
end
