-- Local visual only. Physical boundary is unchanged; no downloaded texture.
-- A pool of three surfaces covers wall/wall/ceiling intersections.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "RSLocalBoundaryGrid"
folder.Parent = workspace
local R = 24
local SPACING = 4 -- hex width across flats, in studs
local SIDE = SPACING / math.sqrt(3)
local ROW = 1.5 * SIDE
local PIXELS = 8
local ACTIVATE = 32
local faces = {
    {normal=Vector3.new(-1,0,0),origin=Vector3.new(384,0,0),up=Vector3.yAxis},
    {normal=Vector3.new(1,0,0),origin=Vector3.new(-384,0,0),up=Vector3.yAxis},
    {normal=Vector3.new(0,0,-1),origin=Vector3.new(0,0,384),up=Vector3.yAxis},
    {normal=Vector3.new(0,0,1),origin=Vector3.new(0,0,-384),up=Vector3.yAxis},
    {normal=Vector3.new(0,-1,0),origin=Vector3.new(0,180,0),up=Vector3.zAxis},
}
for _, f in faces do
    f.right = CFrame.lookAt(f.origin, f.origin + f.normal, f.up).RightVector
end
local segments = {}
local extent = math.ceil((R + SIDE) / ROW) + 2
-- Three edges per hex; neighbors supply the other three. No duplicate edges.
for row = -extent, extent do
    for q = -extent, extent do
        local x, y = SPACING * (q + row * 0.5), ROW * row
        if x*x + y*y <= (R + SIDE)^2 then
            for k = 0, 2 do
                local a = math.rad(-90 + k*60)
                local b = a + math.pi/3
                local x1, y1 = x + SIDE*math.cos(a), y + SIDE*math.sin(a)
                local x2, y2 = x + SIDE*math.cos(b), y + SIDE*math.sin(b)
                table.insert(segments,{x1=x1,y1=y1,x2=x2,y2=y2,
                    x=(x1+x2)/2,y=(y1+y2)/2,angle=math.deg(math.atan2(y2-y1,x2-x1))})
            end
        end
    end
end
assert(#segments * 3 <= 1560, "Boundary visual instance budget exceeded")
local pools = {}
local function createPool()
    local part=Instance.new("Part")
    part.Name="HexGrid";part.Size=Vector3.new(R*2,R*2,0.05)
    part.Anchored=true;part.Transparency=1;part.CanCollide=false
    part.CanQuery=false;part.CanTouch=false;part.CastShadow=false;part.Parent=folder
    local gui=Instance.new("SurfaceGui")
    gui.Face=Enum.NormalId.Front;gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize=Vector2.new(R*2*PIXELS,R*2*PIXELS)
    gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.Enabled=false;gui.Parent=part
    local canvas=Instance.new("Frame")
    canvas.Size=UDim2.fromScale(1,1);canvas.BackgroundTransparency=1
    canvas.ClipsDescendants=true;canvas.Parent=gui
    local lines={}
    for i,s in segments do
        local line=Instance.new("Frame")
        line.AnchorPoint=Vector2.new(0.5,0.5);line.BorderSizePixel=0
        line.BackgroundColor3=Color3.fromRGB(54,169,255)
        line.Position=UDim2.fromOffset((s.x+R)*PIXELS,(s.y+R)*PIXELS)
        line.Size=UDim2.fromOffset(SIDE*PIXELS+0.6,1.6)
        line.Rotation=s.angle;line.BackgroundTransparency=1;line.Parent=canvas
        lines[i]=line
    end
    return {part=part,gui=gui,lines=lines}
end
local function within(w)
    return math.abs(w.X)<=384.1 and math.abs(w.Z)<=384.1 and w.Y<=180.1 and w.Y>=-128
end
local function draw(pool,f,p,distance)
    local center=p-f.normal*((p-f.origin):Dot(f.normal))
    local dx=(center-f.origin):Dot(f.right)
    local dy=-(center-f.origin):Dot(f.up)
    local row=math.round(dy/ROW)
    local q=math.round(dx/SPACING-row*0.5)
    local point=f.origin+f.right*(SPACING*(q+row*0.5))-f.up*(ROW*row)+f.normal*0.08
    pool.part.CFrame=CFrame.lookAt(point,point+f.normal,f.up)
    pool.gui.Enabled=true
    local fade=(1-distance/ACTIVATE)^1.5
    for i,s in segments do
        local a=point+f.right*s.x1-f.up*s.y1
        local b=point+f.right*s.x2-f.up*s.y2
        local midpoint=(a+b)*0.5
        local radial=(midpoint-center).Magnitude
        local alpha=if within(a) and within(b) then fade*math.max(0,1-radial/R)^0.8 else 0
        pool.lines[i].BackgroundTransparency=1-alpha*0.85
    end
end
script.Destroying:Connect(function() folder:Destroy() end)
while folder.Parent do
    task.wait(0.1)
    local hrp=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local count=0
    if hrp and hrp:IsA("BasePart") then
        local p=hrp.Position
        for _,f in faces do
            local distance=math.abs((p-f.origin):Dot(f.normal))
            if distance<ACTIVATE then
                count+=1
                if count>3 then break end
                if not pools[count] then pools[count]=createPool() end
                draw(pools[count],f,p,distance)
            end
        end
    end
    for i=count+1,#pools do pools[i].gui.Enabled=false end
end
