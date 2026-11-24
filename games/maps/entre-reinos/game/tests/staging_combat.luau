-- Executed after native Terrain generation by the isolated engine probe.
local function probeCombat(seed,combat)
    local model=Instance.new("Model")
    local root=Instance.new("Part")
    root.Name="HumanoidRootPart"
    root.Anchored=true
    root.CFrame=CFrame.new(-4,20,0)*CFrame.Angles(0,-math.pi/2,0)
    root.Parent=model
    Instance.new("Humanoid").Parent=model
    model.Parent=workspace

    local values={}
    local testPlayer={Character=model,SetAttribute=function(_,key,value) values[key]=value end}
    local folder=Instance.new("Folder")
    folder.Name="CombatProbe"
    folder.Parent=workspace
    local core=loadCandidate("R3Engine")
    local state=loadCandidate("LivingModel").new(seed)
    local story=core.ensure(state,true)
    combat.start(testPlayer,state,folder)
    assert(folder:FindFirstChild("Story_duke"),"duke preview has no physical actor")
    local order=combat.action(testPlayer,"prologue","training")
    assert(order.ok and story.prologue.stage=="escort")
    core.step(state,0.2,-4)
    combat.present()
    local duke=folder:FindFirstChild("Story_duke")
    assert(duke and duke:GetAttribute("ER_NPCPose").X< -4)
    local human=duke:FindFirstChildOfClass("Humanoid")
    assert(human and human.RigType==Enum.HumanoidRigType.R6 and human:FindFirstChildOfClass("Animator"))
    assert(duke:FindFirstChild("Torso"):FindFirstChild("Left Hip") and duke:FindFirstChild("GuardBlade"),
        "story actor is missing the native joints or equipment")

    -- Independent scenario using the server's real combat entry point.
    local sandbox=loadCandidate("LivingModel").new(seed)
    local d=core.ensure(sandbox,false)
    assert(core.spawnWave(sandbox,1))
    d.enemies[1].x=0
    d.enemies[2].x=18
    combat.start(testPlayer,sandbox,folder)
    local strike=combat.action(testPlayer,"attack",nil)
    assert(strike.ok and strike.hit and d.enemies[1].hp==14)
    assert(values.ER_PlayerAttack)
    local duplicate=combat.action(testPlayer,"attack",nil)
    assert(not duplicate.ok and duplicate.error=="rate_limited" and d.enemies[1].hp==14)
    assert(core.damageEnemy(sandbox,d.enemies[1].id,14))
    assert(combat.fireResident({x=2},d.enemies[1]))
    assert(d.enemies[1].hp==30,"damage happened before the projectile arrived")
    for _=1,19 do combat.tick(0.05) end
    assert(d.enemies[1].hp==20,"native projectile missed or damaged the wrong target")
    combat.stop()
    model:Destroy()
    folder:Destroy()
    return {actor=true,escort=true,articulated=true,melee=true,cooldown=true,nativeArrow=true}
end
