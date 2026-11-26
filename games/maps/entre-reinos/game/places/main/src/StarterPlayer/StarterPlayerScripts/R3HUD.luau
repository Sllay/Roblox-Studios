--!strict
-- Entre Reinos, T1-R3 game HUD. One unobtrusive interface, not a debug board.
-- Sources/worker bags/committed building materials are distinct custodians.
-- Every action remains server authoritative; no custom movement/jump controls.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local HttpService=game:GetService("HttpService")
local BuildMenu=require(script.Parent:WaitForChild("BuildMenu"))
local Professions=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("ProfessionDefs"))
local Production=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("Production"))
local Market=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("Market"))
local Items=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("ItemDefs"))
local Gesture=require(script.Parent:WaitForChild("PressGesture"))
local WeaponControls=require(script.Parent:WaitForChild("WeaponControls"))
local DukeDialogue=require(script.Parent:WaitForChild("DukeDialogue"))
local Ballistics=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("Ballistics"))
local UI={}
local started=false

local Style=require(script.Parent:WaitForChild("VillageUI"))
local Hotbars=require(script.Parent:WaitForChild("Hotbars"))
local C=Style.colors
local resourceNames={wood="Madeira",stone="Pedra",iron="Ferro",food="Alimento"}
local resourceOrder={"wood","stone","iron","food"}
local errorTexts={
    travel_cargo_capacity="Confira a madeira e o espaço disponível.",
    travel_cost="Você precisa de 12 moedas para o cavalo.",
    travel_unavailable="Chegue perto da montaria, de uma doca ou de um reino já visitado.",
    save_busy="O save está ocupado. Tente viajar novamente.",
    datastore_unavailable="O save está indisponível. A viagem não foi confirmada.",
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
    stock_unavailable="Sem estoque livre ou espaço suficiente.",
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
    invalid_market_order="Pedido de mercado inválido.",
    market_funds="Saldo insuficiente.",
    market_stock="Confira o estoque e o espaço no destino.",
    market_route="Sem rota terrestre de carga entre os reinos.",
    market_contract_active="Já há um frete em andamento.",
    market_hostile="A relação entre os reinos impede o contrato.",
    social_wait="Dê um tempo antes de oferecer outra ajuda.",
    social_no_need="O morador está bem agora.",
    social_need_item="O presente usa uma tábua. A ajuda usa um alimento da sua bolsa.",
    social_no_shelter="Nenhum abrigo está acessível.",
    market_unmet="Visite a Vila do Cedro primeiro.",
    diplomacy_conditions="A relação atual ainda não permite esse acordo.",
    unknown_recipe="Receita inválida.",
    production_queue_full="A fila de fabricação está cheia.",
    production_station_required="Aproxime-se de uma oficina ou forja concluída.",
    world_not_loaded="O mundo está carregando.",
}

