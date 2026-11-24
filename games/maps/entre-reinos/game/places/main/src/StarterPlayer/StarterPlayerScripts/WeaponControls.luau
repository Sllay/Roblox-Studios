--!strict
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Ballistics=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("Ballistics"))
local Gesture=require(script.Parent:WaitForChild("PressGesture"))
local Controls={}

type Call=(string,any)->any
function Controls.mount(player: Player,attack: TextButton,sword: TextButton,bow: TextButton,
        call: Call,feedback: (string)->()): ()->()
    local selected="sword"
    local pressing: any=nil
    local swapping=false
    local dots: {Part}={}
    local function hide()
        for _,dot in ipairs(dots) do dot.Transparency=1 end
    end
    local function cancel()
        local old=pressing
        pressing=nil
        hide()
        if old and old.id then task.spawn(call,"bow_cancel",old.id) end
    end
    local function release(p: any)
        if pressing~=p or not p.id then return end
        pressing=nil
        hide()
        local result=call("bow_release",p.id)
        if result.ok then feedback("Flecha disparada.") end
    end
    local cancelGesture=Gesture.bind(attack,function()
        if swapping then return end
        if selected=="sword" then
            task.spawn(function()
                local result=call("attack",nil)
                if result.ok and result.hit then feedback("Inimigo atingido.") end
            end)
            return
        end
        if pressing then cancel() end
        local p={started=workspace:GetServerTimeNow(),released=false}
        pressing=p
        task.spawn(function()
            local result=call("bow_begin",nil)
            if pressing~=p then
                if result.ok then call("bow_cancel",result.id) end
                return
            end
            if not result.ok then cancel();return end
            p.started=result.started
            p.id=result.id
            if p.released then release(p) end
        end)
    end,function(cancelled)
        if cancelled then cancel();return end
        local p=pressing
        if p then p.released=true; task.spawn(release,p) end
    end,{Enum.KeyCode.F,Enum.KeyCode.ButtonX})

    local function paint()
        local on=Color3.fromRGB(77,100,71)
        local off=Color3.fromRGB(40,49,43)
        sword.BackgroundColor3=if selected=="sword" then on else off
        bow.BackgroundColor3=if selected=="bow" then on else off
        bow.Text="2 ARCO\n"..tostring(player:GetAttribute("ER_R3Arrows") or 0).." flechas"
        attack.Text=if selected=="bow" then "MIRAR" else "ATACAR"
    end
    local function selectWeapon(mode: string)
        if not attack.Visible or swapping or mode==selected then return end
        swapping=true
        cancelGesture()
        cancel()
        local result=call("select_weapon",mode)
        if result.ok then selected=mode end
        paint()
        swapping=false
    end
    sword.Activated:Connect(function() selectWeapon("sword") end)
    bow.Activated:Connect(function() selectWeapon("bow") end)
    Input.InputBegan:Connect(function(input,handled)
        if handled then return end
        if input.KeyCode==Enum.KeyCode.One then selectWeapon("sword")
        elseif input.KeyCode==Enum.KeyCode.Two then selectWeapon("bow")
        elseif input.KeyCode==Enum.KeyCode.ButtonL1 then selectWeapon(if selected=="sword" then "bow" else "sword") end
    end)
    player.CharacterRemoving:Connect(function() cancelGesture();cancel() end)
    player:GetAttributeChangedSignal("ER_R3Arrows"):Connect(paint)
    paint()

    local accumulator=0
    local cast=RaycastParams.new()
    cast.FilterType=Enum.RaycastFilterType.Include
    cast.FilterDescendantsInstances={workspace.Terrain}
    cast.IgnoreWater=true
    RunService.RenderStepped:Connect(function(dt)
        if not pressing or pressing.released then return end
        accumulator+=dt
        if accumulator<0.045 then return end
        accumulator=0
        local character=player.Character
        local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
        if not root or not root:IsA("BasePart") then cancel();return end
        local now=workspace:GetServerTimeNow()
        if now-pressing.started>Ballistics.MAX_HOLD then cancel();return end
        local sign=if root.CFrame.LookVector.X>=0 then 1 else -1
        local vx,vy=Ballistics.velocity(now-pressing.started)
        local origin=Vector3.new(root.Position.X+sign*1.1,root.Position.Y+0.9,0)
        local span=math.clamp(2*vy/workspace.Gravity,0.18,0.85)
        local previous=origin
        local obstructed=false
        for i=1,12 do
            local dot=dots[i]
            if not dot then
                dot=Instance.new("Part")
                dot.Name="ER_AimDot"
                dot.Shape=Enum.PartType.Ball
                dot.Size=Vector3.new(0.24,0.24,0.24)
                dot.Color=Color3.fromRGB(245,210,125)
                dot.Material=Enum.Material.Neon
                dot.Anchored=true
                dot.CanCollide=false
                dot.CanTouch=false
                dot.CanQuery=false
                dot.CastShadow=false
                dot.Parent=workspace
                dots[i]=dot
            end
            local x,y=Ballistics.offset(sign*vx,vy,workspace.Gravity,i*span/12)
            local point=origin+Vector3.new(x,y,0)
            if not obstructed and workspace:Raycast(previous,point-previous,cast) then obstructed=true end
            dot.Position=point
            dot.Transparency=if obstructed then 1 else 0.15+i*0.034
            previous=point
        end
    end)
    return function()
        cancelGesture()
        cancel()
    end
end
return Controls
