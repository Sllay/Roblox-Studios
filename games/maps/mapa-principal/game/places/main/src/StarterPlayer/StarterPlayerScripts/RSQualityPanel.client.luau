-- Mobile-friendly optional diagnostics for this staging test world.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local root=workspace:WaitForChild("RSCentralSpawns")
local gui=Instance.new("ScreenGui");gui.Name="RSQualityPanel";gui.ResetOnSpawn=false;gui.Parent=player:WaitForChild("PlayerGui")
local toggle=Instance.new("TextButton");toggle.Name="Toggle";toggle.Size=UDim2.fromOffset(112,34);toggle.Position=UDim2.new(1,-124,0,12)
toggle.BackgroundColor3=Color3.fromRGB(28,38,47);toggle.TextColor3=Color3.new(1,1,1);toggle.Text="P4 | Testes";toggle.TextSize=15;toggle.Parent=gui
local label=Instance.new("TextLabel");label.Size=UDim2.fromOffset(310,200);label.Position=UDim2.new(1,-322,0,52);label.BackgroundColor3=Color3.fromRGB(22,30,38)
label.BackgroundTransparency=0.15;label.TextColor3=Color3.new(1,1,1);label.TextSize=14;label.TextXAlignment=Enum.TextXAlignment.Left;label.TextYAlignment=Enum.TextYAlignment.Top;label.TextWrapped=true;label.Visible=false;label.Parent=gui
toggle.Activated:Connect(function() label.Visible=not label.Visible end)
local frames,elapsed=0,0
local fps=0
RunService.RenderStepped:Connect(function(dt)
    frames+=1;elapsed+=dt
    if elapsed>=1 then fps=math.round(frames/elapsed);frames=0;elapsed=0 end
end)
while gui.Parent do
    task.wait(0.5)
    if label.Visible then
        label.Text=string.format("  FPS local: %d\n  Spawn: %s (%s, %s)\n  Validacao: %s | seguros: %s\n  Query: %s | raio: %s / voxel: %s\n  Props: %s raio / %s voxel / %s revisar\n  Mortes: %s | %s\n  Min Y corpo: %s",
            fps,tostring(player:GetAttribute("RSSpawnPoint") or "-"),tostring(player:GetAttribute("RSSpawnX") or "-"),tostring(player:GetAttribute("RSSpawnZ") or "-"),
            tostring(player:GetAttribute("RSSpawnStatus") or "-"),tostring(root:GetAttribute("RSValidSpawnCount") or "-"),
            tostring(root:GetAttribute("RSQueryStatus") or "verificando"),tostring(root:GetAttribute("RSRaySpawns") or "-"),tostring(root:GetAttribute("RSVoxelSpawns") or "-"),
            tostring(root:GetAttribute("RSPropsPass") or "-"),tostring(root:GetAttribute("RSPropsEstimate") or "-"),tostring(root:GetAttribute("RSPropsReview") or "-"),
            tostring(player:GetAttribute("RSDeaths") or 0),tostring(player:GetAttribute("RSDeathStatus") or "-"),tostring(player:GetAttribute("RSDeathMinY") or "-"))
    end
end
