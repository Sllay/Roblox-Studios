-- P4 staging gameplay quality harness. Server owns spawn and live recovery.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local W=workspace
local root=W:WaitForChild("RSCentralSpawns")
local rng=Random.new()
Players.CharacterAutoLoads=false
local terrainParams=RaycastParams.new()
terrainParams.FilterType=Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances={W.Terrain}
terrainParams.IgnoreWater=false
local overlap=OverlapParams.new()
overlap.FilterType=Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances={W.Terrain,root}
overlap.RespectCanCollide=true
overlap.MaxParts=8
local function ground(x,z,top)
    local hit=W:Raycast(Vector3.new(x,top,z),Vector3.new(0,-220,0),terrainParams)
    if not hit or hit.Material==Enum.Material.Water then return nil end
    return hit
end
local function valid(s)
    if not s:IsA("SpawnLocation") or not s.Enabled then return false end
    local p=s.Position
    if p.X*p.X+p.Z*p.Z>108*108 then return false end
    local h=ground(p.X,p.Z,p.Y+12)
    if not h or h.Normal.Y<0.92 or math.abs(h.Position.Y-(p.Y-2))>3 then return false end
    for _,o in {{3,0},{-3,0},{0,3},{0,-3}} do
        local q=ground(p.X+o[1],p.Z+o[2],p.Y+12)
        if not q or q.Normal.Y<0.88 or math.abs(q.Position.Y-h.Position.Y)>1.8 then return false end
    end
    local box=CFrame.new(p.X,h.Position.Y+3.5,p.Z)
    if #W:GetPartBoundsInBox(box,Vector3.new(4,6,4),overlap)>0 then return false end
    return true,h.Position.Y
