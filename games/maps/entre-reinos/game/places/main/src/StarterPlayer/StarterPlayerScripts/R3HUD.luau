--!strict
-- Entre Reinos, T1-R3 game HUD. One unobtrusive interface, not a debug board.
-- Sources/worker bags/committed building materials are distinct custodians.
-- Every action remains server authoritative; no custom movement/jump controls.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local BuildMenu=require(script.Parent:WaitForChild("BuildMenu"))
local Professions=require(ReplicatedStorage:WaitForChild("Game")
    :WaitForChild("Living"):WaitForChild("ProfessionDefs"))
local Gesture=require(script.Parent:WaitForChild("PressGesture"))
local WeaponControls=require(script.Parent:WaitForChild("WeaponControls"))
local DukeDialogue=require(script.Parent:WaitForChild("DukeDialogue"))
local Ballistics=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("Ballistics"))
local UI={}
local started=false

local C={
    background=Color3.fromRGB(26,38,33),
    surface=Color3.fromRGB(39,57,46),
    raised=Color3.fromRGB(49,71,55),
    stroke=Color3.fromRGB(132,143,104),
    paper=Color3.fromRGB(248,236,203),
    secondary=Color3.fromRGB(192,199,175),
    gold=Color3.fromRGB(230,184,97),
    danger=Color3.fromRGB(208,110,100),
    positive=Color3.fromRGB(149,202,147),
}
local resourceNames={wood="Madeira",stone="Pedra",iron="Ferro",food="Alimento"}
local resourceOrder={"wood","stone","iron","food"}
local errorTexts={
    rate_limited="Aguarde um instante.",
    no_arrows="Sem flechas. Fabrique perto de uma fonte de madeira.",
    no_target="Nenhum inimigo ao alcance.",
    too_far_from_coin="Chegue mais perto da moeda.",
    already_claimed="Essa moeda já foi recolhida.",
    drop_not_found="Moeda não encontrada.",
    invalid_coin_drop="Não há moedas disponíveis na bolsa.",
    treasury_empty="O tesouro da vila está sem moedas.",
    resource_unavailable="Leve madeira na bolsa ou abasteça um galpão próximo.",
    wood_stock_required="Faltam 2 madeiras na bolsa. Colete na árvore ou no galpão.",
    wood_source_too_far="Sem madeira próxima. Siga a indicação da árvore na oficina.",
    player_bag_full="Sua bolsa está cheia. Use a madeira antes de recolher mais.",
    ammo_capacity="Aljava cheia: gaste flechas antes de fabricar.",
    too_far_from_market="Troque recursos perto do centro da vila.",
    not_enough_equipment_materials="Faltam materiais para equipar.",
    too_far_from_defender="Aproxime-se do morador escolhido.",
    action_unavailable="Essa ordem não pode ser executada agora.",
    too_far_from_story="Aproxime-se da escolta ou do castelo.",
    already_equipped="Morador já equipado. Para recarregar um arco vazio, traga seis flechas.",
    too_many_arrows="Aguarde as flechas em voo.",
    invalid_weapon="Selecione uma arma.",
    hold_too_short="Segure a interação até preencher a barra.",
    dialogue_open="Feche o diálogo para voltar ao jogo.",

    character_not_ready="Aguarde o personagem carregar.",
    world_not_loaded="O mundo está carregando.",
}

local function rounded(parent: Instance,radius: number,border: boolean?)
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,radius)
    corner.Parent=parent
    if border then
        local stroke=Instance.new("UIStroke")
        stroke.Color=C.stroke
        stroke.Transparency=0.48
        stroke.Thickness=1
        stroke.Parent=parent
    end
end
local function label(parent: Instance,name: string,content: string,
        fontSize: number,color: Color3): TextLabel
    local t=Instance.new("TextLabel")
    t.Name=name
    t.BackgroundTransparency=1
    t.Text=content
    t.Font=Enum.Font.Gotham
    t.TextSize=fontSize
    t.TextColor3=color
    t.TextWrapped=true
    t.TextXAlignment=Enum.TextXAlignment.Left
    t.TextYAlignment=Enum.TextYAlignment.Center
    t.Parent=parent
    return t
end
local function button(parent: Instance,name: string,title: string): TextButton
    local b=Instance.new("TextButton")
    b.Name=name
    b.Text=title
    b.Font=Enum.Font.GothamSemibold
    b.TextSize=12
    b.TextColor3=C.paper
    b.BackgroundColor3=C.raised
    b.BorderSizePixel=0
    b.AutoButtonColor=true
    b.Parent=parent
    rounded(b,9,true)
    return b
end
local function panel(parent: Instance,name: string,bg: Color3): Frame
    local f=Instance.new("Frame")
    f.Name=name
    f.BackgroundColor3=bg
    f.BorderSizePixel=0
    f.Parent=parent
    rounded(f,11,true)
    return f
