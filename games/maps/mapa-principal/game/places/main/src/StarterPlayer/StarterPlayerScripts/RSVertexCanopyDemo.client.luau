-- Staging diagnostic only: one owned, local, nonphysical canopy. Never edits imported trees.
local A=game:GetService("AssetService")
local P=game:GetService("Players").LocalPlayer
local R=game:GetService("RunService")
local W=workspace
if game.PlaceId~=93428341652658 then return end
local D=require(game:GetService("ReplicatedStorage"):WaitForChild("RSCanopyDeform"))
local mesh,part,connection=nil,nil,nil
local generation=0
local function cleanup()
    if connection then connection:Disconnect();connection=nil end
    if part then part:Destroy();part=nil end
    if mesh then mesh:Destroy();mesh=nil end
end
local function request()
    generation+=1
    local token=generation
    cleanup()
    if not P:GetAttribute("RSVertexDemoRequested") then P:SetAttribute("RSVertexDemoStatus","desativado");return end
    P:SetAttribute("RSVertexDemoStatus","carregando")
    task.spawn(function()
        local em,visual
        local ok,err=pcall(function()
            em=A:CreateEditableMeshAsync(Content.fromUri("rbxassetid://91110653005310"),{FixedSize=true})
            assert(em,"Memória de mesh")
            local ids=em:GetVertices();assert(#ids<=D.maxVertices,"Limite de vértices")
            local rest={};local low,high,x0,x1,z0,z1=math.huge,-math.huge,math.huge,-math.huge,math.huge,-math.huge
            for _,id in ids do
                local p=em:GetPosition(id);rest[id]=p;low=math.min(low,p.Y);high=math.max(high,p.Y)
                x0=math.min(x0,p.X);x1=math.max(x1,p.X);z0=math.min(z0,p.Z);z1=math.max(z1,p.Z)
            end
            visual=A:CreateMeshPartAsync(Content.fromObject(em),{CollisionFidelity=Enum.CollisionFidelity.Box})
            if token~=generation then return end
            local c=P.Character;local hrp=c and c:FindFirstChild("HumanoidRootPart")
            assert(hrp and hrp:IsA("BasePart"),"Personagem indisponível")
            local pos=hrp.Position+hrp.CFrame.LookVector*12
            local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Include;rp.FilterDescendantsInstances={W.Terrain}
            local hit=W:Raycast(pos+Vector3.yAxis*30,-Vector3.yAxis*100,rp)
            local ground=if hit then hit.Position.Y else hrp.Position.Y-3
            visual.Name="RSVertexCanopyDemo";visual.Anchored=true;visual.CanCollide=false;visual.CanTouch=false;visual.CanQuery=false
            visual.Color=Color3.fromRGB(55,133,76);visual.Material=Enum.Material.SmoothPlastic
            visual.CFrame=CFrame.new(pos.X,ground+visual.Size.Y/2+1,pos.Z);visual.Parent=W
            mesh=em;part=visual
            local width=math.max(x1-x0,z1-z0)
            local elapsed=0;local n,cost=0,0
            P:SetAttribute("RSVertexDemoStatus","ativo: "..#ids.." vértices")
            connection=R.Heartbeat:Connect(function(dt)
                if token~=generation then return end
                local camera=W.CurrentCamera
                if not camera or (camera.CFrame.Position-visual.Position).Magnitude>80 then P:SetAttribute("RSVertexDemoRequested",false);return end
                elapsed+=dt;if elapsed<D.interval then return end;elapsed=0
                local start=os.clock()
                local wind=W.GlobalWind;local h=Vector3.new(wind.X,0,wind.Z);local strength=h.Magnitude
                local dir=if strength>.01 then h.Unit else Vector3.xAxis
                local time=W:GetServerTimeNow()
                for _,id in ids do local p=rest[id];em:SetPosition(id,p+D.displacement(p,low,high,width,time,.6,dir,strength)) end
                cost+=(os.clock()-start)*1000;n+=1
                if n>=12 then P:SetAttribute("RSVertexDemoMs",math.round(cost/n*100)/100);n=0;cost=0 end
            end)
        end)
        if token~=generation or not ok then
            if visual then visual:Destroy() end
            if em then em:Destroy() end
            if token==generation then cleanup();P:SetAttribute("RSVertexDemoStatus","indisponível: "..tostring(err):sub(1,150)) end
        end
    end)
end
P:GetAttributeChangedSignal("RSVertexDemoRequested"):Connect(request)
script.Destroying:Connect(function() generation+=1;cleanup() end)
