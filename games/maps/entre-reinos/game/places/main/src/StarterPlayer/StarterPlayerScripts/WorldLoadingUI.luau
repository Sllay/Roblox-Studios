--!strict
-- Dedicated reserved-server loading interface. The entire backdrop is opaque.
-- Progress comes from server-authoritative Player attributes, never a fake timer.
local TeleportService = game:GetService("TeleportService")
local WorldLoadingUI = {}
local messages: {[string]: string} = {
    connecting = "Conectando ao seu servidor privado...",
    validating = "Validando acesso ao mundo...",
    character = "Preparando personagem R6...",
    slot = "Abrindo seu mundo salvo...",
    terrain = "Gerando o terreno inicial em regiões...",
    spawn = "Preparando câmera e física...",
    ready = "Tudo pronto!",
    failed = "Não foi possível entrar no mundo.",
}
local function label(parent: Instance, text: string, size: number, position: UDim2, dimensions: UDim2)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.Font = Enum.Font.Gotham
    l.TextSize = size
    l.TextColor3 = Color3.fromRGB(239, 239, 225)
    l.TextWrapped = true
    l.Size = dimensions
    l.Position = position
    l.Parent = parent
    return l
end

function WorldLoadingUI.start(player: Player, remote: RemoteFunction, onReady: () -> ())
    local gui = Instance.new("ScreenGui")
    gui.Name = "ER_WorldLoading"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100
    gui.IgnoreGuiInset = true
    gui.Parent = player:WaitForChild("PlayerGui")

    local shade = Instance.new("Frame")
    shade.Name = "OpaqueBackground"
    shade.Size = UDim2.fromScale(1, 1)
    shade.BackgroundTransparency = 0
    shade.BackgroundColor3 = Color3.fromRGB(18, 28, 23)
    shade.BorderSizePixel = 0
    shade.Parent = gui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.new(0.85, 0, 0, 260)
    card.BackgroundColor3 = Color3.fromRGB(29, 43, 35)
    card.BorderSizePixel = 0
    card.Parent = shade
    local limit = Instance.new("UISizeConstraint")
    limit.MaxSize = Vector2.new(660, 310)
    limit.Parent = card
    local title = label(card, "ENTRE REINOS", 28,
        UDim2.new(0, 0, 0.10, 0), UDim2.new(1, 0, 0, 38))
    title.Font = Enum.Font.GothamBold
    local stageLabel = label(card, "Preparando mundo...", 18,
        UDim2.new(0.06, 0, 0.40, 0), UDim2.new(0.88, 0, 0, 60))
    local progressBg = Instance.new("Frame")
    progressBg.Position = UDim2.fromScale(0.10, 0.71)
    progressBg.Size = UDim2.fromScale(0.80, 0.045)
    progressBg.BackgroundColor3 = Color3.fromRGB(55, 64, 57)
    progressBg.BorderSizePixel = 0
    progressBg.Parent = card
    local progress = Instance.new("Frame")
    progress.Name = "ActualProgress"
    progress.Size = UDim2.fromScale(0.01, 1)
    progress.BackgroundColor3 = Color3.fromRGB(111, 173, 127)
    progress.BorderSizePixel = 0
    progress.Parent = progressBg
    local amount = label(card, "0%", 13,
        UDim2.new(0.1, 0, 0.78, 0), UDim2.new(0.8, 0, 0, 22))
    local back = Instance.new("TextButton")
    back.Name = "ReturnLobby"
    back.Text = "Voltar ao lobby"
    back.TextSize = 16
    back.Font = Enum.Font.GothamMedium
    back.TextColor3 = Color3.fromRGB(245, 244, 232)
    back.BackgroundColor3 = Color3.fromRGB(72, 94, 76)
    back.Size = UDim2.new(0.46, 0, 0, 40)
    back.Position = UDim2.new(0.27, 0, 0.81, 0)
    back.Visible = false
    back.Parent = card

    local completed = false
    local function render()
        if completed then return end
        local current = player:GetAttribute("ER_LoadStage")
        local p = player:GetAttribute("ER_LoadProgress")
        local message = player:GetAttribute("ER_LoadMessage")
        local errorCode = player:GetAttribute("ER_LoadError")
        if type(p) == "number" then
            local percent = math.clamp(p, 0, 1)
            progress.Size = UDim2.fromScale(math.max(0.01, percent), 1)
            amount.Text = tostring(math.floor(percent * 100 + 0.5)) .. "%"
        end
        stageLabel.Text = if type(message) == "string" and message ~= "" then message
            elseif type(current) == "string" then (messages[current] or current)
            else "Conectando ao servidor..."
        if current == "failed" then
            if type(errorCode) == "string" and errorCode ~= "" then
                stageLabel.Text ..= " [" .. errorCode .. "]"
            end
            back.Visible = true
        end
        if current == "ready" and player:GetAttribute("ER_WorldLoaded") == true then
            completed = true
            gui:Destroy()
            onReady()
        end
    end
    player:GetAttributeChangedSignal("ER_LoadStage"):Connect(render)
    player:GetAttributeChangedSignal("ER_LoadMessage"):Connect(render)
    player:GetAttributeChangedSignal("ER_LoadProgress"):Connect(render)
    player:GetAttributeChangedSignal("ER_LoadError"):Connect(render)
    player:GetAttributeChangedSignal("ER_WorldLoaded"):Connect(render)
    back.Activated:Connect(function()
        back.Active = false
        stageLabel.Text = "Voltando para o lobby..."
        local invoked, response = pcall(function() return remote:InvokeServer("return") end)
        if not invoked or type(response) ~= "table" or not response.ok then
            stageLabel.Text = "Não foi possível voltar; use Sair no menu Roblox."
            back.Active = true
        end
    end)
    -- In Roblox Teleport, the new Place boot is asynchronous; show the current
    -- server state and listen for changes rather than waiting on an RPC.
    render()
end
return WorldLoadingUI
