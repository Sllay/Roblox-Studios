--!strict
-- Client crosshair only; discovery and kill are independently validated by server.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local rs=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
player.CameraMode=Enum.CameraMode.LockFirstPerson
player:GetPropertyChangedSignal("CameraMode"):Connect(function()if player.CameraMode~=Enum.CameraMode.LockFirstPerson then player.CameraMode=Enum.CameraMode.LockFirstPerson end end)
local gui=Instance.new("ScreenGui");gui.Name="RSCrosshair";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=20;gui.Parent=player:WaitForChild("PlayerGui")
local aim=Instance.new("Frame");aim.Name="Aim";aim.AnchorPoint=Vector2.new(.5,.5);aim.Position=UDim2.fromScale(.5,.5);aim.Size=UDim2.fromOffset(24,24);aim.BackgroundTransparency=1;aim.Parent=gui
local bars:{Frame}={}
for _,v in {{10,0,3,8},{10,16,3,8},{0,10,8,3},{16,10,8,3}} do
 local b=Instance.new("Frame");b.Size=UDim2.fromOffset(v[3],v[4]);b.Position=UDim2.fromOffset(v[1],v[2]);b.BackgroundColor3=Color3.new(1,1,1);b.BorderSizePixel=0;b.Parent=aim;table.insert(bars,b)
end
local target=Instance.new("TextLabel");target.Name="Target";target.AnchorPoint=Vector2.new(.5,0);target.Position=UDim2.new(.5,0,.5,22);target.Size=UDim2.fromOffset(160,26);target.BackgroundTransparency=.25;target.BackgroundColor3=Color3.fromRGB(22,35,29);target.TextColor3=Color3.new(1,1,1);target.TextSize=14;target.Font=Enum.Font.GothamMedium;target.Visible=false;target.Parent=gui
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.IgnoreWater=false
local elapsed=0;local focusId:string?=nil;local focusAge=0;local submitted:{[string]:number}={};local pending=false
RunService.RenderStepped:Connect(function(dt:number)
 elapsed+=dt;if elapsed<.05 then return end;local step=elapsed;elapsed=0
 local book=player.PlayerGui:FindFirstChild("RSBook")
 local open=book and book:FindFirstChild("BookPanel");local console=book and book:FindFirstChild("DeveloperConsole")
 local hidden=(open and open:IsA("GuiObject") and open.Visible) or (console and console:IsA("GuiObject") and console.Visible)
 gui.Enabled=not hidden
 local camera=workspace.CurrentCamera;local character=player.Character
 local id:string?=nil;local model:Model?=nil;local direction=Vector3.zero
 if not hidden and camera and character then
  params.FilterDescendantsInstances={character}
  local ray=camera:ViewportPointToRay(camera.ViewportSize.X*.5,camera.ViewportSize.Y*.5)
  direction=ray.Direction.Unit
  local hit=workspace:Raycast(ray.Origin,direction*8,params)
  if hit then
   local m=hit.Instance:FindFirstAncestorOfClass("Model")
   while m do
    local value=m:GetAttribute("CreatureInstanceId")
    if type(value)=="string" and (m:GetAttribute("CreatureHealth") or 0)>0 then id=value;model=m;break end
    local parent=m.Parent;m=if parent then parent:FindFirstAncestorOfClass("Model") else nil
   end
  end
 end
 for _,b in bars do b.BackgroundColor3=if id then Color3.fromRGB(255,66,66) else Color3.new(1,1,1) end
 target.Visible=id~=nil;target.Text=if model then tostring(model:GetAttribute("CreatureDisplayName") or "Criatura") else ""
 if id~=focusId then focusId=id;focusAge=0 else focusAge+=step end
 if id and model and model:GetAttribute("CreatureOrigin")=="Natural" and focusAge>=.4 and not pending and os.clock()-(submitted[id] or -math.huge)>5 then
  local transport=rs:FindFirstChild("RSBookTransport");local remote=transport and transport:FindFirstChild("Request")
  if remote and remote:IsA("RemoteFunction") then
   pending=true;submitted[id]=os.clock();local requested=id;local aimDirection=direction
   task.spawn(function()pcall(function()remote:InvokeServer("discover",{id=requested,direction=aimDirection})end);pending=false end)
  end
 end
end)
