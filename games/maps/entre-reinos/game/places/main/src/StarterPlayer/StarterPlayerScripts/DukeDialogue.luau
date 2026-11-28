--!strict
local Camera=require(script.Parent:WaitForChild("SideCamera"))
local Lane=require(script.Parent:WaitForChild("LaneController"))
local Dialogue={}
local lines={
    "O ar aqui dentro tem gosto de pedra. Quero ver o que cresce além do portão.",
    "O capitão insiste que eu espere até o amanhecer. Ora, leve sua espada e ande comigo. Voltaremos antes do jantar.",
}

function Dialogue.mount(gui: ScreenGui,call: (string,any)->any,changed: (boolean)->()): (()->(),()->())
    local panel=Instance.new("Frame")
    panel.AnchorPoint=Vector2.new(0.5,1)
    panel.Position=UDim2.new(0.5,0,1,-16)
    panel.Size=UDim2.new(1,-28,0,145)
    panel.BackgroundColor3=Color3.fromRGB(34,38,32)
    panel.Visible=false
    panel.Parent=gui
    local cap=Instance.new("UISizeConstraint")
    cap.MaxSize=Vector2.new(590,145)
    cap.Parent=panel
    local round=Instance.new("UICorner")
    round.CornerRadius=UDim.new(0,12)
    round.Parent=panel
    local outline=Instance.new("UIStroke")
    outline.Color=Color3.fromRGB(168,128,68)
    outline.Parent=panel

    local portrait=Instance.new("ViewportFrame")
    portrait.Size=UDim2.fromOffset(69,91)
    portrait.Position=UDim2.fromOffset(10,13)
    portrait.BackgroundColor3=Color3.fromRGB(62,51,43)
    portrait.Ambient=Color3.fromRGB(196,167,125)
    portrait.Parent=panel
    local portraitCamera=Instance.new("Camera")
    portraitCamera.CFrame=CFrame.lookAt(Vector3.new(0,2.2,-4.7),Vector3.new(0,1.9,0))
    portraitCamera.Parent=portrait
    portrait.CurrentCamera=portraitCamera
    local bust=Instance.new("WorldModel")
    bust.Parent=portrait
    local function text(name: string,position: UDim2,size: UDim2,bold: boolean): TextLabel
        local label=Instance.new("TextLabel")
        label.Name=name
        label.Position=position
        label.Size=size
        label.BackgroundTransparency=1
        label.TextColor3=Color3.fromRGB(246,226,187)
        label.TextXAlignment=Enum.TextXAlignment.Left
        label.TextYAlignment=Enum.TextYAlignment.Top
        label.TextWrapped=true
        label.Font=if bold then Enum.Font.GothamBold else Enum.Font.Gotham
        label.TextSize=if bold then 15 else 13
        label.Parent=panel
        return label
    end
    text("DukeName",UDim2.fromOffset(91,12),UDim2.new(1,-120,0,24),true).Text="Duque"
    local speech=text("Speech",UDim2.fromOffset(91,41),UDim2.new(1,-103,0,61),false)
    local advance=Instance.new("TextButton")
    advance.AnchorPoint=Vector2.new(1,1)
    advance.Position=UDim2.new(1,-12,1,-10)
    advance.Size=UDim2.fromOffset(112,34)
    advance.TextColor3=Color3.fromRGB(254,236,194)
    advance.BackgroundColor3=Color3.fromRGB(76,87,61)
    advance.Font=Enum.Font.GothamMedium
    advance.TextSize=13
    advance.Parent=panel
    local dismiss=Instance.new("TextButton")
    dismiss.AnchorPoint=Vector2.new(1,0)
    dismiss.Position=UDim2.new(1,-6,0,5)
    dismiss.Size=UDim2.fromOffset(35,33)
    dismiss.Text="×"
    dismiss.TextSize=22
    dismiss.TextColor3=Color3.fromRGB(240,221,185)
    dismiss.BackgroundTransparency=1
    dismiss.Parent=panel
    local page=1
    local busy=false
    local function close()
        if not panel.Visible then return end
        panel.Visible=false
        bust:ClearAllChildren()
        Camera.focusActor(nil)
        Lane.setPaused(false)
        changed(false)
    end
    local function cancel()
        if not panel.Visible then return end
        close()
        task.spawn(call,"duke_close",nil)
    end
    local function refresh()
        speech.Text=lines[page]
        advance.Text=if page==#lines then "Acompanhar" else "Continuar"
    end
    advance.Activated:Connect(function()
        if busy then return end
        if page<#lines then page+=1;refresh();return end
        busy=true
        local result=call("duke_accept",nil)
        busy=false
        if result.ok then close() end
    end)
    dismiss.Activated:Connect(cancel)
    return function()
        if busy or panel.Visible then return end
        busy=true
        local result=call("duke_talk",nil)
        busy=false
        if not result.ok then return end
        local world=workspace:FindFirstChild("ER_LivingWorld")
        local actor=if world then world:FindFirstChild("Story_duke") else nil
        if actor and actor:IsA("Model") then
            local clone=actor:Clone()
            clone:PivotTo(CFrame.new())
            clone.Parent=bust
            Camera.focusActor(actor)
        end
        page=1
        refresh()
        panel.Visible=true
        Lane.setPaused(true)
        changed(true)
    end,cancel
end
return Dialogue
