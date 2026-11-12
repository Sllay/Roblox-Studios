-- Native SpawnLocations already choose a random eligible spawn.
-- Runtime safety: detect a fall off the bounded island, return to a valid spawn.
local Players=game:GetService("Players")
local root=workspace:WaitForChild("RSCentralSpawns")
local rng=Random.new()
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Include
params.FilterDescendantsInstances={workspace.Terrain}
params.IgnoreWater=false
local function validSpawns()
    local result={}
    for _,s in root:GetChildren() do
        if s:IsA("SpawnLocation") and s.Enabled then
            local hit=workspace:Raycast(s.Position+Vector3.new(0,8,0),Vector3.new(0,-20,0),params)
            if hit and hit.Material~=Enum.Material.Water and hit.Normal.Y>=0.9 and math.abs(hit.Position.Y-14)<3 then table.insert(result,s) end
        end
    end
    return result
end
local function recover(character)
    local points=validSpawns()
    if #points==0 then return end
    local s=points[rng:NextInteger(1,#points)]
    character:PivotTo(s.CFrame+Vector3.new(0,5,0))
    local hrp=character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.AssemblyLinearVelocity=Vector3.zero;hrp.AssemblyAngularVelocity=Vector3.zero end
end
while true do
    task.wait(1)
    for _,player in Players:GetPlayers() do
        local character=player.Character
        local hrp=character and character:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Position.Y < -24 then recover(character) end
    end
end
