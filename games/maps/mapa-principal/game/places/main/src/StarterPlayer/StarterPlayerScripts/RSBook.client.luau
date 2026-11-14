--!strict
local players=game:GetService("Players");local rs=game:GetService("ReplicatedStorage")
local transport=rs:WaitForChild("RSBookTransport",20);if not transport then return end
local remote=transport:WaitForChild("Request",10);if not remote or not remote:IsA("RemoteFunction") then return end
local View=require(script.Parent:WaitForChild("BookView") :: ModuleScript)
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
  local ok,result=pcall(function()return remote:InvokeServer("command",text)end)
  commandBusy=false
  view.cstatus.Text=if ok and result and result.ok then ("Criados: "..tostring(result.count)) else ("Falha: "..tostring(if ok and result then result.error else "serviço indisponível"))
 end)
end
view=View.new(players.LocalPlayer:WaitForChild("PlayerGui"),{refresh=refresh,command=command})
while view.gui.Parent do task.wait(3);if view.box.Visible then refresh(view.order) end end
