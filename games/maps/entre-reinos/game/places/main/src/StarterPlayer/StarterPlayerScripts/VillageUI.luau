--!strict
-- Shared palette, presentation and safe-area sizing for the in-game journal.
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
    b.Font=Enum.Font.GothamMedium
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


local Style={colors=C,label=label,button=button,panel=panel,scroll=scroll,rowText=rowText}

function Style.roundAction(control: TextButton)
    local corner=control:FindFirstChildOfClass("UICorner")
    if corner then corner.CornerRadius=UDim.new(0.5,0) end
    control.TextWrapped=true
    local inset=Instance.new("UIPadding")
    inset.PaddingLeft=UDim.new(0,6)
    inset.PaddingRight=UDim.new(0,6)
    inset.Parent=control
end

function Style.fitJournal(gui: ScreenGui,frame: Frame)
    local function fit()
        local view=gui.AbsoluteSize
        if view.X<=0 or view.Y<=0 then return end
        local width=math.min(384,view.X-22)
        local height=math.max(112,math.min(512,view.Y-100))
        frame.Size=UDim2.fromOffset(width,height)
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    task.defer(fit)
end

function Style.fitActions(gui: ScreenGui,attack: Frame,interact: TextButton)
    interact.AnchorPoint=Vector2.new(1,0.5)
    local function fit()
        if gui.AbsoluteSize.Y<320 then
            attack.Position=UDim2.new(1,-110,1,-92)
            interact.Position=UDim2.new(1,-181,1,-92)
        else
            attack.Position=UDim2.new(1,-12,0.54,0)
            interact.Position=UDim2.new(1,-12,0.54,-70)
        end
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    task.defer(fit)
end

function Style.text(control: TextLabel | TextButton,value: string)
    if control.Text~=value then control.Text=value end
end

return Style
