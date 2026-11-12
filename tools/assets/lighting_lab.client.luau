
-- Staging-only visual diagnosis. No server writes; original lighting restored on exit.
local Players=game:GetService("Players")
local Lighting=game:GetService("Lighting")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui")
gui.Name="RSLightingLab"
gui.ResetOnSpawn=false
gui.Parent=player:WaitForChild("PlayerGui")
local panel=Instance.new("Frame")
panel.Size=UDim2.fromOffset(308,114)
panel.Position=UDim2.new(1,-316,0,8)
panel.BackgroundColor3=Color3.fromRGB(24,34,44)
panel.BackgroundTransparency=0.14
panel.Parent=gui
local label=Instance.new("TextLabel")
label.Size=UDim2.new(1,0,0,26)
label.BackgroundTransparency=1
label.TextColor3=Color3.new(1,1,1)
label.TextSize=14
label.Text="P1 | Laboratorio visual"
label.Parent=panel
local function button(text,x,y,w)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(w,36)
    b.Position=UDim2.fromOffset(x,y)
    b.BackgroundColor3=Color3.fromRGB(53,75,94)
    b.TextColor3=Color3.new(1,1,1)
    b.TextSize=14
    b.Text=text
    b.Parent=panel
    return b
end
local start=button("Abrir teste",4,30,148)
local compare=button("A: importada",156,30,148)
local angle=button("Frente",4,72,96)
local mode=button("Luz original",104,72,200)
local active=false
local usingControl=false
local angleIndex=1
local lightIndex=1
local angles={"Frente","Lado","Contra sol"}
local modes={"Luz original","Sem especular","Exposicao -0.7","Sem raios/bloom","Sol 50%"}
local original,control,camera,backup
local hidden={}
local effects={}
local function restoreLight()
    if not backup then return end
    Lighting.EnvironmentSpecularScale=backup.spec
    Lighting.ExposureCompensation=backup.exposure
    Lighting.Brightness=backup.brightness
    for obj,value in effects do if obj.Parent then obj.Enabled=value end end
end
local function setLight()
    restoreLight()
    if lightIndex==2 then Lighting.EnvironmentSpecularScale=0
    elseif lightIndex==3 then Lighting.ExposureCompensation=math.max(-5,backup.exposure-0.7)
    elseif lightIndex==4 then for obj in effects do if obj.Parent then obj.Enabled=false end end
    elseif lightIndex==5 then Lighting.Brightness=backup.brightness*0.5 end
    mode.Text=modes[lightIndex]
end
local function showControl()
    for part,state in hidden do
        part.LocalTransparencyModifier=if usingControl then 1 else state.transparency
        part.CastShadow=if usingControl then false else state.shadow
    end
    control.Parent=if usingControl then workspace else nil
    compare.Text=if usingControl then "B: fonte original" else "A: importada"
end
local function view()
    local bb,size=original:GetBoundingBox()
    local target=bb.Position
    local sun=Lighting:GetSunDirection()
    local flat=Vector3.new(sun.X,0,sun.Z)
    if flat.Magnitude<0.001 then flat=Vector3.new(0,0,1) end
    flat=flat.Unit
    local radians=({0,math.pi/2,math.pi})[angleIndex]
    local direction=CFrame.Angles(0,radians,0):VectorToWorldSpace(flat)
    local distance=math.max(size.Y*1.55,55)
    camera.CameraType=Enum.CameraType.Scriptable
    camera.FieldOfView=50
    camera.CFrame=CFrame.lookAt(target+direction*distance+Vector3.new(0,5,0),target)
    camera.Focus=CFrame.new(target)
    angle.Text=angles[angleIndex]
    label.Text="P1 | "..angles[angleIndex].." | "..modes[lightIndex]
end
local function stop()
    if not active then return end
    active=false
    restoreLight()
    for part,state in hidden do if part.Parent then part.LocalTransparencyModifier=state.transparency;part.CastShadow=state.shadow end end
    table.clear(hidden)
    if control then control:Destroy();control=nil end
    if camera and backup then
        camera.FieldOfView=backup.fov
        camera.CameraType=backup.cameraType
        camera.CameraSubject=backup.subject
        camera.CFrame=backup.cframe
        camera.Focus=backup.focus
    end
    backup=nil;table.clear(effects)
    start.Text="Abrir teste"
    label.Text="P1 | Laboratorio visual"
end
start.Activated:Connect(function()
    if active then stop();return end
    local root=workspace:FindFirstChild("RSManagedAssets")
    original=root and root:FindFirstChild("yasu-tree-01")
    local source=RS:FindFirstChild("RSLightingLabSource")
    camera=workspace.CurrentCamera
    if not original or not original:IsA("Model") or not source or not source:IsA("Model") or not camera then label.Text="Aguarde carregar a arvore";return end
    backup={spec=Lighting.EnvironmentSpecularScale,exposure=Lighting.ExposureCompensation,brightness=Lighting.Brightness,
        fov=camera.FieldOfView,cameraType=camera.CameraType,subject=camera.CameraSubject,cframe=camera.CFrame,focus=camera.Focus}
    for _,rootObj in {Lighting,camera} do
        for _,obj in rootObj:GetDescendants() do if obj:IsA("SunRaysEffect") or obj:IsA("BloomEffect") then effects[obj]=obj.Enabled end end
    end
    for _,obj in original:GetDescendants() do
        if obj:IsA("BasePart") then hidden[obj]={transparency=obj.LocalTransparencyModifier,shadow=obj.CastShadow} end
    end
    control=source:Clone()
    control:PivotTo(original:GetPivot())
    active=true;usingControl=false;angleIndex=1;lightIndex=1
    start.Text="Sair / restaurar"
    showControl();setLight();view()
end)
compare.Activated:Connect(function() if active then usingControl=not usingControl;showControl() end end)
angle.Activated:Connect(function() if active then angleIndex=angleIndex%#angles+1;view() end end)
mode.Activated:Connect(function() if active then lightIndex=lightIndex%#modes+1;setLight();view() end end)
player.CharacterAdded:Connect(stop)
gui.Destroying:Connect(stop)
