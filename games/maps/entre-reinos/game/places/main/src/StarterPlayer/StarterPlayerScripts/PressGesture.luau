--!strict
local Input=game:GetService("UserInputService")
local Gui=game:GetService("GuiService")
local Gesture={}

function Gesture.bind(button: GuiButton,onStart: ()->(),onEnd: (boolean)->(),
        keys: {Enum.KeyCode}): ()->()
    local pressed: InputObject?=nil
    local function finish(cancelled: boolean)
        if not pressed then return end
        pressed=nil
        onEnd(cancelled)
    end
    local function start(input: InputObject)
        if pressed or not button.Visible or not button.Active then return end
        pressed=input
        onStart()
    end
    button.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch
            or input.UserInputType==Enum.UserInputType.MouseButton1 then start(input) end
    end)
    Input.InputBegan:Connect(function(input,handled)
        if not handled and table.find(keys,input.KeyCode) then start(input) end
    end)
    Input.InputEnded:Connect(function(input)
        if input==pressed then finish(false) end
    end)
    Input.InputChanged:Connect(function(input)
        local current=pressed
        if not current or (current.UserInputType~=Enum.UserInputType.Touch
            and current.UserInputType~=Enum.UserInputType.MouseButton1) then return end
        local mouse=current.UserInputType==Enum.UserInputType.MouseButton1
            and input.UserInputType==Enum.UserInputType.MouseMovement
        if input~=current and not mouse then return end
        local inset=Gui:GetGuiInset()
        local p=Vector2.new(input.Position.X,input.Position.Y)-inset
        local a=button.AbsolutePosition
        local b=a+button.AbsoluteSize
        if p.X<a.X-10 or p.X>b.X+10 or p.Y<a.Y-10 or p.Y>b.Y+10 then finish(true) end
    end)
    button:GetPropertyChangedSignal("Visible"):Connect(function()
        if not button.Visible then finish(true) end
    end)
    Gui.MenuOpened:Connect(function() finish(true) end)
    Input.WindowFocusReleased:Connect(function() finish(true) end)
    return function() finish(true) end
end

return Gesture
