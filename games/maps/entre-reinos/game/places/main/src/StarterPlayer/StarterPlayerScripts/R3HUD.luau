--!strict
-- T1-R3 mobile-first action bar. Only user intent crosses the RemoteFunction;
-- player coordinates, combat hits, loot IDs and currency are server-validated.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UI={}
local started=false

local function button(parent: Instance,name: string,caption: string,
        width: number): TextButton
    local b=Instance.new("TextButton")
    b.Name=name
    b.Text=caption
    b.TextSize=13
    b.TextWrapped=true
    b.Font=Enum.Font.GothamBold
    b.TextColor3=Color3.fromRGB(242,242,229)
    b.BackgroundColor3=Color3.fromRGB(54,77,63)
    b.BorderSizePixel=0
    b.Size=UDim2.fromOffset(width,39)
    b.Parent=parent
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,6)
    c.Parent=b
    return b
end

function UI.start(player: Player)
    if started then return end
    started=true
    local remote=ReplicatedStorage:WaitForChild("Game"):WaitForChild("ER_LivingActions",12)
    if not remote or not remote:IsA("RemoteFunction") then
        warn("[EntreReinos][R3] Missing server combat remote")
        return
    end
    local gui=Instance.new("ScreenGui")
    gui.Name="ER_R3HUD"
    gui.IgnoreGuiInset=false
    gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
    gui.ResetOnSpawn=false
    gui.DisplayOrder=7
    gui.Parent=player:WaitForChild("PlayerGui")

    local info=Instance.new("TextLabel")
    info.Name="DefenseStatus"
    info.AnchorPoint=Vector2.new(0.5,0)
    info.Position=UDim2.new(0.5,0,0,10)
    info.Size=UDim2.new(0,340,0,44)
    info.BackgroundTransparency=0.4
    info.BackgroundColor3=Color3.fromRGB(16,31,24)
    info.TextColor3=Color3.fromRGB(249,245,215)
    info.Font=Enum.Font.GothamSemibold
    info.TextSize=12
    info.TextWrapped=true
    info.Parent=gui

    local bar=Instance.new("Frame")
    bar.Name="Actions"
    bar.AnchorPoint=Vector2.new(0.5,1)
    bar.Position=UDim2.new(0.5,0,1,-68)
    bar.Size=UDim2.fromOffset(350,129)
    bar.BackgroundTransparency=1
    bar.Parent=gui
    local layout=Instance.new("UIGridLayout")
    layout.CellSize=UDim2.fromOffset(82,38)
    layout.CellPadding=UDim2.fromOffset(6,5)
    layout.FillDirectionMaxCells=4
    layout.Parent=bar

    local feedback=Instance.new("TextLabel")
    feedback.Name="ActionFeedback"
    feedback.AnchorPoint=Vector2.new(0.5,1)
    feedback.Position=UDim2.new(0.5,0,1,-199)
    feedback.Size=UDim2.fromOffset(370,40)
    feedback.BackgroundTransparency=1
    feedback.TextColor3=Color3.new(1,1,1)
    feedback.TextStrokeColor3=Color3.new(0,0,0)
    feedback.TextStrokeTransparency=0.25
    feedback.TextSize=12
    feedback.TextWrapped=true
    feedback.Font=Enum.Font.GothamSemibold
    feedback.Parent=gui

    local pending=false
    local function send(action: string,arg: any?)
        if pending then return end
        pending=true
        local ok,response=pcall(function() return remote:InvokeServer(action,arg) end)
        pending=false
        if not ok or type(response)~="table" then
            feedback.Text="Falha de comunicação com o servidor."
            return
        end
        if not response.ok then
            local errors={
                rate_limited="Ação muito rápida; tente novamente.",
                no_arrows="Sem flechas disponíveis.",
                too_far_from_coin="Aproxime-se da moeda.",
                drop_not_found="Moeda não encontrada.",
                already_claimed="Moeda já recolhida.",
                invalid_coin_drop="A bolsa não possui essa moeda.",
                treasury_empty="O tesouro não tem fundos.",
                resource_unavailable="Faltam recursos para negociar.",
                wood_stock_required="Crie flechas perto de um depósito de madeira.",
                ammo_capacity="Sua aljava já está cheia.",
                too_far_from_market="Negocie perto do centro da vila.",
                not_enough_equipment_materials="Faltam materiais para equipar.",
                too_far_from_defender="Aproxime-se de um morador.",
                action_unavailable="Essa ordem ainda não está disponível.",
            }
            feedback.Text=errors[tostring(response.error)] or
                ("Ordem recusada: "..tostring(response.error))
        else
            feedback.Text=if action=="attack" then "Golpe executado."
                else if action=="bow" then "Flecha disparada."
                else if action=="trade" then "Troca autorizada pelo tesouro."
                else if action=="arm_defender" then "Morador equipado para defesa."
                else if action=="pickup_coin" then "Moeda recolhida."
                else "Ordem concluída."
        end
    end

    local attack=button(bar,"Melee","Atacar",82)
    local bow=button(bar,"Arrow","Arco",82)
    local pickup=button(bar,"Pickup","Coletar",82)
    local drop=button(bar,"CoinDrop","Soltar moeda",82)
    local order=button(bar,"PrologueOrder","Ordem",82)
    local bowGuard=button(bar,"ArmArcher","Armar arco",82)
    local spearGuard=button(bar,"ArmSpearman","Armar lança",82)
    local trade=button(bar,"Trade","Vender madeira",82)
    local craft=button(bar,"CraftArrows","Criar flechas",82)

    attack.Activated:Connect(function() send("attack",nil) end)
    bow.Activated:Connect(function() send("bow",nil) end)
    drop.Activated:Connect(function() send("drop_coin",nil) end)
    trade.Activated:Connect(function() send("trade","wood") end)
    craft.Activated:Connect(function() send("craft_arrows",nil) end)
    pickup.Activated:Connect(function()
        local char=player.Character
        local root=if char then char:FindFirstChild("HumanoidRootPart") else nil
        local f=workspace:FindFirstChild("ER_LivingWorld")
        if not root or not root:IsA("BasePart") or not f then return end
        local best: BasePart?=nil
        local dist=math.huge
        for _,p in ipairs(f:GetChildren()) do
            if p:IsA("BasePart") and type(p:GetAttribute("ER_CoinId"))=="number" then
                local d=(p.Position-root.Position).Magnitude
                if d<dist then best=p;dist=d end
            end
        end
        if best and dist<10 then
            send("pickup_coin",best:GetAttribute("ER_CoinId"))
        else
            feedback.Text="Aproxime-se de uma moeda."
        end
    end)

    local function equip(weapon: string)
        local char=player.Character
        local root=if char then char:FindFirstChild("HumanoidRootPart") else nil
        local folder=workspace:FindFirstChild("ER_LivingWorld")
        if not root or not root:IsA("BasePart") or not folder then return end
        local bestId=nil
        local dist=math.huge
        for _,model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") and model:GetAttribute("ER_NPC")==true then
                local id=model:GetAttribute("ER_NPCId")
                local pose=model:GetAttribute("ER_NPCPose")
                if type(id)=="number" and typeof(pose)=="Vector3" then
                    local d=math.abs(root.Position.X-pose.X)
                    if d<dist then bestId=id;dist=d end
                end
            end
        end
        if not bestId or dist>15 then
            feedback.Text="Aproxime-se de um dos moradores."
        else
            send("arm_defender",tostring(bestId)..":"..weapon)
        end
    end
    bowGuard.Activated:Connect(function() equip("bow") end)
    spearGuard.Activated:Connect(function() equip("spear") end)
    order.Activated:Connect(function()
        local phase=player:GetAttribute("ER_R3Phase")
        if phase=="evacuation" then send("prologue","evacuate")
        elseif phase=="coronation" then send("prologue","coronation")
        else feedback.Text="Nenhuma ordem especial neste momento." end
    end)

    local coins: {[BasePart]: any}={}
    local folder=workspace:FindFirstChild("ER_LivingWorld")
    local function attachCoin(part: Instance)
        if part:IsA("BasePart") and type(part:GetAttribute("ER_CoinId"))=="number" then
            coins[part]={base=part.CFrame,created=os.clock()}
        end
    end
    if folder then
        for _,p in ipairs(folder:GetChildren()) do attachCoin(p) end
        folder.ChildAdded:Connect(attachCoin)
        folder.ChildRemoved:Connect(function(p)
            if p:IsA("BasePart") then coins[p]=nil end
        end)
    end
    RunService:BindToRenderStep("ER_CoinVFX",Enum.RenderPriority.Last.Value+1,function(_dt: number)
        local now=os.clock()
        for part,item in pairs(coins) do
            if not part.Parent then coins[part]=nil;continue end
            local t=now-item.created
            -- Local bounce and spin only; the authoritative coin record
            -- never moves or changes ownership due to these effects.
            local bounce=math.abs(math.sin(t*8))*0.7*math.exp(-1.3*t)
            part.CFrame=item.base*CFrame.new(0,bounce,0)*CFrame.Angles(0,t*2.5,0)
        end
    end)
    local function renderHud()
        local day=player:GetAttribute("ER_R3Day") or 1
        local night=player:GetAttribute("ER_R3Night")==true
        local enemies=player:GetAttribute("ER_R3Enemies") or 0
        local wallet=player:GetAttribute("ER_R3Wallet") or 0
        local ammo=player:GetAttribute("ER_R3Arrows") or 0
        local phase=player:GetAttribute("ER_R3Phase") or "sandbox"
        local warning=player:GetAttribute("ER_R3Warning") or ""
        info.Text=string.format("Dia %d | %s | Invasores: %d | Moedas: %d | Flechas: %d\n%s",
            day,if night then "Noite" else "Dia",enemies,wallet,ammo,warning)
        order.Visible=(phase=="evacuation" or phase=="coronation")
        if phase=="evacuation" then order.Text="Evacuar"
        elseif phase=="coronation" then order.Text="Coroação" end
        if phase=="guard" then
            feedback.Text="Prólogo: use Atacar para iniciar o treinamento e defender a vila."
        end
    end
    for _,name in ipairs({"ER_R3Day","ER_R3Night","ER_R3Enemies",
        "ER_R3Wallet","ER_R3Arrows","ER_R3Warning","ER_R3Phase"}) do
        player:GetAttributeChangedSignal(name):Connect(renderHud)
    end
    renderHud()
end
return UI
