-- Local-only circular grid on invisible physical walls. No custom GPU shader.
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local folder=Instance.new("Folder");folder.Name="RSLocalBoundaryGrid";folder.Parent=workspace
local R=48
local STEP=8
local N=12
local faces={
    {normal=Vector3.new(-1,0,0),origin=Vector3.new(384,0,0),u=Vector3.zAxis,v=Vector3.yAxis},
    {normal=Vector3.new(1,0,0),origin=Vector3.new(-384,0,0),u=Vector3.zAxis,v=Vector3.yAxis},
    {normal=Vector3.new(0,0,-1),origin=Vector3.new(0,0,384),u=Vector3.xAxis,v=Vector3.yAxis},
    {normal=Vector3.new(0,0,1),origin=Vector3.new(0,0,-384),u=Vector3.xAxis,v=Vector3.yAxis},
    {normal=Vector3.new(0,-1,0),origin=Vector3.new(0,180,0),u=Vector3.xAxis,v=Vector3.zAxis},
}
for _,f in faces do
    local p=Instance.new("Part");p.Name="Grid";p.Size=Vector3.new(R*2,R*2,0.05)
    p.Anchored=true;p.Transparency=1;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=folder
    local gui=Instance.new("SurfaceGui");gui.Face=Enum.NormalId.Front;gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize=Vector2.new(N*16,N*16);gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.Enabled=false;gui.Parent=p
    local lines={}
    for i=0,N do for j=0,N-1 do
        for k=1,2 do
            local line=Instance.new("Frame");line.BorderSizePixel=0;line.BackgroundColor3=Color3.fromRGB(54,169,255)
            line.Position=UDim2.fromOffset(if k==1 then i*16 else j*16,if k==1 then j*16 else i*16)
            line.Size=UDim2.fromOffset(if k==1 then 2 else 16,if k==1 then 16 else 2);line.BackgroundTransparency=1;line.Parent=gui
            table.insert(lines,{frame=line,x=if k==1 then i*STEP-R else (j+0.5)*STEP-R,y=if k==1 then (j+0.5)*STEP-R else i*STEP-R})
        end
    end end
    f.part=p;f.gui=gui;f.lines=lines
end
while folder.Parent do
    task.wait(0.1)
    local hrp=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    for _,f in faces do
        if not hrp then f.gui.Enabled=false;continue end
        local p=hrp.Position
        local distance=math.abs((p-f.origin):Dot(f.normal))
        if distance>=32 then f.gui.Enabled=false;continue end
        local center=p-f.normal*((p-f.origin):Dot(f.normal))
        local u=math.round((center-f.origin):Dot(f.u)/STEP)*STEP
        local v=math.round((center-f.origin):Dot(f.v)/STEP)*STEP
        local point=f.origin+f.u*u+f.v*v+f.normal*0.08
        f.part.CFrame=CFrame.lookAt(point,point+f.normal,f.v)
        f.gui.Enabled=true
        local right=f.part.CFrame.RightVector
        local up=f.part.CFrame.UpVector
        local fade=(1-distance/32)^1.5
        for _,l in f.lines do
            local w=point+right*l.x-up*l.y
            local radial=(w-center).Magnitude
            local inside=math.abs(w.X)<=384.1 and math.abs(w.Z)<=384.1 and w.Y<=180.1 and w.Y>=-128
            local a=if inside then fade*math.max(0,1-radial/R)^0.8 else 0
            l.frame.BackgroundTransparency=1-a*0.85
        end
    end
end
