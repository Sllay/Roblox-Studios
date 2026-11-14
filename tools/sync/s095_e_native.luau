do
local result={noPlaceWrites=true,passed=false}
local model=game:GetService("AssetService"):LoadAssetAsync(76960331636475)
local folder=Instance.new("Folder");folder.Name="S095_E_Probe";folder.Parent=workspace
local d={registry=Registry,brain=Brain,kernel=Kernel,escape=Escape,adapter=Adapter,agent=Agent,population=Population,spawn=Spawn,biomes=Biomes,food=Food,scheduler=Scheduler,director=Director}
local s=Director.new(d,Spawn.chicken,model,folder,210080)
local guiFolder=Instance.new("Folder");guiFolder.Name="BookProbe"
local ok,err=pcall(function()
 local c=assert(Registry.get("210080"))
 local view=View.new(guiFolder,{refresh=function()end,command=function()end})
 local function snapshot(dev)
  local row=Registry.bookRow(c.id,dev)
  return {ready=true,developer=dev,discovered=1,total=1,percent=100,unknown=0,rows={row}}
 end
 view:update(snapshot(false))
 assert(view.detail:FindFirstChild("Preview").Image=="rbxassetid://107933673393998")
 assert(not view.detail:FindFirstChild("TechnicalId") and not view.dev.Visible)
 view:update(snapshot(true))
 assert(view.detail:FindFirstChild("TechnicalId").Text=="ID técnico: 210080" and view.dev.Visible)
 assert(view.progress.Text=="1/1 descobertos • 100%")
 result.ui=true;result.preview=true;result.developerOnly=true
 assert(Dev.authorized(8136365379,8136365379,"User",{}) and not Dev.authorized(2,8136365379,"User",{}))
 local first=assert(Director.tickSpawn(s,1));local base=s.agents[first].adapter:position()
 assert(Director.remove(s,first,1))
 local plan=assert(Summon.parse(Dev.tokens("/summon mob 210080 2 here false"),true,true,15))
 local ids=Director.spawnDeveloper(s,plan,base,2)
 assert(#ids==2 and s.naturalCount==0 and Director.count(s)==2)
 local before={}
 for _,id in ids do local r=s.agents[id];assert(r.origin=="Developer" and not r.adapter.aiEnabled);before[id]=r.adapter:position() end
 for i=1,10 do Director.step(s,.1,2+i*.1) end
 for _,id in ids do local r=s.agents[id];assert(r.agent.intent.state=="Static" and (r.adapter:position()-before[id]).Magnitude<.001) end
 result.summoned=#ids;result.static=true;result.naturalCount=s.naturalCount
 view.gui:Destroy();result.passed=true
end)
result.ok=ok;if not ok then result.error=tostring(err):sub(1,500) end
Director.destroy(s);folder:Destroy();guiFolder:Destroy();model:Destroy()
return syncResult(result)
end
