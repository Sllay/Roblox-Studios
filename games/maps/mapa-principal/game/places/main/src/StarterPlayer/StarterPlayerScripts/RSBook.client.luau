--!strict
local players=game:GetService("Players");local rs=game:GetService("ReplicatedStorage")
local transport=rs:WaitForChild("RSBookTransport",20);if not transport then return end
local remote=transport:WaitForChild("Request",10);if not remote or not remote:IsA("RemoteFunction") then return end
local View=require(assert(script.Parent):WaitForChild("BookView") :: ModuleScript)
local view:any=nil;local busy=false;local commandBusy=false
local function refresh(order:string)
 if busy then return end;busy=true
 task.spawn(function()
  local ok,snap=pcall(function()return remote:InvokeServer("snapshot",order)end)
  busy=false
  if ok and snap and snap.ok then view:update(snap);view:setStatus("") else view:setStatus("Não foi possível atualizar. Tente novamente.") end
 end)
end
local function command(text:string)
 if commandBusy then return end;commandBusy=true
 task.spawn(function()
  local ok,result=pcall(function()return remote:InvokeServer("command",{text=text,direction=if workspace.CurrentCamera then workspace.CurrentCamera:ViewportPointToRay(workspace.CurrentCamera.ViewportSize.X*.5,workspace.CurrentCamera.ViewportSize.Y*.5).Direction.Unit else Vector3.zero})end)
  commandBusy=false
  view.cstatus.Text=if ok and result and result.ok then (result.message or ("Criados: "..tostring(result.count))) else ("Falha: "..tostring(if ok and result then result.error else "serviço indisponível"))
 end)
end
view=View.new(players.LocalPlayer:WaitForChild("PlayerGui"),{refresh=refresh,command=command})
refresh(view.order)
local player=players.LocalPlayer
local run=game:GetService("RunService")
local input=game:GetService("UserInputService")
local flightGui=Instance.new("ScreenGui");flightGui.Name="RSDevFlight";flightGui.ResetOnSpawn=false;flightGui.Parent=player:WaitForChild("PlayerGui")
local up=Instance.new("TextButton");up.Text="Subir";up.Size=UDim2.fromOffset(76,48);up.Position=UDim2.new(1,-90,.55,0);up.Parent=flightGui
local down=up:Clone();down.Text="Descer";down.Position=UDim2.new(1,-90,.55,56);down.Parent=flightGui
local vertical=0
up.InputBegan:Connect(function()vertical=1 end);up.InputEnded:Connect(function()vertical=0 end)
down.InputBegan:Connect(function()vertical=-1 end);down.InputEnded:Connect(function()vertical=0 end)
local saved:{[BasePart]:boolean}={}
local active:Model?=nil
local force:LinearVelocity?=nil
local attachment:Attachment?=nil
local function restore()
 for part,value in pairs(saved) do if part.Parent then part.CanCollide=value end end;table.clear(saved)
 if force then force:Destroy();force=nil end
 if attachment then attachment:Destroy();attachment=nil end
 if active then local h=active:FindFirstChildWhichIsA("Humanoid");if h then h.PlatformStand=false end end
 active=nil
end
run.Heartbeat:Connect(function()
 local c=player.Character;local mode=if c then c:GetAttribute("RSDevMode") else nil
 local flying=mode=="fly" or mode=="ghost";flightGui.Enabled=flying
 if not flying or not c then if active then restore() end;return end
 local root=c:FindFirstChild("HumanoidRootPart");local h=c:FindFirstChildWhichIsA("Humanoid")
 if not root or not root:IsA("BasePart") or not h then return end
 if active~=c then
  restore();active=c
  attachment=Instance.new("Attachment");attachment.Parent=root
  force=Instance.new("LinearVelocity");force.Attachment0=attachment;force.MaxForce=math.huge;force.RelativeTo=Enum.ActuatorRelativeTo.World;force.Parent=root
 end
 if mode=="ghost" then
  for _,part in c:GetDescendants() do if part:IsA("BasePart") then if saved[part]==nil then saved[part]=part.CanCollide end;part.CanCollide=false end end
 else for part,value in pairs(saved) do if part.Parent then part.CanCollide=value end end;table.clear(saved) end
 local y=vertical
 if input:IsKeyDown(Enum.KeyCode.Space) then y=1 elseif input:IsKeyDown(Enum.KeyCode.LeftControl) then y=-1 end
 if force then force.VectorVelocity=h.MoveDirection*24+Vector3.new(0,y*24,0) end
end)
while view.gui.Parent do task.wait(3);if view.box.Visible or not view.snapshot or not view.snapshot.ready then refresh(view.order) end end
