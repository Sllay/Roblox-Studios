--!strict
-- Mobile-friendly 2D Book. All species data is supplied by the server snapshot.
local V={}
local ink=Color3.fromRGB(232,237,220)
local dark=Color3.fromRGB(22,35,31)
local panelColor=Color3.fromRGB(34,52,43)
local accent=Color3.fromRGB(96,148,104)
local function corner(o:GuiObject,n:number)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,n);c.Parent=o end
local function label(parent:Instance,name:string,value:string,size:UDim2,pos:UDim2,font:number):TextLabel
 local l=Instance.new("TextLabel");l.Name=name;l.Text=value;l.Size=size;l.Position=pos;l.TextSize=font;l.Font=Enum.Font.Gotham;l.TextColor3=ink;l.BackgroundTransparency=1;l.TextWrapped=true;l.Parent=parent;return l
end
local function button(parent:Instance,name:string,value:string,size:UDim2,pos:UDim2):TextButton
 local b=Instance.new("TextButton");b.Name=name;b.Text=value;b.Size=size;b.Position=pos;b.Font=Enum.Font.GothamMedium;b.TextSize=14;b.TextColor3=ink;b.BackgroundColor3=panelColor;b.AutoButtonColor=true;b.Parent=parent;corner(b,8);return b
end
local function frame(parent:Instance,name:string,size:UDim2,pos:UDim2):Frame
 local f=Instance.new("Frame");f.Name=name;f.Size=size;f.Position=pos;f.BackgroundColor3=dark;f.Parent=parent;corner(f,12);return f
end
local function scroll(parent:Instance,name:string,size:UDim2,pos:UDim2):ScrollingFrame
 local f=Instance.new("ScrollingFrame");f.Name=name;f.Size=size;f.Position=pos;f.BackgroundTransparency=1;f.ScrollBarThickness=4;f.CanvasSize=UDim2.new();f.AutomaticCanvasSize=Enum.AutomaticSize.Y;f.Parent=parent
 local list=Instance.new("UIListLayout");list.Padding=UDim.new(0,6);list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=f;return f
end
local function clear(f:ScrollingFrame)for _,c in f:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end end
local function line(f:ScrollingFrame,name:string,value:string,height:number,font:number):TextLabel
 local l=label(f,name,value,UDim2.new(1,-8,0,height),UDim2.new(),font);l.TextXAlignment=Enum.TextXAlignment.Left;l.LayoutOrder=#f:GetChildren();return l
