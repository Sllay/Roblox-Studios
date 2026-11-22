--!strict
-- Mobile-first T1-R2 construction orders. UI only sends intent; the private
-- server decides valid location, materials, progress and NPC assignment.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Structures=require(ReplicatedStorage:WaitForChild("Game")
    :WaitForChild("Living"):WaitForChild("StructureDefs"))
local Menu={}
local installed=false
local order={"shelter","house","stockpile","fence","wall"}
local placing=false
local errorMessages={
    rate_limited="Aguarde um instante antes de enviar outra ordem.",
    no_available_build_site="Sem terreno livre a até 48 studs. Ande para outra área.",
    invalid_footprint_or_slope="Terreno muito inclinado ou perto da água.",
    overlapping_footprint="Já existe uma obra ocupando esse espaço.",
    building_limit="Limite de construções atingido.",
    outside_playable_lane="Você precisa estar na área jogável.",
    character_not_ready="Personagem ainda não está pronto.",
    world_not_loaded="Mundo ainda não terminou de carregar.",
    connection_failed="Não foi possível falar com o servidor.",
}
local function label(parent: Instance,txt: string,size: number): TextLabel
    local l=Instance.new("TextLabel")
    l.Text=txt
    l.BackgroundTransparency=1
    l.TextSize=size
    l.TextColor3=Color3.fromRGB(243,241,222)
    l.TextWrapped=true
    l.Font=Enum.Font.Gotham
    l.Size=UDim2.new(1,-12,0,35)
    l.Parent=parent
    return l
end
function Menu.start(player: Player)
    if installed then return end
    installed=true
    local remote=ReplicatedStorage:WaitForChild("Game"):WaitForChild("ER_LivingActions",12)
    if not remote or not remote:IsA("RemoteFunction") then
        warn("[EntreReinos] Build remote missing; UI not installed")
        return
    end
    local gui=Instance.new("ScreenGui")
    gui.Name="ER_ConstructionOrders"
    gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=false
    gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
    gui.DisplayOrder=8
    gui.Parent=player:WaitForChild("PlayerGui")

    local open=Instance.new("TextButton")
    open.Name="BuildToggle"
    open.Text="Construir"
    open.TextSize=15
    open.Font=Enum.Font.GothamBold
    open.TextColor3=Color3.fromRGB(239,238,225)
    open.BackgroundColor3=Color3.fromRGB(49,81,61)
    open.Size=UDim2.fromOffset(130,42)
    open.Position=UDim2.new(0,14,0,90)
    open.Parent=gui

    local panel=Instance.new("ScrollingFrame")
    panel.Name="OrderPanel"
    panel.BackgroundColor3=Color3.fromRGB(24,37,28)
    panel.BackgroundTransparency=0.03
    panel.BorderSizePixel=0
    panel.Position=UDim2.new(0,14,0,138)
    panel.Size=UDim2.new(0,236,0.60,0)
    panel.CanvasSize=UDim2.new(0,0,0,420)
    panel.ScrollBarThickness=4
    panel.Visible=false
    panel.Parent=gui
    local limit=Instance.new("UISizeConstraint")
    limit.MaxSize=Vector2.new(236,460)
    limit.Parent=panel
    local layout=Instance.new("UIListLayout")
    layout.Padding=UDim.new(0,7)
    layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.Parent=panel
    label(panel,"ORDENS DA VILA",17).Font=Enum.Font.GothamBold
    local status=label(panel,"Coloque uma obra próximo ao personagem.",12)
    status.Size=UDim2.new(1,-10,0,52)

    local function call(action: string, arg: string?): any
        local ok,response=pcall(function()
            return remote:InvokeServer(action,arg)
        end)
        if not ok or type(response)~="table" then
            return {ok=false,error="connection_failed"}
        end
        return response
    end

    for _,id in ipairs(order) do
        local def=Structures.get(id)
        local b=Instance.new("TextButton")
        b.Name="Order_"..id
        local cost=""
        for resource,amount in pairs(def.cost) do
            cost..=resource.." "..tostring(amount).."  "
        end
        b.Text=def.label.."\n"..cost
        b.TextWrapped=true
        b.TextSize=13
        b.Font=Enum.Font.GothamSemibold
        b.TextColor3=Color3.fromRGB(237,241,225)
        b.BackgroundColor3=Color3.fromRGB(53,81,65)
        b.Size=UDim2.new(1,-16,0,54)
        b.Parent=panel
        b.Activated:Connect(function()
            if placing then return end
            placing=true
            b.Active=false
            status.Text="Procurando terreno para "..def.label.."..."
            local result=call("build",id)
            status.Text=if result.ok
                then def.label.." #"..tostring(result.buildingId)
                    .." colocado em X="..tostring(result.x)..". NPCs buscarão os materiais."
                else errorMessages[tostring(result.error)] or
                    ("Não foi possível: "..tostring(result.error))
            b.Active=true
            placing=false
        end)
    end

    local info=Instance.new("TextButton")
    info.Name="Workers"
    info.Text="Ver trabalhadores"
    info.TextSize=14
    info.TextColor3=Color3.fromRGB(245,245,227)
    info.BackgroundColor3=Color3.fromRGB(65,75,70)
    info.Size=UDim2.new(1,-16,0,40)
    info.Parent=panel
    info.Activated:Connect(function()
        local result=call("status",nil)
        if result.ok then
            local workers=result.data.workers
            local count=0
            local active=0
            for _,worker in ipairs(workers) do
                count+=1
                if worker.state~="idle" then active+=1 end
            end
            status.Text=tostring(count).." NPCs | "..tostring(active)
                .." em atividade | "..tostring(#result.data.buildings).." obras"
        else
            status.Text="Falha ao consultar trabalhadores: "..tostring(result.error)
        end
    end)
    open.Activated:Connect(function()
        panel.Visible=not panel.Visible
        open.Text=if panel.Visible then "Fechar" else "Construir"
    end)
end
return Menu
