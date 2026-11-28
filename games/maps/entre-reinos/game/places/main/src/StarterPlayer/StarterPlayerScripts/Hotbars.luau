--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local living=ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living")
local Items=require(living:WaitForChild("ItemDefs"))
local Quick=require(living:WaitForChild("QuickItems"))
local Style=require(script.Parent:WaitForChild("VillageUI"))
local C=Style.colors
local Bars={}
local resourceOrder={"wood","stone","iron","food","plank","metal","grain","meat","leather","axe","pick","hammer","hoe","bow","spear"}

-- Original silhouettes assembled from native UI shapes, without external assets.
local function icon(parent: Instance,key: string,position: UDim2,size: number)
    local tile=Instance.new("Frame")
    tile.Name="Icon"
    tile.BackgroundTransparency=1
    tile.Size=UDim2.fromOffset(size,size)
    tile.Position=position
    tile.Parent=parent
    local function piece(x: number,y: number,w: number,h: number,color: Color3,angle: number,radius: number)
        local part=Instance.new("Frame")
        part.AnchorPoint=Vector2.new(0.5,0.5)
        part.Position=UDim2.fromScale(x,y)
        part.Size=UDim2.fromScale(w,h)
        part.BackgroundColor3=color
        part.BorderSizePixel=0
        part.Rotation=angle
        if radius>0 then
            local round=Instance.new("UICorner")
            round.CornerRadius=UDim.new(radius,0)
            round.Parent=part
        end
        part.Parent=tile
    end
    local wood=Color3.fromRGB(163,110,63)
    local iron=Color3.fromRGB(209,211,187)
    local leaf=Color3.fromRGB(104,155,93)
    if key=="sword" or key=="spear" or key=="axe" or key=="pick" or key=="hammer" or key=="hoe" then
        piece(0.4,0.65,0.13,0.53,wood,44,0.2)
        if key=="sword" or key=="spear" then
            piece(0.60,0.38,0.23,0.53,iron,44,0.12)
            if key=="sword" then piece(0.45,0.55,0.43,0.12,C.gold,44,0.1) end
        else piece(0.63,0.39,0.37,0.25,iron,37,0.19) end
    elseif key=="bow" then
        piece(0.60,0.33,0.12,0.42,wood,-44,0.3)
        piece(0.60,0.67,0.12,0.42,wood,44,0.3)
        piece(0.43,0.5,0.05,0.66,C.paper,0,0)
    elseif key=="wood" or key=="plank" then
        piece(0.45,0.48,0.73,0.29,wood,-18,0.22)
        piece(0.53,0.66,0.70,0.23,Color3.fromRGB(180,134,78),-18,0.15)
        piece(0.71,0.41,0.24,0.27,C.gold,-18,0.48)
    elseif key=="food" or key=="meat" or key=="grain" then
        piece(0.49,0.59,0.63,0.49,if key=="meat" then C.danger else C.gold,-12,0.42)
        piece(0.60,0.31,0.23,0.13,leaf,-32,0.35)
    else
        piece(0.44,0.53,0.6,0.54,if key=="leather" then wood else iron,23,0.28)
        piece(0.55,0.59,0.46,0.35,Color3.fromRGB(111,126,122),-21,0.24)
    end
end