local label,button,panel,scroll,rowText=Style.label,Style.button,Style.panel,Style.scroll,Style.rowText

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
    top.AnchorPoint=Vector2.new(1,0)
    top.Position=UDim2.new(1,-10,0,57)
    top.Size=UDim2.fromOffset(138,29)
    local topLimit=Instance.new("UISizeConstraint")
    topLimit.MaxSize=Vector2.new(432,35)
    topLimit.Parent=top
    top.BackgroundTransparency=0.14
    local vitals=label(top,"Vitals","DIA 1  ·  Moedas 0  ·  Flechas 12",13,C.paper)
    vitals.Font=Enum.Font.GothamSemibold
    vitals.TextXAlignment=Enum.TextXAlignment.Center
    vitals.Size=UDim2.new(1,-16,1,0)

    local stock=Hotbars.resources(gui)

    local openJournal=button(gui,"VillageButton","VILA")
    openJournal.Position=UDim2.fromOffset(12,57)
    openJournal.Size=UDim2.fromOffset(76,42)
    openJournal.BackgroundColor3=C.background

    local journal=panel(gui,"VillageJournal",C.background)
    journal.Position=UDim2.fromOffset(11,90)
    journal.Size=UDim2.new(0,300,0.70,0)
    journal.Visible=false
    journal.ClipsDescendants=true
    local maxSize=Instance.new("UISizeConstraint")
    maxSize.MaxSize=Vector2.new(310,490)
    maxSize.MinSize=Vector2.new(210,112)
    maxSize.Parent=journal
    Style.fitJournal(gui,journal)
    local head=label(journal,"JournalTitle","CADERNO DA VILA",16,C.paper)
    head.Font=Enum.Font.GothamBold
    head.Position=UDim2.fromOffset(15,7)
    head.Size=UDim2.new(1,-61,0,33)
    local close=button(journal,"Close","×")
    close.AnchorPoint=Vector2.new(1,0)
    close.Position=UDim2.new(1,-7,0,5)
    close.Size=UDim2.fromOffset(42,42)
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
    local openSite: any=nil
    local selectedContext: any=nil
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
        elseif action=="social" then
            notify(tostring(result.message))
        elseif action=="produce" then
            notify("Receita adicionada à fila da vila.")
        elseif action=="craft_arrows" then
            notify("Seis flechas fabricadas: duas madeiras consumidas.")
        elseif action=="take_wood" then
            notify("Duas madeiras recolhidas na sua bolsa.")
        elseif action=="arm_defender" then
            notify("Morador equipado para defesa.")
        elseif action=="equipment_order" then
            notify("Ordem recebida. O morador vai buscar o equipamento.")
        elseif action=="stock_transfer" then
            notify("Estoque atualizado.")
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
    local cedroRoute=rowText(resourcesPage,"CedroRoute","",2,36)
    cedroRoute.Visible=false
    local resHint=rowText(resourcesPage,"Hint",
        "Barra: bolsa pessoal / estoque livre (galpões e moradores vivos) / máximo livre considerando o espaço restante. Reservas ficam separadas.",3,58)
    resHint.TextColor3=C.secondary
    local resourceCards: {[string]: TextLabel}={}
    for i,id in ipairs(resourceOrder) do
        local t=rowText(resourcesPage,"Resource_"..id,"",i+3,72)
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
        "Dê ordens a partir do caderno. Para conversar ou presentear, aproxime-se do morador.",2,53)
    local workerRows: {[number]: TextButton}={}
    local selectedNpcId=0
    local updateVillage: ()->()
    local selectedWorker=label(villagersPage,"Selected","Selecione um morador.",12,C.secondary)
    selectedWorker.LayoutOrder=500
    selectedWorker.Size=UDim2.new(1,-10,0,43)

    local roleIndex=1
    local nextRole=button(villagersPage,"ChooseRole","")
    local applyRole=button(villagersPage,"AssignRole","CONFIRMAR PROFISSÃO")
    for i,control in ipairs({nextRole,applyRole}) do
        control.LayoutOrder=501+i
        control.Size=UDim2.new(1,-10,0,40)
    end
    local function updateRole()
        nextRole.Text=Professions.get(Professions.order[roleIndex]).label.."  ·  alterar →"
    end
    nextRole.Activated:Connect(function()
        roleIndex=roleIndex%#Professions.order+1
        updateRole()
    end)
    applyRole.Activated:Connect(function()
        request("profession",tostring(selectedNpcId)..":"..Professions.order[roleIndex])
    end)
    updateRole()
    local directions={{"balanced","Equilíbrio"},{"building","Construção"},{"stock","Estoque"},{"food","Alimentos"}}
    local orderIndex=1
    local orderWorker=button(villagersPage,"WorkOrder","")
    orderWorker.LayoutOrder=508
    orderWorker.Size=UDim2.new(1,-10,0,42)
    orderWorker.Text="ORDEM · equilíbrio →"
    orderWorker.Activated:Connect(function()
        orderIndex=orderIndex%#directions+1
        orderWorker.Text="ORDEM · "..directions[orderIndex][2].." →"
        request("work_order",{id=selectedNpcId,order=directions[orderIndex][1]})
    end)
    local focusFood=button(resourcesPage,"FoodPriority","")
    focusFood.LayoutOrder=20
    focusFood.Size=UDim2.new(1,-10,0,42)
    focusFood.Activated:Connect(function() request("food_priority",nil) end)
    local socialControls={}
    for i,entry in ipairs({{"talk","CONVERSAR"},{"gift","PRESENTEAR · 1 TÁBUA"},
        {"help","AJUDAR · 1 ALIMENTO"},{"rescue","AJUDAR A CHEGAR AO ABRIGO"}}) do
        local control=button(villagersPage,"Social_"..entry[1],entry[2])
        control.LayoutOrder=503+i
        control.Size=UDim2.new(1,-10,0,40)
        control.Visible=false
        control.Activated:Connect(function() request("social",{id=selectedNpcId,kind=entry[1]}) end)
        table.insert(socialControls,control)
    end
    local equipBar=Instance.new("Frame")
    equipBar.Name="Equipment"
    equipBar.BackgroundTransparency=1
    equipBar.LayoutOrder=501
    equipBar.Size=UDim2.new(1,-8,0,40)
    equipBar.Parent=villagersPage
    local equipment={"bow","spear","axe","pick","hammer","hoe"}
    local gearIndex=1
    local chooseGear=button(equipBar,"ChooseGear","Arco →")
    chooseGear.Size=UDim2.new(0.49,0,1,0)
    chooseGear.Activated:Connect(function()
        gearIndex=gearIndex%#equipment+1
        chooseGear.Text=Items.get(equipment[gearIndex]).label.." →"
    end)
    local equip=button(equipBar,"RequestGear","SOLICITAR")
    equip.Position=UDim2.new(0.51,0,0,0)
    equip.Size=UDim2.new(0.49,0,1,0)
    equip.Activated:Connect(function()
        request("equipment_order",{id=selectedNpcId,item=equipment[gearIndex]})
    end)

    local reload=button(villagersPage,"ReloadArcher","ENTREGAR 6 FLECHAS")
    reload.LayoutOrder=509
    reload.Size=UDim2.new(1,-10,0,40)
    reload.Visible=false
    reload.Activated:Connect(function() request("arm_defender",tostring(selectedNpcId)..":bow") end)

    local panels: {[string]: ScrollingFrame}={}
    local details: {[string]: TextLabel}={}
    local siteLabels={castle="Castelo",forge="Ferraria",workshop="Carpintaria",
        stockpile="Galpão",farm="Fazenda",dock="Doca",property="Construção"}
    for key,title in pairs(siteLabels) do
        local page=scroll(content,"Site_"..key)
        page.Visible=false
        pages[key]=page
        panels[key]=page
        local heading=rowText(page,"Title",title,1,30)
        heading.TextSize=16
        heading.Font=Enum.Font.GothamBold
        details[key]=rowText(page,"Details","",2,55)
    end
    for index,recipeId in ipairs(Production.order) do
        local recipe=Production.recipes[recipeId]
        local control=button(panels[recipe.station],"Recipe_"..recipeId,recipe.label.." · "..recipe.cost)
        control.LayoutOrder=20+index
        control.Size=UDim2.new(1,-12,0,44)
        control.Activated:Connect(function()
            if openSite then request("produce",{recipe=recipeId,station=openSite.id}) end
        end)
    end
    local arrows=button(panels.workshop,"CraftArrows","FABRICAR 6 FLECHAS · 2 MADEIRAS")
    arrows.LayoutOrder=19
    arrows.Size=UDim2.new(1,-12,0,42)
    arrows.Activated:Connect(function() request("craft_arrows",openSite and openSite.id) end)
    local depotItems={}
    for item in pairs(Items.all) do table.insert(depotItems,item) end
    table.sort(depotItems)
    local depotItemIndex=1
    local depotItem=button(panels.stockpile,"Item","")
    depotItem.LayoutOrder=3
    depotItem.Size=UDim2.new(1,-12,0,42)
    depotItem.Activated:Connect(function()
        depotItemIndex=depotItemIndex%#depotItems+1
        updateVillage()
    end)
    for index,direction in ipairs({"take","put"}) do
        local transfer=button(panels.stockpile,"Stock_"..direction,if direction=="take" then "RETIRAR 1" else "DEPOSITAR 1")
        transfer.LayoutOrder=3+index
        transfer.Size=UDim2.new(1,-12,0,42)
        transfer.Activated:Connect(function()
            if openSite then request("stock_transfer",{id=openSite.id,item=depotItems[depotItemIndex],direction=direction}) end
        end)
    end
    local castle=panels.castle
    local tradeInfo=rowText(castle,"TradeInfo","",5,67)
    local marketIndex=1
    local marketChoice=button(castle,"MarketChoice","")
    local buyGood=button(castle,"BuyGood","COMPRAR")
    local sellGood=button(castle,"SellGood","VENDER")
    local exportGood=button(castle,"ExportGood","ENVIAR 2 AO CEDRO")
    local importGood=button(castle,"ImportGood","TRAZER 2 DO CEDRO")
    local cancelContract=button(castle,"CancelContract","CANCELAR CONTRATO")
    local marketControls={marketChoice,buyGood,sellGood,exportGood,importGood,cancelContract}
    for index,control in ipairs(marketControls) do
        control.LayoutOrder=30+index
        control.Size=UDim2.new(1,-12,0,42)
        control.Visible=false
    end
    marketChoice.Activated:Connect(function()
        marketIndex=marketIndex%#Market.goods+1
        updateVillage()
    end)
    buyGood.Activated:Connect(function()
        request("market",{verb="buy",item=Market.goods[marketIndex],id=HttpService:GenerateGUID(false)})
    end)
    sellGood.Activated:Connect(function()
        request("market",{verb="sell",item=Market.goods[marketIndex],id=HttpService:GenerateGUID(false)})
    end)
    exportGood.Activated:Connect(function() request("freight",{seller="home",units=2,item=Market.goods[marketIndex],id=HttpService:GenerateGUID(false)}) end)
    importGood.Activated:Connect(function() request("freight",{seller="foreign",units=2,item=Market.goods[marketIndex],id=HttpService:GenerateGUID(false)}) end)
    cancelContract.Activated:Connect(function() request("freight_cancel",nil) end)
    local diplomacyInfo=rowText(castle,"Relations","",40,58)
    local diplomacyButtons={}
    for index,entry in ipairs({{"trade","ACORDO COMERCIAL"},{"alliance","ALIANÇA"},
        {"tribute","TRIBUTO AO CEDRO · 3 MOEDAS"},{"withdraw","ENCERRAR ACORDO"}}) do
        local control=button(castle,"Diplomacy_"..entry[1],entry[2])
        control.LayoutOrder=40+index
        control.Size=UDim2.new(1,-12,0,42)
        control.Visible=false
        control.Activated:Connect(function() request("diplomacy",entry[1]) end)
        table.insert(diplomacyButtons,control)
    end
    local tradeButton=button(castle,"SellWood","VENDER 1 MADEIRA")
    tradeButton.LayoutOrder=6
    tradeButton.Size=UDim2.new(1,-12,0,42)
    local coinsInfo=rowText(castle,"PurseInfo","",7,62)
    local dropCoin=button(castle,"DropCoin","SOLTAR 1 MOEDA")
    dropCoin.LayoutOrder=8
    dropCoin.Size=UDim2.new(1,-12,0,42)

    tradeButton.Activated:Connect(function() request("trade","wood") end)
    dropCoin.Activated:Connect(function() request("drop_coin",nil) end)

    local entries={
        {"build","OBRAS"},
        {"resources","ESTOQUE"},
        {"villagers","PESSOAS"},
    }
    for i,item in ipairs(entries) do
        local b=button(tabs,"Tab_"..item[1],item[2])
        b.LayoutOrder=i
        b.Size=UDim2.new(1/3,-4,1,0)
        b.TextSize=10
        tabsUI[item[1]]=b
    end
    local function showTab(nextTab: string)
        tab=nextTab
        tabs.Visible=panels[tab]==nil
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
        if not value or (nextTab and not panels[nextTab]) then openSite=nil end
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
    combat.Position=UDim2.new(1,-12,0.59,0)
    combat.Size=UDim2.fromOffset(62,62)
    combat.Parent=gui
    local attack=button(combat,"Attack","ATACAR")
    attack.Size=UDim2.fromScale(1,1)
    attack.BackgroundColor3=Color3.fromRGB(105,65,48)
    attack.TextSize=11
    Style.roundAction(attack)

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
    local weapons=WeaponControls.mount(player,gui,attack,call,notify)

    local interact=button(gui,"ContextAction","INTERAGIR")
    interact.AnchorPoint=Vector2.new(1,1)
    interact.Position=UDim2.new(1,-12,0.59,-40)
    interact.Size=UDim2.fromOffset(62,62)
    Style.roundAction(interact)
    interact.TextSize=10
    interact.BackgroundColor3=C.surface
    interact.Visible=false
    Style.fitActions(gui,combat,interact)
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
    local travelLabels={buy_mount="CAVALO • 12 MOEDAS",mount="MONTAR",dismount="DESMONTAR",
        board="EMBARCAR",disembark="DESEMBARCAR",travel="VIAJAR ENTRE REINOS"}
    local contextKind="none"
    local contextTarget: any=0
    local pressedTree: any=nil
    local talking=false
    local cancelInteract: ()->()=function() end
    local function paintActions()
        local open=not talking and not journal.Visible and player:GetAttribute("ER_LocalPlacement")~=true
        local riding=player:GetAttribute("ER_Riding")~=nil
        combat.Visible=open and not riding
        attack.Visible=combat.Visible
        weapons.show(combat.Visible)
        if not combat.Visible then weapons.cancel() end
        if not open and pressedTree then cancelInteract() end
        interact.Visible=open and contextKind~="none"
        openJournal.Visible=not talking
    end
    player:GetAttributeChangedSignal("ER_LocalPlacement"):Connect(paintActions)
    player:GetAttributeChangedSignal("ER_Riding"):Connect(paintActions)
    local openDialogue,closeDialogue=DukeDialogue.mount(gui,call,function(value)
        talking=value
        paintActions()
    end)
    player.CharacterRemoving:Connect(closeDialogue)

    local function interactNow()
        if not interact.Visible then return end
        if contextKind=="travel" then
            request("travel",contextTarget)
        elseif contextKind=="gate" then
            request("gate",contextTarget)
        elseif contextKind=="coin" then
            request("pickup_coin",contextTarget)
        elseif contextKind=="npc" then
            selectedNpcId=contextTarget
            showJournal(true,"villagers")
        elseif contextKind=="structure" then
            for _,building in ipairs(snapshot and snapshot.buildings or {}) do
                if building.id==contextTarget then
                    local kind=if panels[building.typeId] and (building.state=="complete" or building.state=="damaged")
                        then building.typeId else "property"
                    openSite={id=building.id,kind=kind}
                    showJournal(true,kind)
                    updateVillage()
                    break
                end
            end
        elseif contextKind=="dock" then
            openSite={id="dock",kind="dock"}
            showJournal(true,"dock")
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
    cancelInteract=Gesture.bind(interact,function()
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
    warning.Position=UDim2.new(0.5,0,0,86)
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
        local kingdom=player:GetAttribute("ER_Kingdom")
        if type(kingdom)=="string" then head.Text=string.upper(kingdom) end
        local day=player:GetAttribute("ER_R3Day") or 1
        local night=player:GetAttribute("ER_R3Night")==true
        local wallet=player:GetAttribute("ER_R3Wallet") or 0
        local enemies=player:GetAttribute("ER_R3Enemies") or 0
        local phase=player:GetAttribute("ER_R3Phase") or "sandbox"
        local isRaid=player:GetAttribute("ER_R3Raid")==true
        local message=player:GetAttribute("ER_R3Warning")
        Style.text(vitals,"Dia "..tostring(day)..(if night then " · Noite" else "")
            .."  ·  "..tostring(wallet).." moedas")
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

    local loadCargo=button(panels.dock,"BoatLoad","GUARDAR 1 MADEIRA NO BARCO")
    local unloadCargo=button(panels.dock,"BoatUnload","RETIRAR 1 MADEIRA DO BARCO")
    for index,control in ipairs({loadCargo,unloadCargo}) do
        control.LayoutOrder=10+index
        control.Size=UDim2.new(1,-12,0,42)
        control.Visible=false
    end
    loadCargo.Activated:Connect(function() request("travel_cargo","load") end)
    unloadCargo.Activated:Connect(function() request("travel_cargo","unload") end)

    local function updateContext()
        loadCargo.Visible=type(nearby.boatCargo)=="number"
        unloadCargo.Visible=loadCargo.Visible
        unloadCargo.Text="RETIRAR 1 MADEIRA DO BARCO · "..tostring(nearby.boatCargo or 0)
        local target=selectedContext
        contextKind=if target then target.kind else "none"
        contextTarget=if target then target.id else 0
        if target then
            interact.Text=if target.kind=="tree" then "Árvore\nSegure: "..target.label
                elseif target.kind=="travel" then travelLabels[target.id] or "Viajar"
                else target.label
        end
        if pressedTree and (contextKind~="tree" or contextTarget~=pressedTree.treeId) then cancelInteract() end
        if openSite and ((not target or target.id~=openSite.id) or player:GetAttribute("ER_R3Raid")==true) then
            showJournal(false,nil)
            return
        end
        paintActions()
        highlightTarget()
    end
    local interactions=ReplicatedStorage:WaitForChild("Game"):WaitForChild("ER_InteractionTarget") :: RemoteEvent
    interactions.OnClientEvent:Connect(function(target: any)
        selectedContext=target
        updateContext()
    end)
    refreshContext=updateContext

    function updateVillage()
        cedroRoute.Visible=type(nearby.cedroDistance)=="number"
        if cedroRoute.Visible then
            cedroRoute.Text=string.format("Vila do Cedro · siga para %s (%d studs)",
                nearby.cedroDirection,nearby.cedroDistance)
        end
        local resources=if snapshot then snapshot.resources else nil
        local sources=if resources then resources.sources else nil
        local carried=if resources then resources.carried else nil
        local reserved=if resources then resources.reserved else nil
        local committed=if resources then resources.committed else nil
        local stocked=if resources then resources.stored else nil
        local isolated=if resources then resources.isolated else nil
        stock.update(hud.playerItems,if snapshot then snapshot.quickStock else nil)
        weapons.update(hud.playerItems)
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
                    (if w.tool then " · "..tostring(w.tool.item).." "..tostring(w.tool.remaining) else "")..
                    " · nível "..tostring(w.level or 1).." · fome "..tostring(math.floor(w.hunger or 0)).."% · fadiga "..tostring(math.floor(w.fatigue or 0)).."% · carga "..tostring(math.floor(w.carryWeight)).." u."..
                    (if w.district then " · "..w.district else "")..
                    (if w.social then " · "..w.social.mood.." · confiança "..tostring(w.social.trust) else "")
                b.TextColor3=if w.id==selectedNpcId then C.gold else C.paper
                b.Visible=true
            end
        end
        for id,b in pairs(workerRows) do
            if not active[id] then b.Visible=false end
        end
        local nearSelected=nearby.npcId==selectedNpcId and selectedNpcId>0
        local canOrder=active[selectedNpcId] and nearby.canManage==true and snapshot~=nil and snapshot.production~=nil
        selectedWorker.Text=if not active[selectedNpcId] then "Escolha um morador." else "Ordens para o morador selecionado"
        equipBar.Visible=canOrder==true
        nextRole.Visible=canOrder==true
        orderWorker.Visible=nextRole.Visible
        focusFood.Visible=nearby.canManage==true and snapshot~=nil and snapshot.production~=nil
        focusFood.Text=if focusFood.Visible and snapshot.production.focusFood then "ALIMENTAÇÃO · prioridade alta"
            else "PRIORIZAR ALIMENTAÇÃO"
        applyRole.Visible=nextRole.Visible
        for _,control in ipairs(socialControls) do control.Visible=nearSelected and snapshot~=nil and snapshot.production~=nil end
        equip.Text="SOLICITAR"
        reload.Visible=false
        for _,worker in ipairs(workers or {}) do
            if worker.id==selectedNpcId then
                reload.Visible=nearSelected and worker.defense=="bow" and worker.arrows==0
                if worker.gearOrder then
                    selectedWorker.Text=Items.get(worker.gearOrder).label..(if worker.gettingGear then " · a caminho do estoque" else " · aguardando estoque")
                end
                break
            end
        end
        if openSite then
            for _,b in ipairs(snapshot and snapshot.buildings or {}) do
                if b.id~=openSite.id then continue end
                local lines={b.name.." · "..tostring(math.floor(b.health)).." de vida"}
                if openSite.kind=="stockpile" then
                    local item=depotItems[depotItemIndex]
                    local held=b.stored[item] or 0
                    local free=b.available[item] or 0
                    depotItem.Text=Items.get(item).label.." →"
                    table.insert(lines,string.format("%d em estoque · %d reservados",held,held-free))
                    table.insert(lines,string.format("Peso %d / %d",b.storedWeight,b.storedCapacity))
                elseif openSite.kind=="workshop" or openSite.kind=="forge" then
                    for _,order in ipairs(snapshot.production and snapshot.production.orders or {}) do
                        if order.station==b.id then
                            local recipe=Production.recipes[order.recipe]
                            table.insert(lines,recipe.label.." · "..tostring(math.floor(100*order.progress/recipe.time)).."%")
                        end
                    end
                    if #lines==1 then table.insert(lines,"Nenhuma fabricação em andamento.") end
                elseif openSite.kind=="farm" then
                    local plot=b.plot
                    if plot then table.insert(lines,string.format("%s · água %s",plot.stage or "Solo",if plot.irrigated then "próxima" else "distante")) end
                end
                details[openSite.kind].Text=table.concat(lines,"\n")
                details[openSite.kind].Size=UDim2.new(1,-12,0,math.min(210,25+#lines*17))
                break
            end
        end
        local market=if snapshot then snapshot.market else nil
        local currentGood=Market.goods[marketIndex]
        local quote=if market then market.goods[currentGood] else nil
        for _,control in ipairs(marketControls) do
            control.Visible=market~=nil
        end
        exportGood.Visible=market~=nil and nearby.canContract==true
        importGood.Visible=exportGood.Visible
        cancelContract.Visible=market~=nil and nearby.freight~=nil and not nearby.freight.returning
        tradeButton.Visible=market==nil
        local relations=nearby.relations
        diplomacyInfo.Visible=relations~=nil
        if relations then
            diplomacyInfo.Text="VALE DO DUQUE E CEDRO · "..relations.attitude
                .." ("..tostring(relations.standing)..")"
                ..(if relations.accord=="alliance" then "\nAliança" elseif relations.accord=="trade" then "\nAcordo comercial" else "")
        end
        diplomacyButtons[1].Visible=relations~=nil and relations.accord==nil
        diplomacyButtons[2].Visible=relations~=nil and relations.accord=="trade"
        diplomacyButtons[3].Visible=relations~=nil
        diplomacyButtons[4].Visible=relations~=nil and relations.accord~=nil
        if market and quote then
            local last=market.latest
            local freight=nearby.freight
            tradeInfo.Text="TESOURO · "..tostring(market.treasury).." moedas"
                ..(if last then "  ·  "..tostring(last.kind).." "..tostring(last.value) else "")
                ..(if freight then "\nFrete: "..tostring(freight.units).." "..Items.get(freight.item).label
                    ..(if freight.returning then " · devolução" else "") else "")
                ..(if nearby.marketHere then "" else "\nAproxime-se do castelo para negociar.")
            marketChoice.Text=Items.get(currentGood).label.." · "..tostring(quote.stock).." em estoque →"
            buyGood.Text="COMPRAR · "..tostring(quote.buy).." moedas"
            sellGood.Text="VENDER · "..tostring(quote.sell).." moedas"
        end
        coinsInfo.Text="SUA BOLSA  ·  "..tostring(player:GetAttribute("ER_R3Wallet") or 0)..
            " moedas. Soltar uma moeda deixa um item físico no chão."
        dropCoin.Active=(player:GetAttribute("ER_R3Wallet") or 0)>0
        dropCoin.BackgroundColor3=if dropCoin.Active then C.raised else C.surface
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
        selectedContext=nearby.context
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
            if name=="ER_R3Phase" then updateVillage()
            elseif name=="ER_R3Raid" then updateContext() end
        end)
    end
    UserInputService.InputBegan:Connect(function(input: InputObject,processed: boolean)
        if processed or not gui.Parent then return end
        if talking then
            if input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB then closeDialogue() end
            return
        end
        if journal.Visible and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then closeJournal()
        elseif input.KeyCode==Enum.KeyCode.V then showJournal(not journal.Visible,"build") end
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
