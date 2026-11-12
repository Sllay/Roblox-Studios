-- Staging-only mobile development lab. Read-only client diagnostics; no remotes.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Stats=game:GetService("Stats")
local ContentProvider=game:GetService("ContentProvider")
local W=workspace
if game.PlaceId~=93428341652658 then return end
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui");gui.Name="RSQualityPanel";gui.ResetOnSpawn=false;gui.Parent=player:WaitForChild("PlayerGui")
local function text(parent,class,name,size,pos,value)
    local o=Instance.new(class);o.Name=name;o.Size=size;o.Position=pos;o.BackgroundColor3=Color3.fromRGB(24,34,45)
    o.TextColor3=Color3.fromRGB(235,244,250);o.TextSize=14;o.Font=Enum.Font.Gotham;o.Text=value;o.Parent=parent;return o
end
local toggle=text(gui,"TextButton","Toggle",UDim2.fromOffset(150,34),UDim2.new(1,-162,0,12),"RS | Diagnóstico")
local panel=Instance.new("Frame");panel.Name="DevelopmentLab";panel.AnchorPoint=Vector2.new(1,0);panel.Position=UDim2.new(1,-12,0,52);panel.Size=UDim2.new(.48,0,.67,0);panel.BackgroundColor3=Color3.fromRGB(17,24,32);panel.Visible=false;panel.Parent=gui
local limit=Instance.new("UISizeConstraint");limit.MaxSize=Vector2.new(540,430);limit.MinSize=Vector2.new(245,150);limit.Parent=panel
local title=text(panel,"TextLabel","Title",UDim2.new(1,0,0,28),UDim2.new(),"RS DEVELOPMENT LAB");title.BackgroundTransparency=1;title.Font=Enum.Font.GothamBold
local tabs={"Mundo","Recursos","Vento","Física"}
local active="Mundo"
local buttons={}
local highlight=Instance.new("Highlight");highlight.Name="RSLocalInspector";highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;highlight.FillTransparency=.8;highlight.OutlineColor=Color3.fromRGB(255,206,85);highlight.Enabled=false;highlight.Parent=W
gui.Destroying:Connect(function() highlight:Destroy() end)
for i,name in tabs do
    local b=text(panel,"TextButton","Tab"..i,UDim2.new(.25,-2,0,30),UDim2.new((i-1)*.25,1,0,30),name)
    b.Activated:Connect(function() active=name;highlight.Enabled=false;highlight.Adornee=nil end)
    buttons[name]=b