end
local function choose(previous)
    local pool={}
    for _,s in root:GetChildren() do
        if s~=previous and valid(s) then table.insert(pool,s) end
    end
    if #pool==0 and previous and valid(previous) then table.insert(pool,previous) end
    root:SetAttribute("RSValidSpawnCount",#pool)
    if #pool==0 then return nil end
    return pool[rng:NextInteger(1,#pool)]
end
local function alive(character)
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health>0 and hum:GetState()~=Enum.HumanoidStateType.Dead
end
local function recover(player,character)
    -- Never move a dead character or its root. Native death proceeds normally.
    if player.Character~=character or not alive(character) then return end
    local s=choose(player.RespawnLocation)
    if not s then player:SetAttribute("RSRecoveryStatus","no_safe_spawn");return end
    local ok,y=valid(s)
    if not ok then return end
    character:PivotTo(CFrame.new(s.Position.X,y+5,s.Position.Z))
    local hrp=character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.AssemblyLinearVelocity=Vector3.zero;hrp.AssemblyAngularVelocity=Vector3.zero end
    player:SetAttribute("RSRecoveryStatus","recovered_alive")
end
local loading={}
local function spawn(player)
    if loading[player] or player.Parent~=Players then return end
    loading[player]=true
    local s=choose(player.RespawnLocation)
    if not s then
        player:SetAttribute("RSSpawnStatus","no_safe_spawn")
        loading[player]=nil
        task.delay(2,function() if player.Parent==Players and not alive(player.Character) then spawn(player) end end)
        return
    end
    player.RespawnLocation=s
    player:SetAttribute("RSSpawnStatus","validated")
    player:SetAttribute("RSSpawnPoint",s.Name)
    player:SetAttribute("RSSpawnX",s.Position.X)
    player:SetAttribute("RSSpawnZ",s.Position.Z)
    local ok,err=pcall(function() player:LoadCharacterAsync() end)
    loading[player]=nil
    if not ok and player.Parent==Players then
        warn("RS spawn load failed",err);player:SetAttribute("RSSpawnStatus","load_failed")
        task.delay(3,function() if player.Parent==Players and not alive(player.Character) then spawn(player) end end)
    end
end
local function onCharacter(player,character)
    local hum=character:WaitForChild("Humanoid",10)
    if not hum then player:SetAttribute("RSSpawnStatus","missing_humanoid");return end
    hum.BreakJointsOnDeath=true
    player:SetAttribute("RSDeathStatus","alive")
    hum.Died:Connect(function()
        player:SetAttribute("RSDeathStatus","dead")
        player:SetAttribute("RSDeaths",(player:GetAttribute("RSDeaths") or 0)+1)
        -- Preserve Roblox joint breaking. Keep physical torso/head collision
        -- for the detached corpse; never anchor or teleport the dead body.
        task.defer(function()
            RunService.Heartbeat:Wait()
            if player.Character~=character then return end
            for _,name in {"UpperTorso","LowerTorso","Torso","Head"} do
                local part=character:FindFirstChild(name)
                if part and part:IsA("BasePart") then
                    part.CanCollide=true;part.CollisionGroup="Default"
                end
            end
            local torso=character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
            local start=torso and torso.Position.Y
            local minY=start
            for _=1,12 do
                task.wait(0.25)
                if player.Character~=character or not torso or not torso.Parent then break end
                minY=math.min(minY,torso.Position.Y)
            end
            if minY then
                player:SetAttribute("RSDeathMinY",math.round(minY*100)/100)
                player:SetAttribute("RSDeathStatus",if minY < -30 then "corpse_below_ground" else "corpse_observed")
            end
        end)
        task.delay(Players.RespawnTime,function()
            if player.Parent==Players and player.Character==character and hum.Health<=0 then spawn(player) end
        end)
    end)
    task.delay(2,function()
        if player.Character~=character or not alive(character) then return end
        local hrp=character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local hit=ground(hrp.Position.X,hrp.Position.Z,hrp.Position.Y+8)
        if not hit or hrp.Position.Y<hit.Position.Y-1 or hrp.Position.Y-hit.Position.Y>15 then
            player:SetAttribute("RSSpawnStatus","support_recovery");recover(player,character)
        else player:SetAttribute("RSSpawnStatus","ground_confirmed") end
    end)
end
local function onPlayer(player)
    player.CharacterAdded:Connect(function(c) onCharacter(player,c) end)
    if player.Character then task.spawn(onCharacter,player,player.Character) else task.spawn(spawn,player) end
end
Players.PlayerAdded:Connect(onPlayer)
Players.PlayerRemoving:Connect(function(p) loading[p]=nil end)
for _,p in Players:GetPlayers() do task.spawn(onPlayer,p) end
-- Actual gameplay raycast verification, not a claim made in edit-time Open Cloud.
task.spawn(function()
    task.wait(3)
    local pass,review=0,0
    local maxError=0
    for _,folder in {W.RSManagedAssets,W.RSSceneBuilder.Models,W.RSWorldVegetation.Models} do
        for _,m in folder:GetChildren() do
            if m:IsA("Model") then
                local p=m:GetPivot().Position
                local expected=m:GetAttribute("RSExpectedGroundY")
                local radius=m:GetAttribute("RSSupportRadius") or 2
                local ok=typeof(expected)=="number"
                for _,o in {{0,0},{radius,0},{-radius,0},{0,radius},{0,-radius}} do
                    local h=ground(p.X+o[1],p.Z+o[2],p.Y+80)
                    if not h or not ok then ok=false else
                        local err=math.abs(h.Position.Y-expected);maxError=math.max(maxError,err)
                        if err>3 then ok=false end
                    end
                end
                if ok then pass+=1 else review+=1 end
            end
        end
    end
    root:SetAttribute("RSPropsPass",pass);root:SetAttribute("RSPropsReview",review)
    root:SetAttribute("RSPropsMaxError",math.round(maxError*100)/100)
    print("RSQuality ground",pass,review,maxError)
end)
while true do
    task.wait(0.5)
    for _,p in Players:GetPlayers() do
        local c=p.Character
        if alive(c) then
            local hrp=c:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position.Y < -40 or math.abs(hrp.Position.X)>384 or math.abs(hrp.Position.Z)>384) then recover(p,c) end
        end
    end
end
