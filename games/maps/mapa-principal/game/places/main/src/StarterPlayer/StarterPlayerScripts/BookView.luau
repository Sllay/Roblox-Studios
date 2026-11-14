--!strict
-- Full-screen field guide; list and species detail are mutually exclusive pages.
local V={}
local ink=Color3.fromRGB(235,239,221)
local dark=Color3.fromRGB(18,30,25)
local panel=Color3.fromRGB(37,58,46)
local accent=Color3.fromRGB(135,177,123)
local function round(o:GuiObject,n:number)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,n);c.Parent=o end
local function frame(parent:Instance,name:string,size:UDim2,pos:UDim2,color:Color3?):Frame
 local f=Instance.new("Frame");f.Name=name;f.Size=size;f.Position=pos;f.BackgroundColor3=color or dark;f.BorderSizePixel=0;f.Parent=parent;return f
end
local function label(parent:Instance,name:string,value:string,size:UDim2,pos:UDim2,font:number):TextLabel
 local l=Instance.new("TextLabel");l.Name=name;l.Text=value;l.Size=size;l.Position=pos;l.TextSize=font;l.Font=Enum.Font.Gotham;l.TextColor3=ink;l.BackgroundTransparency=1;l.TextWrapped=true;l.Parent=parent;return l
end
local function button(parent:Instance,name:string,value:string,size:UDim2,pos:UDim2):TextButton
 local b=Instance.new("TextButton");b.Name=name;b.Text=value;b.Size=size;b.Position=pos;b.Font=Enum.Font.GothamMedium;b.TextSize=15;b.TextColor3=ink;b.BackgroundColor3=panel;b.BorderSizePixel=0;b.AutoButtonColor=true;b.Parent=parent;round(b,8);return b
end
local function scroll(parent:Instance,name:string,size:UDim2,pos:UDim2):ScrollingFrame
 local f=Instance.new("ScrollingFrame");f.Name=name;f.Size=size;f.Position=pos;f.BackgroundTransparency=1;f.ScrollBarThickness=5;f.BorderSizePixel=0;f.CanvasSize=UDim2.new();f.AutomaticCanvasSize=Enum.AutomaticSize.Y;f.Parent=parent
 local list=Instance.new("UIListLayout");list.Padding=UDim.new(0,8);list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=f;return f
end
local function clear(f:Instance)for _,c in f:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end end
local function line(f:ScrollingFrame,name:string,value:string,height:number,font:number):TextLabel
 local l=label(f,name,value,UDim2.new(1,-12,0,height),UDim2.new(),font);l.TextXAlignment=Enum.TextXAlignment.Left;l.LayoutOrder=#f:GetChildren();return l