end
local sc=Instance.new("ScrollingFrame");sc.Name="Readout";sc.Size=UDim2.new(1,-10,1,-98);sc.Position=UDim2.fromOffset(5,63);sc.BackgroundTransparency=1;sc.ScrollBarThickness=4;sc.AutomaticCanvasSize=Enum.AutomaticSize.Y;sc.CanvasSize=UDim2.new();sc.Parent=panel
local label=text(sc,"TextLabel","Report",UDim2.new(1,-10,0,0),UDim2.new(),"")
label.AutomaticSize=Enum.AutomaticSize.Y;label.BackgroundTransparency=1;label.TextWrapped=true;label.TextXAlignment=Enum.TextXAlignment.Left;label.TextYAlignment=Enum.TextYAlignment.Top
local marker=text(panel,"TextButton","Marker",UDim2.new(1,-10,0,29),UDim2.new(0,5,1,-33),"Destacar objeto próximo")
local selected=nil
marker.Activated:Connect(function()
    if highlight.Enabled then highlight.Enabled=false;highlight.Adornee=nil
    elseif selected and selected:IsDescendantOf(W) then highlight.Adornee=selected;highlight.Enabled=true end
end)
toggle.Activated:Connect(function() panel.Visible=not panel.Visible;if not panel.Visible then highlight.Enabled=false;highlight.Adornee=nil end end)
local frames,elapsed,fps=0,0,0
local samples={}
local p50,p95=0,0
RunService.RenderStepped:Connect(function(dt)
    frames+=1;elapsed+=dt
    if #samples<240 then table.insert(samples,dt*1000) end
    if elapsed>=1 then
        fps=math.round(frames/elapsed);frames=0;elapsed=0
        table.sort(samples);p50=samples[math.max(1,math.ceil(#samples*.5))] or 0;p95=samples[math.max(1,math.ceil(#samples*.95))] or 0;table.clear(samples)
    end
end)
local function attr(o,k)
    local value=o and o:GetAttribute(k)
    return if value==nil then "-" else tostring(value)
end
local function vec(v) return string.format("%.1f, %.1f, %.1f",v.X,v.Y,v.Z) end
local function terrainAt(p)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={W.Terrain}
    local h=W:Raycast(p+Vector3.yAxis*12,-Vector3.yAxis*100,params)
    return h and h.Position.Y or nil
end
local roots={"RSSceneBuilder","RSWorldVegetation","RSEnvironmentP4","RSEnvironmentP4Detail","RSManagedAssets","RSResourcesP45"}
local function scan(p)
    local counts={Stone=0,Stick=0,Tree=0,Bush=0,Rock=0};local partial=0
    local near={}
    for _,name in roots do
        local root=W:FindFirstChild(name)
        local models=root and (if name=="RSManagedAssets" then root else root:FindFirstChild("Models"))
        if not models then continue end
        for _,m in models:GetChildren() do
            if not m:IsA("Model") then continue end
            local sp=m:GetAttribute("RSSpecies") or m.Name
            local kind=m:GetAttribute("RSResourceType")
            if kind~="Stone" and kind~="Stick" then
                local lower=string.lower(tostring(sp))
                kind=if string.find(lower,"rock",1,true) then "Rock" elseif string.find(lower,"bush",1,true) then "Bush" elseif string.find(lower,"tree",1,true) or string.find(lower,"pine",1,true) then "Tree" else nil
            end
            if not kind then continue end
            if not m:FindFirstChildWhichIsA("MeshPart",true) then partial+=1;continue end
            local pos=m:GetPivot().Position
            local d=(Vector2.new(pos.X,pos.Z)-Vector2.new(p.X,p.Z)).Magnitude
            counts[kind]+=1
            if not near[kind] or d<near[kind].distance then near[kind]={model=m,distance=d,root=root} end
        end
    end
    return counts,near,partial
end
local function describe(row)
    if not row then return "Não carregado nesta sessão" end
    local m=row.model;local cf,s=m:GetBoundingBox();local h=terrainAt(cf.Position)
    local yExtent=(math.abs(cf.RightVector.Y)*s.X+math.abs(cf.UpVector.Y)*s.Y+math.abs(cf.LookVector.Y)*s.Z)/2
    local gap=if h then string.format("%.2f",cf.Position.Y-yExtent-h) else "sem ray"
    local part=m:FindFirstChildWhichIsA("MeshPart",true)
    local fetch="N/A"
    if part then local ok,status=pcall(function()return ContentProvider:GetAssetFetchStatus(part.MeshId)end);if ok then fetch=tostring(status) end end
    local folder=row.root:FindFirstChild("Collisions")
    local shaft=folder and folder:FindFirstChild(m.Name)
    return string.format("%s\nEspécie: %s | dist: %.1f\nPos: %s | tamanho: %s\nSolo: %s | base-solo: %s\nMesh: %s | grupo: %s | colisão: %s\nColisor tronco: %s | asset: %s",m.Name,attr(m,"RSSpecies"),row.distance,vec(cf.Position),vec(s),h and string.format("%.2f",h) or "N/A",gap,part and part.MeshId or "-",part and part.CollisionGroup or "-",part and tostring(part.CanCollide) or "-",shaft and shaft:IsA("BasePart") and vec(shaft.Size) or "-",fetch)
end
local resourceChoice="Stone"
local cycle=text(panel,"TextButton","Cycle",UDim2.fromOffset(85,25),UDim2.new(1,-88,0,1),"Pedra")
cycle.Visible=false
cycle.Activated:Connect(function() resourceChoice=if resourceChoice=="Stone" then "Stick" else "Stone";cycle.Text=if resourceChoice=="Stone" then "Pedra" else "Graveto";highlight.Enabled=false;highlight.Adornee=nil end)
while gui.Parent do
    task.wait(.5)
    if not panel.Visible then continue end
    for name,b in buttons do b.BackgroundColor3=if name==active then Color3.fromRGB(48,95,113) else Color3.fromRGB(24,34,45) end
    cycle.Visible=active=="Recursos"
    local c=player.Character;local hrp=c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then label.Text="Aguardando personagem";continue end
    local p=hrp.Position
    local root=W:FindFirstChild("RSCentralSpawns")
    local resource=W:FindFirstChild("RSResourcesP45")
    local wind=player:FindFirstChild("RSWindDiagnostics")
    local counts,near,partial=scan(p)
    local report={}
    if active=="Recursos" and near[resourceChoice] then
        local v=near[resourceChoice].model:GetPivot().Position-p
        marker.Text=string.format("Destacar | direção X %+.0f Z %+.0f",v.X,v.Z)
    else marker.Text="Destacar objeto próximo" end
    local function add(s)table.insert(report,s) end
    add(string.format("Place v%d | FPS %d | p50 %.1f / p95 %.1f ms",game.PlaceVersion,fps,p50,p95))
    if active=="Mundo" then
        local ok,mem=pcall(function()return Stats:GetTotalMemoryUsageMb()end)
        add("Posição: "..vec(p).." | Memória MB: "..(ok and string.format("%.0f",mem) or "N/A"))
        add("Carregados: "..counts.Tree.." árvores / "..counts.Bush.." arbustos / "..counts.Rock.." rochas")
        add("Spawn: "..attr(player,"RSSpawnPoint").." | "..attr(player,"RSSpawnStatus"))
        add("Raio / voxel: "..attr(root,"RSRaySpawns").." / "..attr(root,"RSVoxelSpawns"))
        add("Props raio / voxel / revisar: "..attr(root,"RSPropsPass").." / "..attr(root,"RSPropsEstimate").." / "..attr(root,"RSPropsReview"))
        add(describe(near.Tree));selected=near.Tree and near.Tree.model
    elseif active=="Recursos" then
        add("Carregados com mesh: "..counts.Stone.." pedras / "..counts.Stick.." gravetos | modelos parciais: "..partial)
        add("Servidor: "..attr(resource,"RSPhysicsStoneCount").." / "..attr(resource,"RSPhysicsStickCount").." | matriz: "..attr(resource,"RSPhysicsMatrixOK"))
        add("Próximo selecionado: "..resourceChoice);add(describe(near[resourceChoice]));selected=near[resourceChoice] and near[resourceChoice].model
    elseif active=="Vento" then
        add("Vento global: "..vec(W.GlobalWind));add("Elegíveis: "..attr(wind,"Eligible").." | ativos: "..attr(wind,"Active"))
        add("Árvores / arbustos: "..attr(wind,"ActiveTrees").." / "..attr(wind,"ActiveBushes"))
        add("Ângulo pico: "..attr(wind,"PeakAngleDegrees").." | custo ms: "..attr(wind,"MeanUpdateMs"))
        add("Rejeitados: "..attr(wind,"FlagRejected").." | não mapeados: "..attr(wind,"Unmapped"))
        add(describe(near.Tree));selected=near.Tree and near.Tree.model
    else
        add("Grupo jogador: "..hrp.CollisionGroup.." | backend: "..attr(resource,"RSPhysicsBackend"))
        add("Rochas físicas: "..attr(resource,"RSPhysicsLargeRockCount"))
        add("Mortes: "..attr(player,"RSDeaths").." | "..attr(player,"RSDeathStatus"))
        add("Ragdoll: "..attr(player,"RSDeathRig").." | juntas "..attr(player,"RSDeathJoints").." | colisores "..attr(player,"RSDeathColliders"))
        add("Min Y: "..attr(player,"RSDeathMinY").." | folga: "..attr(player,"RSDeathClearance").." | inclinação: "..attr(player,"RSDeathTilt"))
        add("Sonda servidor: "..attr(root,"RSServerProbeStatus").." / "..attr(root,"RSServerProbeY"))
        add("Rocha próxima:");add(describe(near.Rock));selected=near.Rock and near.Rock.model
    end
    if highlight.Enabled and (not selected or highlight.Adornee~=selected) then highlight.Enabled=false;highlight.Adornee=nil end
    label.Text=table.concat(report,"\n\n")
end
