--!strict
-- Roblox-Studios: prova visual de execução do LocalScript no celular.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local existing = playerGui:FindFirstChild("RobloxStudiosClientStatus")
if existing then existing:Destroy() end
local ui = Instance.new("ScreenGui")
ui.Name = "RobloxStudiosClientStatus"
ui.ResetOnSpawn = false
ui.IgnoreGuiInset = true
ui.DisplayOrder = 40
ui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "Status"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.fromScale(0.5, 0.04)
label.Size = UDim2.new(0.88, 0, 0, 46)
label.BackgroundColor3 = Color3.fromRGB(17, 30, 49)
label.BackgroundTransparency = 0.12
label.TextColor3 = Color3.fromRGB(232, 244, 255)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Text = "LOCAL OK | buscando plataforma..."
label.Parent = ui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = label
local size = Instance.new("UISizeConstraint")
size.MaxSize = Vector2.new(440, 46)
size.MinSize = Vector2.new(190, 46)
size.Parent = label

local folder = workspace:WaitForChild("RobloxStudiosSmoke", 20)
if not folder then
    label.Text = "LOCAL OK | pasta de teste ausente"
    warn("[RobloxStudiosSmoke] O teste local iniciou, mas falta a pasta")
    return
end
local platform = folder:WaitForChild("FloatingPlatform", 20)
if not platform or not platform:IsA("BasePart") then
    label.Text = "LOCAL OK | Part ausente"
    warn("[RobloxStudiosSmoke] O teste local iniciou, mas falta a Part")
    return
end

local baseY = platform.Position.Y
label.Text = "LOCAL OK | esperando movimento..."
print("[RobloxStudiosSmoke] CLIENT OK; monitorando plataforma")

local connection: RBXScriptConnection?
local startedAt = os.clock()
connection = RunService.Heartbeat:Connect(function()
    if not platform:IsDescendantOf(workspace) then
        label.Text = "LOCAL OK | plataforma removida"
        if connection then connection:Disconnect() end
        return
    end
    if math.abs(platform.Position.Y - baseY) >= 0.5 then
        label.Text = "LOCAL OK | PLATAFORMA FLUTUANDO"
        print("[RobloxStudiosSmoke] CLIENT OK; movimento replicado")
        if connection then connection:Disconnect() end
    elseif os.clock() - startedAt > 15 then
        label.Text = "LOCAL OK | movimento não detectado"
        warn("[RobloxStudiosSmoke] Sem movimento após 15 segundos")
        if connection then connection:Disconnect() end
    end
end)