end
function V.new(parent:Instance,callbacks:any):any
 local gui=Instance.new("ScreenGui");gui.Name="RSBook";gui.ResetOnSpawn=false;gui.DisplayOrder=30;gui.IgnoreGuiInset=false;gui.Parent=parent
 local toolbar=frame(gui,"TopToolbar",UDim2.fromOffset(172,40),UDim2.new(.5,0,0,6));toolbar.AnchorPoint=Vector2.new(.5,0);toolbar.BackgroundTransparency=1
 local open=button(toolbar,"OpenBook","BOOK",UDim2.fromOffset(104,40),UDim2.new())
 local dev=button(toolbar,"Developer","DEV",UDim2.fromOffset(60,40),UDim2.fromOffset(112,0));dev.Visible=false
 local box=frame(gui,"BookPanel",UDim2.fromScale(1,1),UDim2.new());box.Visible=false
 local head=frame(box,"Header",UDim2.new(1,0,0,56),UDim2.new(),panel)
 local title=label(head,"Title","BLACK ISLANDS  /  BESTIÁRIO",UDim2.new(1,-110,1,0),UDim2.fromOffset(16,0),20);title.TextXAlignment=Enum.TextXAlignment.Left
 local close=button(head,"Close","X",UDim2.fromOffset(42,40),UDim2.new(1,-50,0,8));close.Modal=true
 local catalog=frame(box,"CatalogPage",UDim2.new(1,0,1,-56),UDim2.fromOffset(0,56))
 local detailPage=frame(box,"CreaturePage",UDim2.new(1,0,1,-56),UDim2.fromOffset(0,56));detailPage.Visible=false
 local progress=label(catalog,"Progress","Carregando...",UDim2.new(1,-32,0,30),UDim2.fromOffset(16,8),15);progress.TextXAlignment=Enum.TextXAlignment.Left
 local tabs={};for i,n in {"Criaturas","Itens","Missões"} do tabs[n]=button(catalog,"Tab"..i,n,UDim2.new(1/3,-12,0,38),UDim2.new((i-1)/3,8,0,44)) end
 local sort=button(catalog,"Sort","Descoberta",UDim2.new(.5,-16,0,36),UDim2.fromOffset(8,90))
 local filter=button(catalog,"Filter","Todos",UDim2.new(.5,-16,0,36),UDim2.new(.5,8,0,90))
 local list=scroll(catalog,"SpeciesList",UDim2.new(1,-32,1,-170),UDim2.fromOffset(16,138))
 local status=label(catalog,"Status","",UDim2.new(1,-24,0,24),UDim2.new(0,12,1,-28),12)
 local back=button(detailPage,"Back","X  Voltar",UDim2.fromOffset(100,36),UDim2.fromOffset(12,8))
 local speciesName=label(detailPage,"SpeciesName","",UDim2.new(1,-134,0,40),UDim2.fromOffset(124,6),24);speciesName.TextXAlignment=Enum.TextXAlignment.Left
 local preview=frame(detailPage,"PreviewPanel",UDim2.new(.43,-18,1,-64),UDim2.fromOffset(12,54),panel);round(preview,12)
 local image=Instance.new("ImageLabel");image.Name="Preview";image.Size=UDim2.new(1,-16,1,-48);image.Position=UDim2.fromOffset(8,8);image.BackgroundTransparency=1;image.ScaleType=Enum.ScaleType.Fit;image.Parent=preview
 label(preview,"Caption","REGISTRO DE CAMPO",UDim2.new(1,-12,0,32),UDim2.new(0,6,1,-36),12)
 local detail=scroll(detailPage,"SpeciesDetail",UDim2.new(.57,-22,1,-64),UDim2.new(.43,10,0,54))
 local console=frame(gui,"DeveloperConsole",UDim2.new(.92,0,0,220),UDim2.fromScale(.5,.5));console.AnchorPoint=Vector2.new(.5,.5);console.Visible=false;round(console,12)
 local cap=Instance.new("UISizeConstraint");cap.MaxSize=Vector2.new(640,220);cap.Parent=console
 label(console,"ConsoleTitle","CONSOLE DE DESENVOLVEDOR",UDim2.new(1,-55,0,34),UDim2.fromOffset(8,4),16)
 local cclose=button(console,"Close","X",UDim2.fromOffset(40,34),UDim2.new(1,-48,0,5));cclose.Modal=true
 local input=Instance.new("TextBox");input.Name="Command";input.PlaceholderText="/summon mob 210080 1 here true";input.Text="";input.ClearTextOnFocus=false;input.TextColor3=ink;input.PlaceholderColor3=accent;input.BackgroundColor3=panel;input.TextSize=14;input.Font=Enum.Font.Code;input.Size=UDim2.new(1,-20,0,44);input.Position=UDim2.fromOffset(10,48);input.Parent=console;round(input,8)
 local send=button(console,"Execute","Executar",UDim2.new(1,-20,0,38),UDim2.fromOffset(10,102))
 local cstatus=label(console,"Result","",UDim2.new(1,-20,0,62),UDim2.fromOffset(10,148),13)
 local self:any={gui=gui,box=box,progress=progress,list=list,detail=detail,status=status,dev=dev,console=console,cstatus=cstatus,order="Discovery",filter="Todos",tab="Criaturas",snapshot=nil,selected=nil}
 local function page(row:any)
  self.selected=row;catalog.Visible=row==nil;detailPage.Visible=row~=nil
  if not row then return end
  clear(detail);detail.CanvasPosition=Vector2.zero;speciesName.Text=row.name;image.Image=if row.previewAssetId then "rbxassetid://"..row.previewAssetId else ""
  local disposition=if row.disposition=="Passive" then "Passivo" elseif row.disposition=="Neutral" then "Neutro" else "Agressivo"
  line(detail,"Category",row.category.."  •  "..disposition,28,16).TextColor3=accent
  line(detail,"Biome","Biomas  /  "..table.concat(row.biomes,", "),44,14)
  local desc=line(detail,"Description",row.description,80,15);desc.AutomaticSize=Enum.AutomaticSize.Y
  local a,b=row.stats.level1,row.stats.level10
  local function percent(x:number,y:number):string return if x==0 then "—" else string.format("%+.1f%%",100*(y/x-1)) end
  line(detail,"Stats","ATRIBUTOS  |  Nível 1 → "..row.stats.levelHigh,36,17).TextColor3=accent
  for _,stat in {{name="Vida",a=a.health,b=b.health},{name="Dano",a=a.damage,b=b.damage},{name="Caminhada",a=a.walkSpeed,b=b.walkSpeed},{name="Corrida",a=a.runSpeed,b=b.runSpeed}} do
   line(detail,stat.name,string.format("%s  ×  %.2f → %.2f  (%s)",stat.name,stat.a,stat.b,percent(stat.a,stat.b)),36,15)
  end
  if row.id then line(detail,"TechnicalId","ID técnico: "..row.id,32,13) end
 end
 function self:render()
  local snap=self.snapshot
  if snap then dev.Visible=snap.developer==true;if not dev.Visible then console.Visible=false end end
  if not snap or not snap.ready then progress.Text="Carregando descobertas...";return end
  progress.Text=string.format("REGISTROS  •  %d/%d descobertos  •  %.0f%%",snap.discovered,snap.total,snap.percent)
  if detailPage.Visible then
   for _,row in snap.rows do if self.selected and row.key==self.selected.key then page(row);return end end
   page(nil)
  end
  clear(list)
  if self.tab~="Criaturas" then line(list,"Unavailable","Esta categoria ainda está em desenvolvimento.",52,15);return end
  for _,row in snap.rows do
   if self.filter~="Todos" and row.disposition~=self.filter then continue end
   local b=button(list,"SpeciesRow",row.name.."    ›",UDim2.new(1,-10,0,60),UDim2.new());b.LayoutOrder=#list:GetChildren();b.Activated:Connect(function()page(row)end)
  end
  if snap.unknown>0 then line(list,"Unknown",string.format("?  %d espécies desconhecidas",snap.unknown),54,15) end
 end
 function self:select(row:any)page(row)end
 function self:back()page(nil);self:render()end
 function self:update(snap:any)self.snapshot=snap;self:render()end
 function self:setStatus(value:string)status.Text=value end
 function self:show()console.Visible=false;box.Visible=true;toolbar.Visible=false;page(nil);callbacks.refresh(self.order)end
 function self:hide()box.Visible=false;console.Visible=false;toolbar.Visible=true;page(nil)end
 open.Activated:Connect(function()self:show()end)
 close.Activated:Connect(function()self:hide()end)
 back.Activated:Connect(function()self:back()end)
 sort.Activated:Connect(function()self.order=if self.order=="Discovery" then "Alphabetical" else "Discovery";sort.Text=if self.order=="Discovery" then "Descoberta" else "A–Z";callbacks.refresh(self.order)end)
 local filters={"Todos","Passive","Neutral","Aggressive"};local labels={Todos="Todos",Passive="Passivos",Neutral="Neutros",Aggressive="Agressivos"};local fi=1
 filter.Activated:Connect(function()fi=fi%#filters+1;self.filter=filters[fi];filter.Text=labels[self.filter];self:render()end)
 for name,b in tabs do b.Activated:Connect(function()self.tab=name;self:render()end) end
 dev.Activated:Connect(function()if self.snapshot and self.snapshot.developer then box.Visible=false;console.Visible=not console.Visible end end)
 cclose.Activated:Connect(function()console.Visible=false end)
 send.Activated:Connect(function()if self.snapshot and self.snapshot.developer then callbacks.command(input.Text) end end)
 return self
end
return table.freeze(V)
