--!strict
-- T1-R1 client entrypoint. UI comes up first; gameplay controls only after server confirms a loaded world.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Lane = require(script.Parent:WaitForChild("LaneController"))
local Camera = require(script.Parent:WaitForChild("SideCamera"))
local Menu = require(script.Parent:WaitForChild("SlotMenu"))
local slots = ReplicatedStorage:WaitForChild("Game"):WaitForChild("ER_WorldSlots")

local function startDiagnostics()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ER_PerformanceMetrics"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 6
    gui.Parent = player:WaitForChild("PlayerGui")
    local stats = Instance.new("TextLabel")
    stats.Name = "ClientFPSAndLane"
    stats.Position = UDim2.fromOffset(12, 16)
    stats.Size = UDim2.fromOffset(245, 48)
    stats.TextSize = 12
    stats.Font = Enum.Font.Code
    stats.TextColor3 = Color3.new(1, 1, 1)
    stats.BackgroundColor3 = Color3.fromRGB(15, 24, 19)
    stats.BackgroundTransparency = 0.3
    stats.TextXAlignment = Enum.TextXAlignment.Left
    stats.Parent = gui
    local elapsed = 0
    local frames = 0
    RunService.RenderStepped:Connect(function(dt)
        elapsed += dt
        frames += 1
        if elapsed < 1 then return end
        local fps = math.floor(frames / math.max(elapsed, 0.001) + 0.5)
        local character = player.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        local zDrift = if root and root:IsA("BasePart") then math.abs(root.Position.Z) else 0
        stats.Text = string.format("FPS local: %d | Z desvio: %.2f\nModo: %s | Seed: %s",
            fps, zDrift, Lane.mode(), tostring(player:GetAttribute("ER_Seed") or "?"))
        elapsed = 0
        frames = 0
    end)
end

Menu.start(slots, function(result, options)
    Camera.setWide(options.wide)
    Lane.start(player)
    Camera.start(player)
    if options.debug then startDiagnostics() end
    print("[EntreReinos] World loaded, seed " .. tostring(result.seed))
end)
