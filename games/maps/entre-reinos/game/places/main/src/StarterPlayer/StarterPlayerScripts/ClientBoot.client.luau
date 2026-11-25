--!strict
-- T1-R1 client entrypoint. UI comes up first; gameplay controls only after server confirms a loaded world.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local Lane = require(script.Parent:WaitForChild("LaneController"))
local Camera = require(script.Parent:WaitForChild("SideCamera"))
local Menu = require(script.Parent:WaitForChild("SlotMenu"))
local Loading = require(script.Parent:WaitForChild("WorldLoadingUI"))
local NPCPresentation = require(script.Parent:WaitForChild("NPCPresentation"))
local VehiclePresentation=require(script.Parent:WaitForChild("VehiclePresentation"))
local R3HUD = require(script.Parent:WaitForChild("R3HUD"))
local slots = ReplicatedStorage:WaitForChild("Game"):WaitForChild("ER_WorldSlots")

local function startDiagnostics()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ER_PerformanceMetrics"
    gui.ResetOnSpawn = false
    -- Respect the Roblox topbar and phone notch / CoreGui touch-safe area.
    gui.IgnoreGuiInset = false
    gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    gui.DisplayOrder = 6
    gui.Parent = player:WaitForChild("PlayerGui")
    local stats = Instance.new("TextLabel")
    stats.Name = "ClientFPSAndLane"
    -- Right-aligned, beneath the native topbar, away from the mobile joystick.
    stats.AnchorPoint = Vector2.new(1, 0)
    stats.Position = UDim2.new(1, -12, 0, 10)
    stats.Size = UDim2.fromOffset(246, 58)
    stats.TextSize = 12
    stats.Font = Enum.Font.Code
    stats.TextColor3 = Color3.new(1, 1, 1)
    stats.BackgroundColor3 = Color3.fromRGB(15, 24, 19)
    stats.BackgroundTransparency = 0.12
    stats.BorderSizePixel = 0
    stats.TextWrapped = true
    stats.TextXAlignment = Enum.TextXAlignment.Left
    stats.TextYAlignment = Enum.TextYAlignment.Center
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

local mode = player:GetAttribute("ER_ServerMode")
if type(mode) ~= "string" then
    player:GetAttributeChangedSignal("ER_ServerMode"):Wait()
    mode = player:GetAttribute("ER_ServerMode")
end
if mode == "world" then
    Loading.start(player, slots, function()
        local savedOptions = TeleportService:GetTeleportSetting("ER_Options")
        if type(savedOptions) ~= "table" then savedOptions = {wide = false, debug = false} end
        Camera.setWide(savedOptions.wide == true)
        Lane.start(player)
        Camera.start(player)
        NPCPresentation.start()
        task.spawn(VehiclePresentation.start)
        R3HUD.start(player)
        if savedOptions.debug ~= false then startDiagnostics() end
        print("[EntreReinos] Reserved world ready, seed ", player:GetAttribute("ER_Seed"))
    end)
else
    -- A public server is lobby only: no camera/gameplay controller/terrain.
    Menu.start(slots, function(_result, _options) end)
end
