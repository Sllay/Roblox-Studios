-- P4 hotfix: native lifecycle is independent of optional terrain diagnostics.
local Players=game:GetService("Players")
Players.CharacterAutoLoads=true
local W=workspace
local RunService=game:GetService("RunService")
local Policy=require(script.Parent:WaitForChild("RSGameplayPolicy"))
local root=W:WaitForChild("RSCentralSpawns")
local T=W.Terrain
local rng=Random.new()
local ray=RaycastParams.new()
ray.FilterType=Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances={T}
ray.IgnoreWater=false
local physical=RaycastParams.new()
physical.FilterType=Enum.RaycastFilterType.Include
physical.FilterDescendantsInstances={T}
physical.IgnoreWater=false
physical.RespectCanCollide=true
local overlap=OverlapParams.new()
overlap.FilterType=Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances={T,root}
overlap.RespectCanCollide=true
overlap.MaxParts=8
local function rayGround(x,z,top)
    local o=Vector3.new(x,top,z)
    local d=Vector3.new(0,-240,0)
    -- Compare filters rather than treating a missing query as proof of no terrain.
    for _,params in {ray,physical} do
        local h=W:Raycast(o,d,params)
        if h and h.Instance==T then return h,"filtered" end
    end
    local h=W:Raycast(o,d)
    if h and h.Instance==T then return h,"unfiltered" end
    return nil,"unavailable"
end
-- Read small aligned native voxel columns. This is a structural estimate,
-- NOT a collision hit. Never treat unavailable queries as confirmed physics.
local voxelCache={}
local function voxelColumn(ix,iz)
    local key=ix..":"..iz
    if voxelCache[key]~=nil then return voxelCache[key] or nil end
    local b=Vector3.new(ix*4,-32,iz*4)
    local ok,d=pcall(function()
        return T:ReadVoxelChannels(Region3.new(b,b+Vector3.new(4,144,4)),4,{"SolidMaterial","SolidOccupancy","LiquidOccupancy"})
    end)
    if not ok then voxelCache[key]=false;return nil end
    local height=nil
    local wet=false
    local solidBelow=true
    local gap=false
    for y=1,36 do
        local s=d.SolidOccupancy[1][y][1]
        local w=d.LiquidOccupancy[1][y][1]
        if w>0.02 then wet=true end
        if s>0.02 then
            if gap then solidBelow=false end
            height=-32+(y-1+s)*4
        else gap=true end
    end
    if not height or wet or not solidBelow then voxelCache[key]=false;return nil end
    local row={height=height};voxelCache[key]=row;return row
end
local function voxelGround(x,z)
    local gx,gz=x/4-0.5,z/4-0.5
    local i,j=math.floor(gx),math.floor(gz)
    local a,b,c,d=voxelColumn(i,j),voxelColumn(i+1,j),voxelColumn(i,j+1),voxelColumn(i+1,j+1)
    if not (a and b and c and d) then return nil end
    local tx,tz=gx-i,gz-j
    return (a.height+(b.height-a.height)*tx)*(1-tz)+(c.height+(d.height-c.height)*tx)*tz
end
local function support(x,z,expected,radius)
    local center,method=rayGround(x,z,expected+80)
    if center then
        if center.Material==Enum.Material.Water or not Policy.supportValid(center.Position.Y,expected,center.Normal.Y,3,0.88) then return nil,"ray_invalid" end
        for _,o in {{radius,0},{-radius,0},{0,radius},{0,-radius}} do
            local h=rayGround(x+o[1],z+o[2],expected+80)
            if not h then return nil,"ray_partial" end
            if h.Material==Enum.Material.Water or h.Normal.Y<0.85 or math.abs(h.Position.Y-center.Position.Y)>2.5 then return nil,"ray_invalid" end
        end
        return center.Position.Y,"ray_"..method
    end
    local y=voxelGround(x,z)
    if not y or math.abs(y-expected)>3 then return nil,"voxel_unavailable_or_invalid" end
    for _,o in {{radius,0},{-radius,0},{0,radius},{0,-radius}} do
        local h=voxelGround(x+o[1],z+o[2])
        if not h or math.abs(h-y)>2.5 then return nil,"voxel_invalid" end
    end
    return y,"voxel_estimate"
