--!strict
-- T1-R1. Functional six-world selector. No fake offline saves or silent deletion.
local Players = game:GetService("Players")
local SlotMenu = {}

local function newText(parent: Instance, text: string, size: UDim2, pos: UDim2, fontSize: number)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(235, 235, 220)
    label.Font = Enum.Font.Gotham
    label.TextSize = fontSize
    label.TextWrapped = true
    label.Size = size
    label.Position = pos
    label.Parent = parent
    return label
end

local function button(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Text = text
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 16
    b.TextScaled = false
    b.TextColor3 = Color3.fromRGB(245, 246, 232)
    b.BackgroundColor3 = Color3.fromRGB(54, 82, 62)
    b.AutoButtonColor = true
    b.Size = size
    b.Position = pos
    b.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = b
    return b
end

local function displayError(value: any): string
    local known = {
        datastore_unavailable = "Salvamento indisponível. Nenhum progresso será criado localmente.",
        slot_not_empty = "Esse espaço já contém um mundo. Atualize a lista.",
        slot_missing_corrupt_or_locked = "Mundo ocupado em outro servidor, ausente ou incompatível.",
        locked_or_corrupt_slot = "Não é possível excluir este mundo enquanto estiver bloqueado.",
        r6_creation_failed = "Não foi possível gerar o R6 no servidor. Nenhum save foi alterado. Tente novamente.",
        r6_assignment_failed = "Erro ao carregar personagem R6; tente reconectar.",
        r6_spawn_in_progress = "O personagem está carregando. Aguarde alguns instantes.",
        player_disconnected = "Sua sessão foi encerrada; reabra o jogo.",
        world_already_active = "Já existe um mundo ativo. Tentando recuperar a entrada...",
        other_slot_active = "Outro mundo está ativo neste servidor. Entre novamente apenas para trocar de mundo.",
        no_active_session = "Nenhuma sessão de mundo está ativa neste servidor.",
        lane_setup_exception = "Falha ao conectar a física do personagem. Tente entrar no mesmo mundo novamente.",
        lane_setup_failed = "O personagem ainda não está pronto. Tente entrar novamente.",
        character_not_ready = "O personagem ainda está carregando. Tente novamente.",
        character_changed = "O personagem reapareceu durante a entrada. Tente entrar novamente.",
        r6_not_ready = "A conversão para R6 não terminou. Tente novamente.",
        terrain_activation_exception = "Falha na inicialização do terreno. Saia do servidor e entre novamente, sem excluir o save.",
        world_needs_new_server = "A geração não terminou neste servidor.",
        terrain_incomplete = "O terreno não terminou de carregar neste servidor.",
        terrain_read_failed = "Falha na leitura inicial do Terrain.",
        terrain_readback_failed = "Falha ao verificar o Terrain após a escrita.",
        terrain_readback_diff = "O motor retornou voxels diferentes dos gerados.",
        terrain_material_readback_diff = "O material dos voxels não corresponde ao esperado.",
        terrain_verify_missing_channels = "Água ou terreno não apareceram na verificação.",
        world_decoration_requires_new_server = "Falha na decoração do mundo após gerar o Terrain.",
        terrain_activation_exception = "O motor interrompeu a geração do Terrain.",
        session_conflict = "A sessão do save foi modificada por outra operação.",
        server_operation_failed = "O servidor encontrou uma falha ao iniciar. O save continua preservado.",
        character_setup_exception = "Falha ao preparar o personagem. Tente o mesmo mundo novamente.",
        request_busy = "O mundo ainda está carregando. Aguarde e tente novamente.",
        terrain_write_uncertain = "Falha na geração do Terrain. Inspecionar antes de tentar novamente.",
        nonempty_terrain_refuses_overwrite = "Terreno existente detectado: escrita bloqueada para evitar sobrescrever o Place.",
        rate_limited = "Aguarde um instante antes da próxima ação.",
    }
    return known[value] or ("Operação não confirmada: " .. tostring(value))
end

function SlotMenu.start(remote: RemoteFunction, onWorldLoaded: (any, any) -> ())
    local player = Players.LocalPlayer
    local gui = Instance.new("ScreenGui")
    gui.Name = "ER_MainMenu"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 40
    gui.Parent = player:WaitForChild("PlayerGui")

    local overlay = Instance.new("Frame")
    overlay.Name = "Backdrop"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(15, 23, 19)
    overlay.BackgroundTransparency = 0.08
    overlay.BorderSizePixel = 0
    overlay.Parent = gui

    local pane = Instance.new("Frame")
    pane.Name = "Panel"
    pane.AnchorPoint = Vector2.new(0.5, 0.5)
    pane.Position = UDim2.fromScale(0.5, 0.5)
    pane.Size = UDim2.fromScale(0.94, 0.88)
    pane.BackgroundColor3 = Color3.fromRGB(26, 38, 31)
    pane.BorderSizePixel = 0
    pane.Parent = overlay
    local constraint = Instance.new("UISizeConstraint")
    constraint.MaxSize = Vector2.new(760, 520)
    constraint.MinSize = Vector2.new(300, 240)
    constraint.Parent = pane
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = pane

    local title = newText(pane, "ENTRE REINOS", UDim2.new(1, -18, 0, 42), UDim2.fromOffset(9, 7), 27)
    title.Font = Enum.Font.GothamBold
    local status = newText(pane, "", UDim2.new(1, -22, 0, 40), UDim2.new(0, 11, 1, -44), 12)
    status.TextColor3 = Color3.fromRGB(213, 191, 150)

    local pages = {}
    for _, pageName in ipairs({"home", "slots", "options"}) do
        local frame = Instance.new("Frame")
        frame.Name = pageName
        frame.BackgroundTransparency = 1
        frame.Position = UDim2.fromOffset(11, 52)
        frame.Size = UDim2.new(1, -22, 1, -106)
        frame.Visible = pageName == "home"
        frame.Parent = pane
        pages[pageName] = frame
    end
    local options = {wide = false, debug = true}
    local busy = false
    local selected: number? = nil
    local pendingDeletion: number? = nil

    local function page(name: string)
        for key, frame in pairs(pages) do frame.Visible = key == name end
        status.Text = ""
        pendingDeletion = nil
    end

    local function request(action: string, index: number?): (any, string?)
        if busy then return nil, "request_busy" end
        busy = true
        status.Text = "Processando " .. action .. "..."
        local transportOk, answer = pcall(function()
            return remote:InvokeServer(action, index)
        end)
        busy = false
        if not transportOk or type(answer) ~= "table" then
            status.Text = "Resposta do servidor não confirmada. Tentaremos recuperar a sessão."
            return nil, "transport_failed"
        end
        if not answer.ok then
            local reason = tostring(answer.error)
            local description = displayError(reason)
            if reason == "other_slot_active" and type(answer.activeSlot) == "number" then
                description = "O Mundo " .. tostring(answer.activeSlot) ..
                    " está aberto. Selecione esse mesmo mundo para continuar."
            end
            if type(answer.stage) == "string" then
                description ..= " (etapa: " .. answer.stage .. ")"
            end
            if type(answer.terrainPhase) == "string" then
                description ..= " [geração: " .. answer.terrainPhase .. "]"
            end
            if answer.retryInNewServer then
                description ..= " | Saia do servidor. Não exclua o save."
            end
            status.Text = description
            return nil, reason, answer
        end
        status.Text = ""
        return answer, nil
    end

    local homeText = newText(pages.home, "Construa seu próprio reino medieval em um mundo 3D persistente.",
        UDim2.new(1, 0, 0, 58), UDim2.fromScale(0, 0.08), 15)
    homeText.TextColor3 = Color3.fromRGB(192, 207, 184)
    local play = button(pages.home, "Play", "Jogar", UDim2.new(0.6, 0, 0, 42), UDim2.new(0.2, 0, 0.42, 0))
    local settings = button(pages.home, "Settings", "Opções", UDim2.new(0.6, 0, 0, 42), UDim2.new(0.2, 0, 0.69, 0))

    local list = Instance.new("ScrollingFrame")
    list.Name = "WorldSlots"
    list.BackgroundTransparency = 1
    list.Size = UDim2.new(1, 0, 1, -40)
    list.ScrollBarThickness = 5
    list.BorderSizePixel = 0
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.Parent = pages.slots
    local vertical = Instance.new("UIListLayout")
    vertical.SortOrder = Enum.SortOrder.LayoutOrder
    vertical.Padding = UDim.new(0, 6)
    vertical.Parent = list
    local back = button(pages.slots, "Back", "Voltar", UDim2.new(0, 112, 0, 32), UDim2.new(0, 0, 1, -33))
    back.Activated:Connect(function() page("home") end)

    local function buildRows(summaries: {any})
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        for index = 1, 6 do
            local summary = summaries[index] or {index = index, exists = false}
            local row = Instance.new("Frame")
            row.Name = "Slot" .. tostring(index)
            row.Size = UDim2.new(1, -8, 0, 46)
            row.BackgroundColor3 = Color3.fromRGB(34, 49, 39)
            row.BorderSizePixel = 0
            row.LayoutOrder = index
            row.Parent = list
            local label = newText(row, "Mundo " .. tostring(index), UDim2.new(0.42, 0, 1, 0), UDim2.fromScale(0.012, 0), 14)
            label.TextXAlignment = Enum.TextXAlignment.Left
            if summary.exists then
                label.Text = "Mundo " .. tostring(index) .. "  •  Dia " .. tostring(summary.worldDay or 1)
            elseif summary.corrupt then
                label.Text = "Mundo " .. tostring(index) .. "  •  Dados incompatíveis"
            else
                label.Text = "Mundo " .. tostring(index) .. "  •  Vazio"
            end
            local choose = button(row, "Choose", if summary.exists then "Entrar" else "Criar",
                UDim2.new(0.25, 0, 0, 34), UDim2.new(0.49, 0, 0.5, -17))
            choose.Active = not summary.corrupt
            choose.Activated:Connect(function()
                if summary.corrupt or busy then return end
                selected = index
                local action = if summary.exists then "open" else "create"
                local answer, failure, details = request(action, index)
                local recoverCharacter = details and details.recoverable == true
                    and (details.stage == "character" or details.stage == "lane")
                if not answer and (recoverCharacter or failure == "transport_failed"
                    or failure == "world_already_active") then
                    -- Resume only a potentially ready session. Never overwrite a
                    -- Terrain failure with "world_needs_new_server".
                    task.wait(0.15)
                    answer = request("resume", index)
                end
                if answer then
                    overlay.Visible = false
                    onWorldLoaded(answer, options)
                end
            end)
            local remove = button(row, "Delete", "Excluir", UDim2.new(0.22, 0, 0, 34), UDim2.new(0.76, 0, 0.5, -17))
            remove.BackgroundColor3 = Color3.fromRGB(101, 53, 49)
            remove.Active = summary.exists
            remove.Visible = summary.exists
            remove.Activated:Connect(function()
                if busy then return end
                if pendingDeletion ~= index then
                    pendingDeletion = index
                    status.Text = "Toque Excluir novamente para apagar DEFINITIVAMENTE o mundo " .. tostring(index)
                    return
                end
                pendingDeletion = nil
                local answer = request("delete", index)
                if answer then
                    summaries[index] = answer.summary
                    buildRows(summaries)
                end
            end)
        end
    end

    play.Activated:Connect(function()
        page("slots")
        local response = request("list", nil)
        if response then buildRows(response.slots) end
    end)

    local optText = newText(pages.options, "Ajustes visuais locais. Seu progresso é salvo no servidor.",
        UDim2.new(1, 0, 0, 45), UDim2.fromScale(0, 0.03), 14)
    optText.TextColor3 = Color3.fromRGB(192, 207, 184)
    local zoom = button(pages.options, "Zoom", "Câmera: padrão", UDim2.new(0.8, 0, 0, 42), UDim2.new(0.1, 0, 0.29, 0))
    zoom.Activated:Connect(function()
        options.wide = not options.wide
        zoom.Text = if options.wide then "Câmera: ampla" else "Câmera: padrão"
    end)
    local diagnostics = button(pages.options, "Debug", "Indicadores FPS: ligados", UDim2.new(0.8, 0, 0, 42), UDim2.new(0.1, 0, 0.54, 0))
    diagnostics.Activated:Connect(function()
        options.debug = not options.debug
        diagnostics.Text = if options.debug then "Indicadores FPS: ligados" else "Indicadores FPS: desligados"
    end)
    local optionsBack = button(pages.options, "Back", "Voltar", UDim2.new(0.4, 0, 0, 34), UDim2.new(0.3, 0, 0.81, 0))
    optionsBack.Activated:Connect(function() page("home") end)
    settings.Activated:Connect(function() page("options") end)
end

return SlotMenu
