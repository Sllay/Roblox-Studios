--!strict
-- Village construction catalog. Mounted inside the ONE game journal;
-- this is deliberately not a second ScreenGui or developer overlay.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Structures=require(ReplicatedStorage:WaitForChild("Game")
    :WaitForChild("Living"):WaitForChild("StructureDefs"))
local Menu={}
local order={"shelter","house","stockpile","fence","wall"}
local names={wood="Madeira",stone="Pedra",iron="Ferro",food="Alimento"}
local amber=Color3.fromRGB(214,175,99)
local cream=Color3.fromRGB(245,232,203)
local muted=Color3.fromRGB(178,186,166)
local errors={
    rate_limited="Aguarde um instante antes de outra obra.",
    no_available_build_site="Sem terreno livre próximo. Caminhe até outra área.",
    invalid_footprint_or_slope="Terreno úmido ou inclinado demais.",
    overlapping_footprint="Outra construção ocupa o local.",
    building_limit="Limite de construções atingido.",
    world_not_loaded="O mundo ainda está carregando.",
    character_not_ready="Aguarde seu personagem carregar.",
    outside_playable_lane="Aproxime-se da faixa jogável.",
    connection_failed="Não foi possível falar com o servidor.",
}

local function text(parent: Instance,content: string,size: number,color: Color3): TextLabel
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1
    t.Text=content
    t.Font=Enum.Font.Gotham
    t.TextSize=size
    t.TextColor3=color
    t.TextXAlignment=Enum.TextXAlignment.Left
    t.TextYAlignment=Enum.TextYAlignment.Center
    t.TextWrapped=true
    t.Parent=parent
    return t
end

function Menu.mount(parent: GuiObject,remote: RemoteFunction,
        notify: (string)->(),refresh: ()->()): any
    local list=Instance.new("ScrollingFrame")
    list.Name="ConstructionCatalog"
    list.Size=UDim2.fromScale(1,1)
    list.ScrollBarThickness=3
    list.BackgroundTransparency=1
    list.BorderSizePixel=0
    list.CanvasSize=UDim2.fromOffset(0,0)
    list.Visible=false
    list.Parent=parent
    local layout=Instance.new("UIListLayout")
    layout.Padding=UDim.new(0,9)
    layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout.Parent=list
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+16)
    end)

    local intro=text(list,"CONSTRUIR NA VILA",16,cream)
    intro.Size=UDim2.new(1,-10,0,26)
    intro.Font=Enum.Font.GothamBold
    intro.LayoutOrder=0
    local hint=text(list,"Os moradores levam recursos reais até a obra. Os valores abaixo são das fontes da região, não da sua bolsa.",11,muted)
    hint.Size=UDim2.new(1,-12,0,48)
    hint.LayoutOrder=1

    local activeInfo=text(list,"OBRAS DA VILA  ·  nenhum projeto registrado",12,cream)
    activeInfo.LayoutOrder=2
    activeInfo.Size=UDim2.new(1,-12,0,72)
    activeInfo.TextWrapped=true
    local snapshot: any=nil
    local busy=false
    local cards: {[string]: {button: TextButton,materials: TextLabel}}={}
    for i,id in ipairs(order) do
        local def=Structures.get(id)
        local card=Instance.new("TextButton")
        card.Name="Construct_"..id
        card.LayoutOrder=i+2
        card.Size=UDim2.new(1,-12,0,78)
        card.BackgroundColor3=Color3.fromRGB(50,64,54)
        card.BorderSizePixel=0
        card.AutoButtonColor=true
        card.Text=""
        card.Parent=list
        local corner=Instance.new("UICorner")
        corner.CornerRadius=UDim.new(0,9)
        corner.Parent=card
        local stroke=Instance.new("UIStroke")
        stroke.Color=Color3.fromRGB(101,112,87)
        stroke.Thickness=1
        stroke.Transparency=0.3
        stroke.Parent=card

        local title=text(card,def.label,15,cream)
        title.Font=Enum.Font.GothamSemibold
        title.Position=UDim2.fromOffset(13,7)
        title.Size=UDim2.new(1,-74,0,24)
        local marker=text(card,"CRIAR",10,amber)
        marker.Font=Enum.Font.GothamBold
        marker.TextXAlignment=Enum.TextXAlignment.Right
        marker.AnchorPoint=Vector2.new(1,0)
        marker.Position=UDim2.new(1,-12,0,10)
        marker.Size=UDim2.fromOffset(50,18)
        local materials=text(card,"",12,muted)
        materials.Position=UDim2.fromOffset(13,33)
        materials.Size=UDim2.new(1,-22,0,37)
        materials.TextYAlignment=Enum.TextYAlignment.Top
        cards[id]={button=card,materials=materials}
        card.Activated:Connect(function()
            if busy then return end
            busy=true
            card.Active=false
            local ok,result=pcall(function() return remote:InvokeServer("build",id) end)
            card.Active=true
            busy=false
            if not ok or type(result)~="table" then
                notify(errors.connection_failed)
                return
            end
            if result.ok then
                notify(def.label.." encomendada. Moradores buscarão os materiais.")
                refresh()
            else
                notify(errors[tostring(result.error)] or
                    ("Não foi possível construir: "..tostring(result.error)))
            end
        end)
    end

    local api={}
    function api.update(data: any)
        snapshot=data
        local buildings=if snapshot then snapshot.buildings else nil
        if buildings and #buildings>0 then
            local parts={}
            local shown=0
            for _,b in ipairs(buildings) do
                if b.state~="complete" then
                    shown+=1
                    if shown<=3 then
                        table.insert(parts,b.name.." #"..tostring(b.id)..
                            " · "..tostring(b.progress).."%")
                    end
                end
            end
            activeInfo.Text=if shown==0 then
                "OBRAS DA VILA  ·  "..tostring(#buildings).." concluídas"
                else "EM ANDAMENTO ("..tostring(shown)..")\n"..
                    table.concat(parts,"   ·   ")..
                    (if shown>3 then "  e mais "..tostring(shown-3) else "")
        else
            activeInfo.Text="OBRAS DA VILA  ·  nenhuma encomendada"
        end
        local stocks=if snapshot and snapshot.resources then snapshot.resources.sources else nil
        local bags=if snapshot and snapshot.resources then snapshot.resources.carried else nil
        local reserved=if snapshot and snapshot.resources then snapshot.resources.reserved else nil
        for _,id in ipairs(order) do
            local def=Structures.get(id)
            local rows={}
            local low=false
            for _,item in ipairs({"wood","stone","iron","food"}) do
                local required=def.cost[item]
                if required then
                    local inWorld=if stocks then (stocks[item] or 0)+(if bags then bags[item] or 0 else 0) else 0
                    local free=math.max(0,inWorld-(if reserved then reserved[item] or 0 else 0))
                    if stocks and free<required then low=true end
                    table.insert(rows,(names[item] or item).." "..tostring(required)
                        .." / livre ~"..(if stocks then tostring(free) else "…"))
                end
            end
            local materials=cards[id].materials
            materials.Text=table.concat(rows,"  ·  ")..
                (if low then "\nEstoque curto: moradores podem aguardar coleta." else
                    "\nMateriais reais; entrega feita pelos moradores.")
            materials.TextColor3=if low then amber else muted
        end
    end
    function api.setVisible(value: boolean)
        list.Visible=value
    end
    api.update(nil)
    return api
end
return Menu
