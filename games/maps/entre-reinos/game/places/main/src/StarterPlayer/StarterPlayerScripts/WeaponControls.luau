--!strict
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Ballistics=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("Ballistics"))
local Gesture=require(script.Parent:WaitForChild("PressGesture"))
local Hotbars=require(script.Parent:WaitForChild("Hotbars"))
local Quick=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Living"):WaitForChild("QuickItems"))
local Controls={}

type Call=(string,any)->any
function Controls.mount(player: Player,gui: ScreenGui,attack: TextButton,
        call: Call,feedback: (string)->())
    local bag: any={}
    local choose: (string)->()=function() end
    local bar=Hotbars.equipment(gui,function(mode) choose(mode) end)
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
        if selected~="bow" then
            local def=Quick.items[selected]
            if not def then return end
            task.spawn(function()
                local result=call(def.action,nil)
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
        bar.update(selected,bag,player:GetAttribute("ER_R3Arrows") or 0)
        attack.Text=if selected=="bow" then "MIRAR" elseif Quick.items[selected].action=="tool_use"
            then "USAR" else "ATACAR"
    end
    choose=function(mode: string)
        if not attack.Visible or swapping or mode==selected or not Quick.owned(mode,{items=bag}) then return end
        swapping=true
        cancelGesture()
        cancel()
        local result=call("select_weapon",mode)
        if result.ok then selected=mode end
        paint()
        swapping=false
    end
    local keys={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four,Enum.KeyCode.Five}
    Input.InputBegan:Connect(function(input,handled)
        if handled then return end
        local index=table.find(keys,input.KeyCode)
        if index then choose(Quick.order[index]);return end
        if input.KeyCode==Enum.KeyCode.ButtonL1 then
            local start=table.find(Quick.order,selected) or 1
            for step=1,#Quick.order do
                local mode=Quick.order[(start+step-1)%#Quick.order+1]
                if Quick.owned(mode,{items=bag}) then choose(mode);break end
            end
        end
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
    return {
        cancel=function() cancelGesture();cancel() end,
        show=function(value: boolean) bar.view.Visible=value end,
        update=function(values: any)
            bag=values or {}
            if not Quick.owned(selected,{items=bag}) then choose("sword") end
            paint()
        end,
    }
end
return Controls