end
function V.new(parent:Instance,callbacks:any):any
 local gui=Instance.new("ScreenGui");gui.Name="RSBook";gui.ResetOnSpawn=false;gui.DisplayOrder=30;gui.Parent=parent
 local open=button(gui,"OpenBook","Book",UDim2.fromOffset(94,42),UDim2.new(0,12,1,-110))
 local box=frame(gui,"BookPanel",UDim2.fromScale(.94,.82),UDim2.fromScale(.5,.48));box.AnchorPoint=Vector2.new(.5,.5);box.Visible=false
 local limit=Instance.new("UISizeConstraint");limit.MaxSize=Vector2.new(800,560);limit.Parent=box
 label(box,"Title","BOOK  •  BLACK ISLANDS",UDim2.new(1,-75,0,36),UDim2.fromOffset(10,4),18)
 local close=button(box,"Close","X",UDim2.fromOffset(38,32),UDim2.new(1,-44,0,6))
 local progress=label(box,"Progress","Carregando...",UDim2.new(1,-20,0,28),UDim2.fromOffset(10,42),15)
 local tabs={};for i,n in {"Criaturas","Itens","Missões"} do tabs[n]=button(box,"Tab"..i,n,UDim2.new(1/3,-8,0,34),UDim2.new((i-1)/3,5,0,75)) end
 local sort=button(box,"Sort","Descoberta",UDim2.new(.48,-8,0,34),UDim2.fromOffset(6,116))
 local filter=button(box,"Filter","Todos",UDim2.new(.48,-8,0,34),UDim2.new(.5,4,0,116))
 local list=scroll(box,"SpeciesList",UDim2.new(.36,-10,1,-198),UDim2.fromOffset(8,158))
 local detail=scroll(box,"SpeciesDetail",UDim2.new(.64,-10,1,-198),UDim2.new(.36,0,0,158))
 local status=label(box,"Status","",UDim2.new(1,-20,0,26),UDim2.new(0,10,1,-31),12)
 local dev=button(box,"Developer","Dev",UDim2.fromOffset(58,28),UDim2.new(1,-64,1,-32));dev.Visible=false
 local console=frame(gui,"DeveloperConsole",UDim2.fromScale(.9,.33),UDim2.fromScale(.5,.5));console.AnchorPoint=Vector2.new(.5,.5);console.Visible=false
 local cap=Instance.new("UISizeConstraint");cap.MaxSize=Vector2.new(620,220);cap.Parent=console
 label(console,"ConsoleTitle","CONSOLE DE DESENVOLVEDOR",UDim2.new(1,-50,0,34),UDim2.fromOffset(8,4),16)
 local cclose=button(console,"Close","X",UDim2.fromOffset(38,30),UDim2.new(1,-44,0,5))
 local input=Instance.new("TextBox");input.Name="Command";input.PlaceholderText="/summon mob 210080 1 here true";input.Text="";input.ClearTextOnFocus=false;input.TextColor3=ink;input.PlaceholderColor3=Color3.fromRGB(160,180,168);input.BackgroundColor3=panelColor;input.TextSize=14;input.Font=Enum.Font.Code;input.Size=UDim2.new(1,-20,0,42);input.Position=UDim2.fromOffset(10,48);input.Parent=console;corner(input,8)
 local send=button(console,"Execute","Executar",UDim2.new(1,-20,0,36),UDim2.fromOffset(10,98))
 local cstatus=label(console,"Result","",UDim2.new(1,-20,0,44),UDim2.fromOffset(10,139),12)
 local self:any={gui=gui,box=box,progress=progress,list=list,detail=detail,status=status,dev=dev,console=console,cstatus=cstatus,order="Discovery",filter="Todos",tab="Criaturas",snapshot=nil,selected=nil}
 local function details(row:any)
  clear(detail);self.selected=row
  if not row then line(detail,"Empty","Descubra criaturas para preencher seu Book.",90,15);return end
  line(detail,"SpeciesName",row.name,32,20)
  local image=Instance.new("ImageLabel");image.Name="Preview";image.Size=UDim2.new(1,-8,0,150);image.BackgroundTransparency=1;image.ScaleType=Enum.ScaleType.Fit;image.Image=if row.previewAssetId then "rbxassetid://"..row.previewAssetId else "";image.LayoutOrder=#detail:GetChildren();image.Parent=detail
  line(detail,"Category",row.category.." • "..row.disposition,28,13)
  line(detail,"Biome","Bioma: "..table.concat(row.biomes,", "),36,13)
  line(detail,"Description",row.description,80,14)
  local a,b=row.stats.level1,row.stats.level10
  local function percent(x:number,y:number):string return if x==0 then "—" else string.format("%+.1f%%",100*(y/x-1)) end
  line(detail,"Stats","Nível 1 → "..row.stats.levelHigh,26,15)
  line(detail,"Health",string.format("Vida: %g → %g  (%s)",a.health,b.health,percent(a.health,b.health)),34,13)
  line(detail,"Damage",string.format("Dano: %g → %g  (%s)",a.damage,b.damage,percent(a.damage,b.damage)),34,13)
  line(detail,"Walk",string.format("Caminhada: %.3f → %.3f  (%s)",a.walkSpeed,b.walkSpeed,percent(a.walkSpeed,b.walkSpeed)),36,13)
  line(detail,"Run",string.format("Corrida: %.3f → %.3f  (%s)",a.runSpeed,b.runSpeed,percent(a.runSpeed,b.runSpeed)),36,13)
  if row.id then line(detail,"TechnicalId","ID técnico: "..row.id,32,13) end
 end
 function self:render()
  clear(list);local snap=self.snapshot
  if not snap or not snap.ready then progress.Text="Carregando descobertas...";details(nil);return end
  progress.Text=string.format("%d/%d descobertos • %.0f%%",snap.discovered,snap.total,snap.percent)
  self.dev.Visible=snap.developer==true
  if not self.dev.Visible then console.Visible=false end
  if self.tab~="Criaturas" then line(list,"Unavailable","Em breve",52,14);clear(detail);line(detail,"UnavailableDetail","Esta categoria ainda não está disponível.",90,14);return end
  local first=nil;local chosen=nil
  for _,row in snap.rows do
   if self.filter~="Todos" and row.disposition~=self.filter then continue end
   first=first or row
   if self.selected and self.selected.name==row.name then chosen=row end
   local b=button(list,"SpeciesRow",row.name,UDim2.new(1,-8,0,46),UDim2.new());b.LayoutOrder=#list:GetChildren();b.Activated:Connect(function()details(row)end)
  end
  if snap.unknown>0 then line(list,"Unknown",string.format("?  %d desconhecidos",snap.unknown),44,13) end
  details(chosen or first)
 end
 function self:update(snap:any)self.snapshot=snap;self:render()end
 function self:setStatus(text:string)status.Text=text end
 function self:show()box.Visible=true;callbacks.refresh(self.order)end
 function self:hide()box.Visible=false;console.Visible=false end
 open.Activated:Connect(function()if box.Visible then self:hide() else self:show() end end)
 close.Activated:Connect(function()self:hide()end)
 sort.Activated:Connect(function()self.order=if self.order=="Discovery" then "Alphabetical" else "Discovery";sort.Text=if self.order=="Discovery" then "Descoberta" else "A–Z";callbacks.refresh(self.order)end)
 local filters={"Todos","Passive","Neutral","Aggressive"};local labels={Todos="Todos",Passive="Passivos",Neutral="Neutros",Aggressive="Agressivos"};local fi=1
 filter.Activated:Connect(function()fi=fi%#filters+1;self.filter=filters[fi];filter.Text=labels[self.filter];self:render()end)
 for name,b in tabs do b.Activated:Connect(function()self.tab=name;self:render()end) end
 dev.Activated:Connect(function()if self.snapshot and self.snapshot.developer then console.Visible=true end end)
 cclose.Activated:Connect(function()console.Visible=false end)
 send.Activated:Connect(function()if self.snapshot and self.snapshot.developer then callbacks.command(input.Text) end end)
 return self
end
return table.freeze(V)
