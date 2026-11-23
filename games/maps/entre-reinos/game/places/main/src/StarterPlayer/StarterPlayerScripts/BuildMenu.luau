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
    build_too_far="Aproxime-se do local da obra.",
    outside_region="O local fica fora da região jogável.",
    occupied_by_tree="Uma árvore ocupa o local. Marque-a para corte.",
    no_worker_route="Os moradores não têm rota terrestre até o local.",
    terrain_not_ready="O terreno está carregando. Tente novamente.",
    preview_changed="Escolha o local novamente.",
    materials_already_delivered="A entrega começou e a obra está em andamento.",
    building_not_found="A obra já foi removida.",
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

local function actionButton(parent: Instance,name: string,caption: string): TextButton
    local button=Instance.new("TextButton")
    button.Name=name
    button.Text=caption
    button.Font=Enum.Font.GothamSemibold
    button.TextSize=13
    button.TextColor3=cream
    button.BackgroundColor3=Color3.fromRGB(50,64,54)
    button.BorderSizePixel=0
    button.Parent=parent
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,8)
    corner.Parent=button
    return button
end

function Menu.mount(parent: GuiObject,remote: RemoteFunction,
        notify: (string)->(),refresh: ()->(),player: Player,closeJournal: ()->()): any
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
    local hint=text(list,"Escolha o local. Os moradores levam os materiais e começam a obra após completar a entrega.",11,muted)
    hint.Size=UDim2.new(1,-12,0,48)
    hint.LayoutOrder=1

    local activeInfo=text(list,"OBRAS DA VILA  ·  nenhum projeto registrado",12,cream)
    activeInfo.LayoutOrder=2
    activeInfo.Size=UDim2.new(1,-12,0,72)
    activeInfo.TextWrapped=true
    local cancelOrder=actionButton(list,"CancelWork","")
    cancelOrder.LayoutOrder=3
    cancelOrder.Size=UDim2.new(1,-12,0,40)
    cancelOrder.Visible=false
    local cancelId: number?=nil
    local confirmCancel: number?=nil

    local overlay=Instance.new("Frame")
    overlay.Name="BuildPlacement"
    overlay.AnchorPoint=Vector2.new(0.5,1)
    overlay.Position=UDim2.new(0.5,0,1,-70)
    overlay.Size=UDim2.new(1,-30,0,86)
    overlay.BackgroundTransparency=1
    overlay.Visible=false
    overlay.Parent=parent:FindFirstAncestorOfClass("ScreenGui")
    local constraint=Instance.new("UISizeConstraint")
    constraint.MaxSize=Vector2.new(335,86)
    constraint.Parent=overlay
    local caption=text(overlay,"",13,cream)
    caption.TextXAlignment=Enum.TextXAlignment.Center
    caption.TextStrokeTransparency=0.2
    caption.Size=UDim2.new(1,0,0,38)
    local previous=actionButton(overlay,"Left","◀")
    local following=actionButton(overlay,"Right","▶")
    local confirm=actionButton(overlay,"Confirm","Confirmar")
    local leave=actionButton(overlay,"Close","Sair")
    for i,button in ipairs({previous,following,confirm,leave}) do
        button.Position=UDim2.new((i-1)*0.25,2,0,42)
        button.Size=UDim2.new(0.25,-4,0,42)
    end

    local snapshot: any=nil
    local busy=false
    local selected: string?=nil
    local candidate=0
    local previewId: number?=nil
    local ghost: Part?=nil
    local cast=RaycastParams.new()
    cast.FilterType=Enum.RaycastFilterType.Include
    cast.FilterDescendantsInstances={workspace.Terrain}
    cast.IgnoreWater=true

    local function playerX(): number?
        local character=player.Character
        local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
        return if root and root:IsA("BasePart") then root.Position.X else nil
    end

    local function call(action: string,arg: any,x: number?): any
        busy=true
        local ok,result=pcall(function() return remote:InvokeServer(action,arg,x) end)
        busy=false
        if ok and type(result)=="table" then return result end
        return {ok=false,error="connection_failed"}
    end

    local function closePreview()
        selected=nil
        previewId=nil
        overlay.Visible=false
        if ghost then ghost:Destroy() end
        ghost=nil
    end

    local function updatePreview()
        if busy or not selected then return end
        local id=selected
        local def=Structures.get(id)
        previewId=nil
        confirm.BackgroundColor3=Color3.fromRGB(79,70,66)
        caption.Text="Verificando o terreno…"
        local result=call("build_preview",id,candidate)
        if selected~=id then return end
        local x=if result.ok then result.x else candidate
        local hit=workspace:Raycast(Vector3.new(x,70,Structures.DEPTH_Z),Vector3.new(0,-120,0),cast)
        local y=if result.ok then result.y elseif hit then hit.Position.Y else 17
        local preview=ghost
        if not preview then
            preview=Instance.new("Part")
            preview.Name="ER_LocalBlueprint"
            preview.Anchored=true
            preview.CanCollide=false
            preview.CanQuery=false
            preview.CanTouch=false
            preview.CastShadow=false
            preview.Transparency=0.73
            preview.Material=Enum.Material.ForceField
            preview.Parent=workspace
            ghost=preview
        end
        preview.Size=Vector3.new(def.footprint,def.height,7)
        preview.Position=Vector3.new(x,y+def.height/2,Structures.DEPTH_Z)
        preview.Color=if result.ok then Color3.fromRGB(138,217,123) else Color3.fromRGB(248,121,105)
        if result.ok then
            previewId=result.previewId
            confirm.BackgroundColor3=Color3.fromRGB(58,101,67)
            caption.Text=def.label.." · terreno livre"
        else
            caption.Text=errors[result.error] or "Local indisponível."
        end
    end

    previous.Activated:Connect(function()
        if busy or not selected then return end
        candidate=math.max(-120,candidate-2)
        updatePreview()
    end)
    following.Activated:Connect(function()
        if busy or not selected then return end
        candidate=math.min(120,candidate+2)
        updatePreview()
    end)
    leave.Activated:Connect(closePreview)
    confirm.Activated:Connect(function()
        if busy or not selected then return end
        if not previewId then
            updatePreview()
            return
        end
        local result=call("build",previewId)
        if result.ok then
            closePreview()
            notify("Obra marcada. Os moradores vão entregar os materiais.")
            refresh()
        else
            caption.Text=errors[result.error] or "Não foi possível confirmar a obra."
        end
    end)
    overlay.Destroying:Connect(closePreview)

    cancelOrder.Activated:Connect(function()
        if busy or not cancelId then return end
        if confirmCancel~=cancelId then
            confirmCancel=cancelId
            cancelOrder.Text="Confirmar cancelamento #"..tostring(cancelId)
            return
        end
        local result=call("build_cancel",cancelId)
        confirmCancel=nil
        cancelOrder.Text="Cancelar obra #"..tostring(cancelId)
        notify(if result.ok then "Obra cancelada. Os moradores mantêm sua carga."
            else errors[result.error] or "Não foi possível cancelar a obra.")
        refresh()
    end)
    local cards: {[string]: {button: TextButton,materials: TextLabel}}={}
    for i,id in ipairs(order) do
        local def=Structures.get(id)
        local card=Instance.new("TextButton")
        card.Name="Construct_"..id
        card.LayoutOrder=i+3
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
        local marker=text(card,"LOCAR",10,amber)
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
            local x=playerX()
            if not x then
                notify(errors.character_not_ready)
                return
            end
            candidate=math.round(x)
            selected=id
            overlay.Visible=true
            closeJournal()
            updatePreview()
        end)
    end

    local api={}
    api.closePreview=closePreview
    function api.update(data: any)
        snapshot=data
        local buildings=if snapshot then snapshot.buildings else nil
        local closest: number?=nil
        local distance=Structures.PLACEMENT_RANGE
        local x=playerX()
        if x and buildings then
            for _,b in ipairs(buildings) do
                local delta=math.abs(b.x-x)
                if b.canCancel and delta<=distance then
                    distance=delta
                    closest=b.id
                end
            end
        end
        if closest~=cancelId then confirmCancel=nil end
        cancelId=closest
        cancelOrder.Visible=cancelId~=nil
        if cancelId then
            cancelOrder.Text=(if confirmCancel then "Confirmar cancelamento #" else "Cancelar obra #")
                ..tostring(cancelId)
        end
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
        local stocked=if snapshot and snapshot.resources then snapshot.resources.stored else nil
        local reserved=if snapshot and snapshot.resources then snapshot.resources.reserved else nil
        for _,id in ipairs(order) do
            local def=Structures.get(id)
            local rows={}
            local low=false
            for _,item in ipairs({"wood","stone","iron","food"}) do
                local required=def.cost[item]
                if required then
                    local inWorld=if stocks then (stocks[item] or 0)
                        +(if bags then bags[item] or 0 else 0)
                        +(if stocked then stocked[item] or 0 else 0) else 0
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