end
local function scroll(parent: Instance,name: string): ScrollingFrame
    local f=Instance.new("ScrollingFrame")
    f.Name=name
    f.BackgroundTransparency=1
    f.ScrollBarThickness=3
    f.BorderSizePixel=0
    f.Size=UDim2.fromScale(1,1)
    f.CanvasSize=UDim2.fromOffset(0,0)
    f.Parent=parent
    local l=Instance.new("UIListLayout")
    l.SortOrder=Enum.SortOrder.LayoutOrder
    l.Padding=UDim.new(0,8)
    l.Parent=f
    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        f.CanvasSize=UDim2.fromOffset(0,l.AbsoluteContentSize.Y+12)
    end)
    return f
end
local function rowText(parent: Instance,name: string,content: string,
        order: number,height: number): TextLabel
    local t=label(parent,name,content,12,C.secondary)
    t.LayoutOrder=order
    t.Size=UDim2.new(1,-12,0,height)
    return t
end

function UI.start(player: Player)
    if started then return end
    started=true
    local remote=ReplicatedStorage:WaitForChild("Game"):WaitForChild("ER_LivingActions",12)
    if not remote or not remote:IsA("RemoteFunction") then
        warn("[EntreReinos] Gameplay world remote missing")
        return
    end

    local gui=Instance.new("ScreenGui")
    gui.Name="ER_R3HUD"
    gui.IgnoreGuiInset=false
    gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
    gui.DisplayOrder=7
    gui.ResetOnSpawn=false
    gui.Parent=player:WaitForChild("PlayerGui")

    -- A short top strip; everything else is either contextual or collapsible.
    local top=panel(gui,"KingdomVitals",C.background)
    top.AnchorPoint=Vector2.new(0.5,0)
    top.Position=UDim2.new(0.5,0,0,7)
    top.Size=UDim2.fromOffset(340,35)
    top.BackgroundTransparency=0.14
    local vitals=label(top,"Vitals","DIA 1  ·  Moedas 0  ·  Flechas 12",13,C.paper)
    vitals.Font=Enum.Font.GothamSemibold
    vitals.TextXAlignment=Enum.TextXAlignment.Center
    vitals.Size=UDim2.new(1,-16,1,0)

    local stockBar=panel(gui,"VillageStock",C.background)
    stockBar.AnchorPoint=Vector2.new(0.5,0)
    stockBar.Position=UDim2.new(0.5,0,0,49)
    stockBar.Size=UDim2.fromOffset(420,25)
    stockBar.BackgroundTransparency=0.2
    local stock=label(stockBar,"Stock","FONTES DA VILA  ·  consultando…",11,C.secondary)
    stock.Size=UDim2.new(1,-12,1,0)
    stock.TextXAlignment=Enum.TextXAlignment.Center

    local openJournal=button(gui,"VillageButton","VILA")
    openJournal.Position=UDim2.fromOffset(12,7)
    openJournal.Size=UDim2.fromOffset(76,35)
    openJournal.BackgroundColor3=C.background

    local journal=panel(gui,"VillageJournal",C.background)
    journal.Position=UDim2.fromOffset(12,48)
    journal.Size=UDim2.new(0,300,0.70,0)
    journal.Visible=false
    journal.ClipsDescendants=true
    local maxSize=Instance.new("UISizeConstraint")
    maxSize.MaxSize=Vector2.new(310,490)
    maxSize.MinSize=Vector2.new(240,225)
    maxSize.Parent=journal
    local head=label(journal,"JournalTitle","CADERNO DA VILA",16,C.paper)
    head.Font=Enum.Font.GothamBold
    head.Position=UDim2.fromOffset(15,8)
    head.Size=UDim2.new(1,-61,0,33)
    local close=button(journal,"Close","×")
    close.AnchorPoint=Vector2.new(1,0)
    close.Position=UDim2.new(1,-10,0,10)
    close.Size=UDim2.fromOffset(29,29)
    close.BackgroundColor3=C.surface

    local tabs=Instance.new("Frame")
    tabs.Name="Sections"
    tabs.BackgroundTransparency=1
    tabs.Position=UDim2.fromOffset(11,50)
    tabs.Size=UDim2.new(1,-22,0,34)
    tabs.Parent=journal
    local tabLayout=Instance.new("UIListLayout")
    tabLayout.FillDirection=Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    tabLayout.SortOrder=Enum.SortOrder.LayoutOrder
    tabLayout.Padding=UDim.new(0,4)
    tabLayout.Parent=tabs

    local content=Instance.new("Frame")
    content.Name="JournalContent"
    content.BackgroundTransparency=1
    content.Position=UDim2.fromOffset(12,93)
    content.Size=UDim2.new(1,-24,1,-145)
    content.ClipsDescendants=true
    content.Parent=journal

    local exitWorld=button(journal,"SaveAndReturn","SALVAR E VOLTAR")
    exitWorld.AnchorPoint=Vector2.new(0.5,1)
    exitWorld.Position=UDim2.new(0.5,0,1,-10)
    exitWorld.Size=UDim2.new(1,-24,0,34)
    exitWorld.BackgroundColor3=C.surface

    local toast=label(gui,"GameFeedback","",13,C.paper)
    toast.TextXAlignment=Enum.TextXAlignment.Center
    toast.TextStrokeColor3=Color3.new(0,0,0)
    toast.TextStrokeTransparency=0.18
    toast.AnchorPoint=Vector2.new(0.5,1)
    toast.Position=UDim2.new(0.5,0,0,148)
    toast.Size=UDim2.new(0,400,0,42)
    toast.Visible=false
    local toastSerial=0
    local function notify(message: string)
        toastSerial+=1
        local token=toastSerial
        toast.Text=message
        toast.Visible=true
        task.delay(3.2,function()
            if token==toastSerial then toast.Visible=false end
        end)
    end

    local returning=false
    exitWorld.Activated:Connect(function()
        if returning then return end
        local slots=ReplicatedStorage.Game:FindFirstChild("ER_WorldSlots")
        if not slots or not slots:IsA("RemoteFunction") then
            notify("Conexão com o mundo indisponível.")
            return
        end
        returning=true
        exitWorld.Text="SALVANDO…"
        local ok,answer=pcall(function() return slots:InvokeServer("return") end)
        if not ok or type(answer)~="table" or not answer.ok then
            returning=false
            exitWorld.Text="SALVAR E VOLTAR"
            notify(if ok and type(answer)=="table" and answer.error=="teleport_request_failed"
                then "Progresso salvo. A volta ao lobby falhou."
                else "Não foi possível confirmar a saída. Tente novamente.")
            return
        end
        exitWorld.Text="VOLTANDO…"
        task.delay(12,function()
            if not gui.Parent then return end
            returning=false
            exitWorld.Text="SALVAR E VOLTAR"
        end)
    end)

    local snapshot: any=nil
    local nearby: any={}
    local hud: any={}
    local busy=false
    local refreshInFlight=false
    local tab="build"
    local tabsUI: {[string]: TextButton}={}
    local pages: {[string]: GuiObject}={}
    local builders: any=nil
    local closeJournal: ()->()=function() end

    local refreshStatus: ()->()
    local function request(action: string,arg: any?)
        if busy then return end
        busy=true
        local ok,result=pcall(function()
            return remote:InvokeServer(action,arg)
        end)
        busy=false
        if not ok or type(result)~="table" then
            notify("Conexão com o mundo interrompida. Tente novamente.")
            return
        end
        if not result.ok then
            local key=tostring(result.error)
            notify(errorTexts[key] or ("Não foi possível: "..key))
            return
        end
        if action=="attack" then
            if result.hit==true then notify("Inimigo atingido.") end
        elseif action=="bow" then
            notify("Flecha disparada.")
        elseif action=="trade" then
            notify("Madeira vendida; moedas recebidas do tesouro.")
        elseif action=="craft_arrows" then
            notify("Seis flechas fabricadas: duas madeiras consumidas.")
        elseif action=="take_wood" then
            notify("Duas madeiras recolhidas na sua bolsa.")
        elseif action=="arm_defender" then
            notify("Morador equipado para defesa.")
        elseif action=="pickup_coin" then
            notify("Moeda recolhida.")
        elseif action=="drop_coin" then
            notify("Uma moeda deixada no chão.")
        elseif action=="prologue" then
            notify("Ordem confirmada.")
        end
        task.defer(function() refreshStatus() end)
    end

    local builds=BuildMenu.mount(content,remote,notify,function()
        task.defer(function() refreshStatus() end)
    end,player,function() closeJournal() end)
    builders=builds
    pages.build=content:FindFirstChild("ConstructionCatalog") :: GuiObject

    local resourcesPage=scroll(content,"ResourceLedger")
    resourcesPage.Visible=false
    pages.resources=resourcesPage
    local resTitle=rowText(resourcesPage,"Title","ESTOQUES REAIS DA REGIÃO",1,30)
    resTitle.Font=Enum.Font.GothamBold
    resTitle.TextSize=15
    resTitle.TextColor3=C.paper
    local resHint=rowText(resourcesPage,"Hint",
        "Fontes são depósitos naturais; bolsas são materiais que NPCs estão carregando. Recursos aplicados às obras não estão mais livres.",2,58)
    resHint.TextColor3=C.secondary
    local resourceCards: {[string]: TextLabel}={}
    for i,id in ipairs(resourceOrder) do
        local t=rowText(resourcesPage,"Resource_"..id,"",i+2,72)
        t.TextColor3=C.paper
        resourceCards[id]=t
    end

    local villagersPage=scroll(content,"Villagers")
    villagersPage.Visible=false
    pages.villagers=villagersPage
    local villTitle=rowText(villagersPage,"Title","MORADORES DA VILA",1,30)
    villTitle.TextSize=15
    villTitle.Font=Enum.Font.GothamBold
    villTitle.TextColor3=C.paper
    local villHelp=rowText(villagersPage,"Help",
        "Equipe um morador próximo. Arco: 3 madeira. Lança: 2 ferro. Use a bolsa ou o estoque local.",2,53)
    local workerRows: {[number]: TextButton}={}
    local selectedNpcId=0
    local updateVillage: ()->()
    local selectedWorker=label(villagersPage,"Selected","Selecione um morador.",12,C.secondary)
    selectedWorker.LayoutOrder=500
    selectedWorker.Size=UDim2.new(1,-10,0,43)

    local equipBar=Instance.new("Frame")
    equipBar.Name="Equipment"
    equipBar.BackgroundTransparency=1
    equipBar.LayoutOrder=501
    equipBar.Size=UDim2.new(1,-8,0,40)
    equipBar.Parent=villagersPage
    local equipBow=button(equipBar,"EquipBow","ARCO")
    equipBow.Size=UDim2.new(0.49,0,1,0)
    local equipSpear=button(equipBar,"EquipSpear","LANÇA")
    equipSpear.Position=UDim2.new(0.51,0,0,0)
    equipSpear.Size=UDim2.new(0.49,0,1,0)
    local function equip(weapon: string)
        if selectedNpcId==0 then notify("Escolha primeiro um morador.");return end
        if nearby.npcId~=selectedNpcId then
            notify("Aproxime-se do morador antes de equipá-lo.")
            return
        end
        request("arm_defender",tostring(selectedNpcId)..":"..weapon)
    end
    equipBow.Activated:Connect(function() equip("bow") end)
    equipSpear.Activated:Connect(function() equip("spear") end)

    local workshop=scroll(content,"VillageWorkshop")
    workshop.Visible=false
    pages.workshop=workshop
    local craftTitle=rowText(workshop,"Title","OFICINA E COMÉRCIO",1,30)
    craftTitle.TextSize=15
    craftTitle.Font=Enum.Font.GothamBold
    craftTitle.TextColor3=C.paper
    local craftInfo=rowText(workshop,"AmmoInfo","",2,97)
    local collectButton=button(workshop,"TakeWood","RECOLHER 2 MADEIRAS")
    collectButton.LayoutOrder=3
    collectButton.Size=UDim2.new(1,-12,0,42)
    local craftButton=button(workshop,"CraftArrows","FABRICAR 6 FLECHAS")
    craftButton.LayoutOrder=4
    craftButton.Size=UDim2.new(1,-12,0,42)
    local tradeInfo=rowText(workshop,"TradeInfo","",5,67)
    local tradeButton=button(workshop,"SellWood","VENDER 1 MADEIRA")
    tradeButton.LayoutOrder=6
    tradeButton.Size=UDim2.new(1,-12,0,42)
    local coinsInfo=rowText(workshop,"PurseInfo","",7,62)
    local dropCoin=button(workshop,"DropCoin","SOLTAR 1 MOEDA")
    dropCoin.LayoutOrder=8
    dropCoin.Size=UDim2.new(1,-12,0,42)

    collectButton.Activated:Connect(function()
        if (nearby.wood or 0)>=2 then
            request("take_wood",nil)
        else
            local dist=nearby.nearestWoodDistance or -1
            if dist>=0 then
                notify("Árvore com madeira a "..tostring(dist).." studs à "..
                    tostring(nearby.nearestWoodDirection)..".")
            else
                notify("Madeira esgotada nas fontes conhecidas.")
            end
        end
    end)
    craftButton.Activated:Connect(function()
        if (hud.playerWood or 0)<2 and nearby.canCraftArrows~=true then
            local dist=nearby.nearestWoodDistance or -1
            if dist>=0 then
                notify("Madeira disponível "..tostring(dist).." studs à "..
                    tostring(nearby.nearestWoodDirection)..". Aproxime-se e recolha.")
            else
                notify("Faltam duas madeiras na bolsa ou num galpão próximo.")
            end
            return
        end
        request("craft_arrows",nil)
    end)
    tradeButton.Activated:Connect(function() request("trade","wood") end)
    dropCoin.Activated:Connect(function() request("drop_coin",nil) end)

    local entries={
        {"build","OBRAS"},
        {"resources","ESTOQUE"},
        {"villagers","PESSOAS"},
        {"workshop","OFICINA"},
    }
    for i,item in ipairs(entries) do
        local b=button(tabs,"Tab_"..item[1],item[2])
        b.LayoutOrder=i
        b.Size=UDim2.new(0.25,-4,1,0)
        b.TextSize=10
        tabsUI[item[1]]=b
    end
    local function showTab(nextTab: string)
        tab=nextTab
        for key,page in pairs(pages) do page.Visible=(key==tab) end
        for key,b in pairs(tabsUI) do
            b.BackgroundColor3=if key==tab then C.raised else C.surface
            b.TextColor3=if key==tab then C.gold else C.secondary
        end
    end
    for _,item in ipairs(entries) do
        local key=item[1]
        tabsUI[key].Activated:Connect(function() showTab(key) end)
    end
    showTab("build")
    local refreshContext: ()->()=function() end

    local function showJournal(value: boolean,nextTab: string?)
        if value then builds.closePreview() end
        journal.Visible=value
        openJournal.Text=if value then "FECHAR" else "VILA"
        if nextTab then showTab(nextTab) end
        if value then task.defer(function() refreshStatus() end) end
        refreshContext()
    end
    closeJournal=function() showJournal(false,nil) end
    openJournal.Activated:Connect(function()
        showJournal(not journal.Visible,if not journal.Visible then "build" else nil)
    end)
    close.Activated:Connect(function() showJournal(false,nil) end)

    -- The right edge owns action controls. Native jump and thumbstick remain
    -- in the bottom corners, and the live scene is unobstructed in the middle.
    local combat=Instance.new("Frame")
    combat.Name="CombatControls"
    combat.BackgroundTransparency=1
    combat.AnchorPoint=Vector2.new(1,0.5)
    combat.Position=UDim2.new(1,-10,0.54,0)
    combat.Size=UDim2.fromOffset(114,106)
    combat.Parent=gui
    local sword=button(combat,"SwordSlot","1 ESPADA")
    sword.Size=UDim2.fromOffset(56,44)
    sword.TextSize=10
    local bow=button(combat,"BowSlot","2 ARCO")
    bow.Position=UDim2.fromOffset(58,0)
    bow.Size=UDim2.fromOffset(56,44)
    bow.TextSize=10
    local attack=button(combat,"Attack","ATACAR")
    attack.Position=UDim2.fromOffset(0,49)
    attack.Size=UDim2.fromOffset(114,48)
    attack.BackgroundColor3=Color3.fromRGB(105,65,48)
    attack.TextSize=12

    local function call(action: string,arg: any): any
        local ok,result=pcall(function() return remote:InvokeServer(action,arg) end)
        if not ok or type(result)~="table" then
            notify("Conexão interrompida. Tente novamente.")
            return {ok=false}
        end
        if not result.ok and action~="tree_cancel" and action~="bow_cancel" then
            notify(errorTexts[tostring(result.error)] or "Essa ação está indisponível.")
        end
        return result
    end
    local cancelAttack=WeaponControls.mount(player,attack,sword,bow,call,notify)

    local interact=button(gui,"ContextAction","INTERAGIR")
    interact.AnchorPoint=Vector2.new(1,1)
    interact.Position=UDim2.new(1,-10,0.54,-58)
    interact.Size=UDim2.fromOffset(114,46)
    interact.TextSize=10
    interact.BackgroundColor3=C.surface
    interact.Visible=false
    local track=Instance.new("Frame")
    track.Position=UDim2.new(0,6,1,-5)
    track.Size=UDim2.new(1,-12,0,2)
    track.BackgroundColor3=C.raised
    track.BorderSizePixel=0
    track.Visible=false
    track.Parent=interact
    local fill=Instance.new("Frame")
    fill.BackgroundColor3=C.gold
    fill.BorderSizePixel=0
    fill.Size=UDim2.fromScale(0,1)
    fill.Parent=track
    local contextKind="none"
    local contextTarget: any=0
    local pressedTree: any=nil
    local talking=false
    local function paintActions()
        local open=not talking and not journal.Visible and player:GetAttribute("ER_LocalPlacement")~=true
        combat.Visible=open
        attack.Visible=open
        if not open then cancelAttack() end
        interact.Visible=open and contextKind~="none"
        openJournal.Visible=not talking
    end
    player:GetAttributeChangedSignal("ER_LocalPlacement"):Connect(paintActions)
    local openDialogue,closeDialogue=DukeDialogue.mount(gui,call,function(value)
        talking=value
        paintActions()
    end)
    player.CharacterRemoving:Connect(closeDialogue)

    local function interactNow()
        if contextKind=="coin" then
            request("pickup_coin",contextTarget)
        elseif contextKind=="npc" then
            selectedNpcId=contextTarget
            showJournal(true,"villagers")
        elseif contextKind=="structure" then
            for _,building in ipairs(snapshot and snapshot.buildings or {}) do
                if building.id==contextTarget then
                    local labels={complete="Pronto",blueprint="Entregas",building="Em obra",damaged="Danificado",ruined="Ruína"}
                    notify(building.name.." · "..(labels[building.state] or building.state))
                    break
                end
            end
            showJournal(true,"build")
        elseif contextKind=="wood" then
            request("take_wood",nil)
        elseif contextKind=="craft" then
            request("craft_arrows",nil)
        elseif contextKind=="market" then
            showJournal(true,"workshop")
        elseif contextKind=="story" then
            local phase=player:GetAttribute("ER_R3Phase")
            if phase=="guard" then openDialogue()
            elseif phase=="evacuation" then request("prologue","evacuate")
            elseif phase=="coronation" then request("prologue","coronation") end
        end
    end
    local function finishTree(press: any)
        if not press.ticket then return end
        if press.cancelled or pressedTree~=press then
            call("tree_cancel",press.ticket)
            return
        end
        pressedTree=nil
        track.Visible=false
        local action=if press.duration>=0.8 then "tree_mark" else "tree_take"
        local result=call(action,press.ticket)
        if result.ok then
            if action=="tree_mark" then
                notify(if result.marked then "Árvore marcada." else "Marcação removida.")
            else notify("Madeira recolhida.") end
            task.defer(function() refreshStatus() end)
        end
    end
    local pressedKind=""
    local pressedTarget: any=nil
    local cancelInteract=Gesture.bind(interact,function()
        pressedKind=contextKind
        pressedTarget=contextTarget
        if contextKind~="tree" then return end
        if pressedTree then
            pressedTree.cancelled=true
            local previous=pressedTree
            task.spawn(finishTree,previous)
        end
        local press={treeId=contextTarget,at=os.clock(),duration=0}
        pressedTree=press
        fill.Size=UDim2.fromScale(0,1)
        track.Visible=true
        task.spawn(function()
            local result=call("tree_press",press.treeId)
            if not result.ok then
                if pressedTree==press then pressedTree=nil;track.Visible=false end
                return
            end
            press.ticket=result.id
            if press.released or press.cancelled or pressedTree~=press then finishTree(press) end
        end)
    end,function(cancelled)
        local press=pressedTree
        if press then
            press.cancelled=cancelled or contextTarget~=press.treeId
            press.duration=os.clock()-press.at
            press.released=true
            track.Visible=false
            task.spawn(finishTree,press)
        elseif not cancelled and contextKind==pressedKind
            and contextTarget==pressedTarget and contextKind~="tree" then
            task.spawn(interactNow)
        end
    end,{Enum.KeyCode.E,Enum.KeyCode.ButtonY})
    RunService.RenderStepped:Connect(function()
        local press=pressedTree
        if not press or press.released then return end
        local duration=os.clock()-press.at
        if duration>Ballistics.MAX_HOLD then cancelInteract();return end
        fill.Size=UDim2.fromScale(math.clamp(duration/0.8,0,1),1)
    end)
    local highlight=Instance.new("Highlight")
    highlight.FillTransparency=1
    highlight.OutlineTransparency=0.32
    highlight.OutlineColor=C.gold
    highlight.DepthMode=Enum.HighlightDepthMode.Occluded
    highlight.Parent=workspace
    local function highlightTarget()
        local world=workspace:FindFirstChild("ER_LivingWorld")
        local name=if contextKind=="tree" then "HarvestableTree_"..tostring(contextTarget) else nil
        local target=if world and name then world:FindFirstChild(name) else nil
        if world and contextKind=="structure" then
            for _,model in ipairs(world:GetChildren()) do
                if model:GetAttribute("ER_BuildingId")==contextTarget then target=model;break end
            end
        end
        highlight.Adornee=target
        highlight.Enabled=target~=nil and interact.Visible
    end

    local warning=label(gui,"RaidBanner","",12,C.gold)
    warning.AnchorPoint=Vector2.new(0.5,0)
    warning.Position=UDim2.new(0.5,0,0,78)
    warning.Size=UDim2.new(1,-24,0,42)
    warning.TextWrapped=true
    local maxWarning=Instance.new("UISizeConstraint")
    maxWarning.MaxSize=Vector2.new(510,42)
    maxWarning.Parent=warning
    warning.TextStrokeColor3=Color3.new(0,0,0)
    warning.TextStrokeTransparency=0.3
    warning.TextXAlignment=Enum.TextXAlignment.Center
    warning.Visible=false

    local function redraw()
        local day=player:GetAttribute("ER_R3Day") or 1
        local night=player:GetAttribute("ER_R3Night")==true
        local wallet=player:GetAttribute("ER_R3Wallet") or 0
        local arrows=player:GetAttribute("ER_R3Arrows") or 0
        local enemies=player:GetAttribute("ER_R3Enemies") or 0
        local phase=player:GetAttribute("ER_R3Phase") or "sandbox"
        local isRaid=player:GetAttribute("ER_R3Raid")==true
        local message=player:GetAttribute("ER_R3Warning")
        vitals.Text="DIA "..tostring(day)..(if night then " · NOITE" else " · SOL")..
            " · MOEDAS "..tostring(wallet).." · FLECHAS "..tostring(arrows)..
            " · BOLSA MAD "..tostring(hud.playerWood or 0)
        if type(message)~="string" then message="" end
        local recovering=player:GetAttribute("ER_Recovering")==true
        warning.Visible=recovering or phase~="sandbox" or isRaid
            or player:GetAttribute("ER_R3Forecast")==true
        warning.Text=if talking then "" elseif recovering then "Você caiu. A guarda o levará de volta ao castelo."
            elseif isRaid and phase=="sandbox" then
                "INVASÃO · "..tostring(enemies).." ameaças · "..message
            elseif phase=="guard" and message=="" then "Use a interação para iniciar o prólogo."
            else message

    end

    local orderButton=button(workshop,"StoryOrder","CONTINUAR O PRÓLOGO")
    orderButton.LayoutOrder=9
    orderButton.Size=UDim2.new(1,-12,0,42)
    orderButton.Visible=false
    orderButton.Activated:Connect(function()
        local phase=player:GetAttribute("ER_R3Phase")
        if phase=="evacuation" then request("prologue","evacuate")
        elseif phase=="coronation" then request("prologue","coronation")
        else notify("Nenhuma ordem especial disponível.") end
    end)

    local function updateContext()
        contextKind="none"
        contextTarget=0
        local phase=player:GetAttribute("ER_R3Phase")
        if nearby.storyAction and (phase=="guard" or phase=="evacuation" or phase=="coronation") then
            contextKind="story"
            interact.Text=if phase=="guard" then "FALAR COM DUQUE"
                else if phase=="evacuation" then "EVACUAR"
                else "ACEITAR COROA"
        elseif (nearby.coinId or 0)>0 then
            contextKind="coin"
            contextTarget=nearby.coinId
            interact.Text="RECOLHER MOEDA"
        elseif nearby.treeId then
            contextKind="tree"
            contextTarget=nearby.treeId
            interact.Text=if nearby.treeMarked then "ÁRVORE\nSegure: desmarcar" else "ÁRVORE\nSegure: marcar"
        elseif (nearby.npcId or 0)>0 then
            contextKind="npc"
            contextTarget=nearby.npcId
            interact.Text="MORADOR"
        elseif nearby.buildingId then
            contextKind="structure"
            contextTarget=nearby.buildingId
            interact.Text="ESTRUTURA"
        elseif (nearby.wood or 0)>=2 then
            contextKind="wood"
            interact.Text="PEGAR MADEIRA"
        elseif (hud.playerWood or 0)>=2 and (hud.arrows or 0)<=24 then
            contextKind="craft"
            interact.Text="CRIAR FLECHAS"
        elseif nearby.canTrade then
            contextKind="market"
            interact.Text="MERCADO"
        end
        if pressedTree and contextTarget~=pressedTree.treeId then cancelInteract() end
        paintActions()
        highlightTarget()
    end
    refreshContext=updateContext

    function updateVillage()
        local resources=if snapshot then snapshot.resources else nil
        local sources=if resources then resources.sources else nil
        local carried=if resources then resources.carried else nil
        local reserved=if resources then resources.reserved else nil
        local committed=if resources then resources.committed else nil
        local stocked=if resources then resources.stored else nil
        local isolated=if resources then resources.isolated else nil
        if not sources then
            stock.Text="FONTES DA VILA  ·  consultando..."
        else
            stock.Text=(nearby.district or "Vila").."  ·  MADEIRA "..tostring(sources.wood or 0).."+"..
                tostring(if stocked then stocked.wood or 0 else 0)..
                "   PEDRA "..tostring(sources.stone or 0)..
                "   FERRO "..tostring(sources.iron or 0)..
                "   COMIDA "..tostring(sources.food or 0)
        end
        if (nearby.localThreats or 0)>0 then
            stock.Text=(nearby.district or "Vila").." · "..tostring(nearby.localThreats).." ameaças próximas"
        end
        for _,item in ipairs(resourceOrder) do
            local t=resourceCards[item]
            t.Text=(resourceNames[item] or item)..
                "\nFontes "..tostring(if sources then sources[item] or 0 else "?")..
                "  ·  Nas bolsas "..tostring(if carried then carried[item] or 0 else "?")..
                "\nReservado "..tostring(if reserved then reserved[item] or 0 else "?")..
                "  ·  Aplicado "..tostring(if committed then committed[item] or 0 else "?")..
                "  ·  No galpão "..tostring(if stocked then stocked[item] or 0 else "?")..
                (if isolated and (isolated[item] or 0)>0 then
                    "\nIsolado nas ruínas "..tostring(isolated[item]) else "")
        end
        if builders then builders.update(snapshot) end

        local active: {[number]: boolean}={}
        local workers=if snapshot then snapshot.workers else nil
        if workers then
            for _,w in ipairs(workers) do
                active[w.id]=true
                local b=workerRows[w.id]
                if not b then
                    b=button(villagersPage,"Citizen_"..tostring(w.id),"")
                    b.LayoutOrder=10+w.id
                    b.Size=UDim2.new(1,-12,0,58)
                    workerRows[w.id]=b
                    local workerId=w.id
                    b.Activated:Connect(function()
                        selectedNpcId=workerId
                        showTab("villagers")
                        updateVillage()
                    end)
                end
                local stateName={
                    gather="coletando",deliver="transportando",build="construindo",
                    idle="disponível",rest="descansando",
                    store_gather="buscando estoque",store_deliver="levando ao galpão",
                    collect="coletando",load="retirando estoque",flee="em fuga",
                    sheltered="abrigado",dead="morto",strike="defendendo"}
                local role=if w.defense=="bow" then " · arqueiro"
                    else if w.defense=="spear" then " · lanceiro" else ""
                local profession=Professions.get(w.profession)
                local roleLabel=if profession then profession.label else w.profession
                b.Text=w.name.."  ·  "..roleLabel..role..
                    (if w.defense=="bow" then " · "..tostring(w.arrows).." flechas" else "")..
                    "\n"..(stateName[w.state] or tostring(w.state))..
                    "  ·  carga "..tostring(math.floor(w.carryWeight)).." u."..
                    (if w.district then " · "..w.district else "")
                b.TextColor3=if w.id==selectedNpcId then C.gold else C.paper
                b.Visible=true
            end
        end
        for id,b in pairs(workerRows) do
            if not active[id] then b.Visible=false end
        end
        local nearSelected=nearby.npcId==selectedNpcId and selectedNpcId>0
        selectedWorker.Text=if selectedNpcId==0 then "Toque em um morador para ver sua defesa."
            else if nearSelected then "Morador próximo: você pode equipá-lo."
            else "Selecione um morador próximo para equipar."
        equipBar.Visible=nearSelected
        local dist=nearby.nearestWoodDistance or -1
        local direction=if dist>=0 then
            "Árvore: "..tostring(dist).." studs à "..
                tostring(nearby.nearestWoodDirection or "esquerda")
            else "Nenhuma árvore com estoque restante"
        local bagWood=hud.playerWood or 0
        local siteWood=nearby.wood or 0
        craftInfo.Text="RECEITA: 2 MADEIRAS → 6 FLECHAS"..
            "\nSua bolsa: "..tostring(bagWood).." madeira(s)  ·  Próximo: "..
            tostring(siteWood)..
            "\n"..direction
        collectButton.Text=if siteWood>=2 then "PEGAR 2 MADEIRAS DA FONTE"
            else "LOCALIZAR MADEIRA"
        -- Clicking an unavailable recipe must explain WHY, not silently
        -- swallow input by disabling a game action.
        collectButton.Active=true
        craftButton.Active=true
        collectButton.BackgroundColor3=if siteWood>=2 then C.raised else C.surface
        local canCraft=(bagWood>=2 or nearby.canCraftArrows==true) and
            (player:GetAttribute("ER_R3Arrows") or 0)<=24
        craftButton.BackgroundColor3=if canCraft then C.raised else C.surface
        local tradeStatus=if not nearby.canTrade then "Aproxime-se do centro da vila."
            elseif (hud.treasury or 0)<1 then "O tesouro não tem moedas."
            elseif not nearby.canSellWood then "Traga madeira na bolsa ou abasteça um galpão próximo."
            else "Madeira disponível para venda."
        tradeInfo.Text="1 MADEIRA POR 1 MOEDA\n"..tradeStatus
        tradeButton.BackgroundColor3=if nearby.canTrade and nearby.canSellWood
            and (hud.treasury or 0)>=1 then C.raised else C.surface
        coinsInfo.Text="SUA BOLSA  ·  "..tostring(player:GetAttribute("ER_R3Wallet") or 0)..
            " moedas. Soltar uma moeda deixa um item físico no chão."
        dropCoin.Active=(player:GetAttribute("ER_R3Wallet") or 0)>0
        dropCoin.BackgroundColor3=if dropCoin.Active then C.raised else C.surface
        local phase=player:GetAttribute("ER_R3Phase")
        orderButton.Visible=nearby.storyAction=="evacuate" or nearby.storyAction=="coronation"
        orderButton.Text=if phase=="evacuation" then "EVACUAR MORADORES"
            else "ACEITAR A COROA"
        updateContext()
    end

    function refreshStatus()
        if refreshInFlight then return end
        refreshInFlight=true
        local ok,response=pcall(function()
            return remote:InvokeServer("status",nil)
        end)
        refreshInFlight=false
        if not ok or type(response)~="table" or not response.ok then return end
        snapshot=response.data
        nearby=if type(response.nearby)=="table" then response.nearby else {}
        hud=if type(response.hud)=="table" then response.hud else {}
        redraw()
        updateVillage()
    end
    -- 1 read-only overview every 3 s, not a network request each frame.
    task.spawn(function()
        while gui.Parent and player.Parent do
            refreshStatus()
            task.wait(3)
        end
    end)

    for _,name in ipairs({"ER_R3Day","ER_R3Night","ER_R3Enemies",
        "ER_R3Wallet","ER_R3Arrows","ER_R3Warning","ER_R3Phase",
        "ER_R3Raid","ER_R3Forecast","ER_Recovering"}) do
        player:GetAttributeChangedSignal(name):Connect(function()
            redraw()
            if name=="ER_R3Phase" then updateVillage() end
        end)
    end
    UserInputService.InputBegan:Connect(function(input: InputObject,processed: boolean)
        if processed or not gui.Parent then return end
        if talking then
            if input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB then closeDialogue() end
            return
        end
        if input.KeyCode==Enum.KeyCode.V then showJournal(not journal.Visible,nil) end
    end)

    -- Local animation only. The server keeps each coin's ID and pickup value.
    local coinVfx: {[BasePart]: {base: CFrame,created: number}}={}
    local function addCoin(part: Instance)
        if part:IsA("BasePart") and type(part:GetAttribute("ER_CoinId"))=="number" then
            coinVfx[part]={base=part.CFrame,created=os.clock()}
        end
    end
    task.spawn(function()
        local folder=workspace:WaitForChild("ER_LivingWorld",20)
        if not folder then return end
        for _,part in ipairs(folder:GetChildren()) do addCoin(part) end
        folder.ChildAdded:Connect(addCoin)
        folder.ChildRemoved:Connect(function(part: Instance)
            if part:IsA("BasePart") then coinVfx[part]=nil end
        end)
    end)
    RunService:BindToRenderStep("ER_CoinVFX",
        Enum.RenderPriority.Last.Value+1,function(_dt: number)
        local now=os.clock()
        for part,item in pairs(coinVfx) do
            if not part.Parent then coinVfx[part]=nil;continue end
            local t=now-item.created
            local bounce=math.abs(math.sin(t*8))*0.7*math.exp(-1.3*t)
            part.CFrame=item.base*CFrame.new(0,bounce,0)*CFrame.Angles(0,t*2.5,0)
        end
    end)
    redraw()
    updateVillage()
end
return UI