end
local function valid(s)
    if not s:IsA("SpawnLocation") or not s.Enabled or not s.Neutral then return nil,"disabled" end
    local p=s.Position
    if not Policy.inRadius(p.X,p.Z,108) then return nil,"radius" end
    local y,method=support(p.X,p.Z,p.Y-2,3)
    if not y then return nil,method end
    local box=CFrame.new(p.X,y+3.5,p.Z)
    if #W:GetPartBoundsInBox(box,Vector3.new(4,6,4),overlap)>0 then return nil,"obstruction" end
    return y,method
end
local reviewed={}
local function choose(previous)
    local candidates={}
    for _,s in root:GetChildren() do
        if s:IsA("SpawnLocation") and s.Enabled and s.Neutral and s~=previous then
            if reviewed[s] then table.insert(candidates,s) end
        end
    end
    if #candidates==0 and previous and reviewed[previous] then return previous end
    if #candidates==0 then return nil end
    return candidates[rng:NextInteger(1,#candidates)]
end
local function selectNext(player)
    local selected=choose(player.RespawnLocation)
    -- Native spawn is always available, even if all optional diagnostics fail.
    -- The 53 persisted markers were checked against native voxels before save.
    player.RespawnLocation=selected
    player:SetAttribute("RSNextSpawnMode",if selected then reviewed[selected] else "native_prevalidated")
end
local function alive(character)
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    return Policy.humanoidAlive(hum)
end
local function recover(player,character)
    if player.Character~=character or not alive(character) then return end
    local s=choose(player.RespawnLocation)
    if not s then player:SetAttribute("RSRecoveryStatus","native_reset");character:FindFirstChildOfClass("Humanoid").Health=0;return end
    local y,method=valid(s)
    if not y then player:SetAttribute("RSRecoveryStatus","native_reset");character:FindFirstChildOfClass("Humanoid").Health=0;return end
    character:PivotTo(CFrame.new(s.Position.X,y+5,s.Position.Z))
    local hrp=character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.AssemblyLinearVelocity=Vector3.zero;hrp.AssemblyAngularVelocity=Vector3.zero end
    player:SetAttribute("RSRecoveryStatus","recovered_"..method)
end
local watched=setmetatable({},{__mode="k"})
local function onCharacter(player,character)
    if watched[character] then return end
    watched[character]=true
    local hum=character:WaitForChild("Humanoid",10)
    local hrp=character:WaitForChild("HumanoidRootPart",10)
    if not hum or not hrp then return end
    hum.BreakJointsOnDeath=true
    player:SetAttribute("RSDeathStatus","alive")
    player:SetAttribute("RSSpawnStatus","native_loaded")
    hum.Died:Connect(function()
        player:SetAttribute("RSDeathStatus","dead")
        player:SetAttribute("RSDeaths",(player:GetAttribute("RSDeaths") or 0)+1)
        selectNext(player)
        task.defer(function()
            RunService.Heartbeat:Wait()
            if player.Character~=character then return end
            for _,name in {"UpperTorso","LowerTorso","Torso","Head"} do
                local part=character:FindFirstChild(name)
                if part and part:IsA("BasePart") then part.CanCollide=true;part.CollisionGroup="Default" end
            end
            local torso=character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
            local minY=torso and torso.Position.Y
            for _=1,12 do
                task.wait(0.25)
                if player.Character~=character or not torso or not torso.Parent then break end
                minY=math.min(minY,torso.Position.Y)
            end
            if minY and player.Character==character then
                player:SetAttribute("RSDeathMinY",math.round(minY*100)/100)
                player:SetAttribute("RSDeathStatus",if minY < -30 then "corpse_below_ground" else "corpse_observed")
            end
        end)
    end)
    task.delay(1,function()
        if player.Character~=character or not alive(character) then return end
        local pos=hrp.Position
        local nearest,dist=nil,math.huge
        for _,s in root:GetChildren() do
            if s:IsA("SpawnLocation") then
                local d=(Vector2.new(s.Position.X,s.Position.Z)-Vector2.new(pos.X,pos.Z)).Magnitude
                if d<dist then nearest,dist=s,d end
            end
        end
        player:SetAttribute("RSSpawnPoint",if nearest then nearest.Name else "native")
        player:SetAttribute("RSSpawnX",math.round(pos.X));player:SetAttribute("RSSpawnZ",math.round(pos.Z))
        local h=rayGround(pos.X,pos.Z,pos.Y+8)
        if h and h.Material~=Enum.Material.Water and pos.Y>=h.Position.Y-1 and pos.Y-h.Position.Y<=15 then
            player:SetAttribute("RSSpawnStatus","ground_confirmed")
        else
            local y=voxelGround(pos.X,pos.Z)
            if y and pos.Y>=y-1 and pos.Y-y<=15 then player:SetAttribute("RSSpawnStatus","voxel_supported")
            else player:SetAttribute("RSSpawnStatus","native_loaded_query_unavailable") end
        end
    end)
end
local function onPlayer(player)
    selectNext(player)
    player.CharacterAdded:Connect(function(c) onCharacter(player,c) end)
    if player.Character then task.spawn(onCharacter,player,player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _,p in Players:GetPlayers() do task.spawn(onPlayer,p) end
-- Diagnostics must never delay character creation. Yield periodically to avoid
-- a long startup stall on the server. Distinguish estimates from physics.
task.spawn(function()
    local confirmed,estimated,missing=0,0,0
    local reasons={}
    for _,s in root:GetChildren() do
        local ok,y,method=pcall(valid,s)
        if ok and y then
            reviewed[s]=method
            if method=="voxel_estimate" then estimated+=1 else confirmed+=1 end
        else
            missing+=1
            local reason=if ok then method else "query_error"
            reasons[reason]=(reasons[reason] or 0)+1
        end
        task.wait()
    end
    root:SetAttribute("RSValidSpawnCount",confirmed+estimated)
    root:SetAttribute("RSRaySpawns",confirmed);root:SetAttribute("RSVoxelSpawns",estimated);root:SetAttribute("RSRejectedSpawns",missing)
    root:SetAttribute("RSQueryStatus",if confirmed>0 then "ray_available" elseif estimated>0 then "voxel_only" else "query_unavailable")
    print("RSQuality spawn",confirmed,estimated,missing,game:GetService("HttpService"):JSONEncode(reasons))
    local pass,estimate,review=0,0,0
    for _,folder in {W.RSManagedAssets,W.RSSceneBuilder.Models,W.RSWorldVegetation.Models} do
        for _,m in folder:GetChildren() do
            if not m:IsA("Model") then continue end
            local p=m:GetPivot().Position
            local expected=m:GetAttribute("RSExpectedGroundY")
            local radius=m:GetAttribute("RSSupportRadius") or 2
            local ok,y,method=pcall(support,p.X,p.Z,expected,radius)
            if ok and y then
                if method=="voxel_estimate" then estimate+=1 else pass+=1 end
            else review+=1 end
            task.wait()
        end
    end
    root:SetAttribute("RSPropsPass",pass);root:SetAttribute("RSPropsEstimate",estimate);root:SetAttribute("RSPropsReview",review)
end)
while true do
    task.wait(0.5)
    for _,p in Players:GetPlayers() do
        local c=p.Character
        if alive(c) then
            local hrp=c:FindFirstChild("HumanoidRootPart")
            if hrp and not Policy.inWorld(hrp.Position.X,hrp.Position.Y,hrp.Position.Z,384,-40) then recover(p,c) end
        end
    end
end