function Bars.resources(gui: ScreenGui)
    local view=Instance.new("ScrollingFrame")
    view.Name="ResourceHotbar"
    view.AnchorPoint=Vector2.new(0.5,0)
    view.Position=UDim2.new(0.5,0,0,4)
    view.BackgroundTransparency=1
    view.BorderSizePixel=0
    view.ScrollingDirection=Enum.ScrollingDirection.X
    view.ScrollBarThickness=2
    view.ScrollBarImageColor3=C.stroke
    view.CanvasSize=UDim2.fromOffset(0,0)
    view.ClipsDescendants=true
    view.Parent=gui
    local layout=Instance.new("UIListLayout")
    layout.FillDirection=Enum.FillDirection.Horizontal
    layout.Padding=UDim.new(0,4)
    layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout.Parent=view

    local cards: {[string]: {box: Frame,count: TextLabel}}={}
    local cardCount=0
    local width=80
    local pending=0
    local dragging=false
    local adjusting=false
    local scrolling: Tween?=nil
    local function resize()
        local usable=math.max(64,gui.AbsoluteSize.X-108)
        width=math.clamp(math.floor(usable/4)-4,68,106)
        local step=width+4
        local slots=math.min(4,math.max(1,math.floor((usable+4)/step)),math.max(1,cardCount))
        view.Size=UDim2.fromOffset(slots*step-4,51)
        for _,slot in pairs(cards) do slot.box.Size=UDim2.fromOffset(width,48) end
        view.CanvasSize=UDim2.fromOffset(math.max(0,cardCount*step-4),0)
    end
    local function snap()
        pending+=1
        local marker=pending
        task.delay(0.16,function()
            if not view.Parent or pending~=marker or dragging or adjusting then return end
            local step=width+4
            local x=math.clamp(math.floor(view.CanvasPosition.X/step+0.5)*step,
                0,math.max(0,view.AbsoluteCanvasSize.X-view.AbsoluteWindowSize.X))
            if math.abs(x-view.CanvasPosition.X)<0.5 then return end
            adjusting=true
            local tween=TweenService:Create(view,TweenInfo.new(0.13,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
                {CanvasPosition=Vector2.new(x,0)})
            scrolling=tween
            tween.Completed:Once(function()
                if scrolling==tween then scrolling=nil;adjusting=false end
            end)
            tween:Play()
        end)
    end
    view.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true
            if scrolling then scrolling:Cancel() end
            adjusting=false
        end
    end)
    Input.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then
            dragging=false
            snap()
        end
    end)
    view:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if not dragging and not adjusting then snap() end
    end)
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    view.Visible=false
    resize()

    local function update(bag: any,rows: any)
        local changed=false
        for _,id in ipairs(resourceOrder) do
            local row=rows and rows[id]
            local personal=(bag and bag[id]) or 0
            local stock=if row then row.stock else 0
            local slot=cards[id]
            if not slot and (personal>0 or stock>0) then
                local box=Style.panel(view,id,C.background)
                box.BackgroundTransparency=0.1
                cardCount+=1
                box.LayoutOrder=cardCount
                icon(box,id,UDim2.fromOffset(3,5),19)
                local count=Style.label(box,"Count","",12,C.paper)
                count.Position=UDim2.fromOffset(25,4)
                count.Size=UDim2.new(1,-27,0,21)
                count.TextScaled=true
                local size=Instance.new("UITextSizeConstraint")
                size.MaxTextSize=13
                size.MinTextSize=8
                size.Parent=count
                local name=Style.label(box,"Name",Items.get(id).label,10,C.secondary)
                name.Position=UDim2.fromOffset(2,25)
                name.Size=UDim2.new(1,-4,0,17)
                name.TextXAlignment=Enum.TextXAlignment.Center
                slot={box=box,count=count}
                cards[id]=slot
                changed=true
            end
            if slot then
                Style.text(slot.count,string.format("%d/%d/%s",personal,stock,if row and row.capacity>0 then tostring(row.capacity) else "–"))
            end
        end
        if changed then resize() end
        view.Visible=cardCount>0
    end
    return {update=update,view=view}
end

function Bars.equipment(gui: ScreenGui,select: (string)->())
    local bar=Style.panel(gui,"EquipmentHotbar",C.background)
    bar.AnchorPoint=Vector2.new(0.5,1)
    bar.Position=UDim2.new(0.5,0,1,-8)
    bar.Size=UDim2.fromOffset(116,53)
    local layout=Instance.new("UIListLayout")
    layout.FillDirection=Enum.FillDirection.Horizontal
    layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.Padding=UDim.new(0,3)
    layout.Parent=bar
    local cards: {[string]: TextButton}={}
    for _,id in ipairs(Quick.order) do
        local def=Quick.items[id]
        local slot=Style.button(bar,id,def.label)
        slot.Size=UDim2.fromOffset(49,50)
        slot.TextSize=10
        slot.TextYAlignment=Enum.TextYAlignment.Bottom
        icon(slot,id,UDim2.new(0.5,-12,0,3),24)
        slot.Activated:Connect(function() select(id) end)
        cards[id]=slot
    end
    return {
        view=bar,
        update=function(mode: string,bag: any,arrows: number)
            local n=0
            for _,id in ipairs(Quick.order) do
                local slot=cards[id]
                local qty=(bag and bag[id]) or 0
                local def=Quick.items[id]
                slot.Visible=def.issued or qty>0
                if slot.Visible then n+=1 end
                slot.BackgroundColor3=if mode==id then C.raised:Lerp(C.gold,0.25) else C.surface
                Style.text(slot,def.label..(if def.ammo then " "..tostring(arrows) elseif not def.issued then " "..tostring(qty) else ""))
            end
            bar.Size=UDim2.fromOffset(n*52+4,53)
        end,
    }
end

return Bars
