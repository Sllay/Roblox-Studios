do
local model=game:GetService("AssetService"):LoadAssetAsync(76960331636475)
assert(model.Parent==nil)
local result={noPlaceWrites=true,transitions={},speedTests={},allPassed=false}
local ok,err=pcall(function()
 local mesh=model:FindFirstChildWhichIsA("MeshPart",true)
 mesh.Anchored=true
 mesh.CanCollide=false
 local ac=model:FindFirstChildWhichIsA("AnimationController",true)
 local animator=ac:FindFirstChildWhichIsA("Animator")
 if not animator then animator=Instance.new("Animator");animator.Parent=ac end
 model.Parent=workspace
 animator.PreferLodEnabled=false
 local tracks={}
 local assets={}
 for name,id in pairs(cfg.ids) do
  local a=Instance.new("Animation");a.AnimationId="rbxassetid://"..id
  local t=animator:LoadAnimation(a)
  t:Play(0,1,1)
  for i=1,30 do if t.Length>0 then break end task.wait(.1) end
  assert(t.Length>0,"Failed to load "..name)
  t:Stop(0)
  tracks[name]=t;assets[name]=a
 end
 local function reset()
  for _,t in pairs(tracks) do t:Stop(0) end
  animator:StepAnimations(0)
  for _,b in mesh:GetDescendants() do if b:IsA("Bone") then b.Transform=CFrame.identity end end
 end
 local function motion()
  local max=0
  for _,b in mesh:GetDescendants() do
   if b:IsA("Bone") then
    local v={b.Transform:GetComponents()}
    for i=1,12 do
     local identity=if i==4 or i==8 or i==12 then 1 else 0
     max=math.max(max,math.abs(v[i]-identity))
    end
   end
  end
  return max
 end
 -- Evaluate transitions in a stopped Open Cloud session using the native Animator.
 local pairsToTest={{"Idle","Walk"},{"Walk","Run"},{"Run","Idle"},{"Idle","Peck"},{"Peck","Idle"},{"Idle","Flap"},{"Flap","Idle"}}
 local all=true
 for _,pair in pairsToTest do
  reset()
  local a,b=tracks[pair[1]],tracks[pair[2]]
  a:Play(0,1,1)
  animator:StepAnimations(.125)
  local before=motion()
  a:Stop(.2)
  b:Play(.2,1,1)
  animator:StepAnimations(.1)
  local midA,midB=a.WeightCurrent,b.WeightCurrent
  local midMotion=motion()
  animator:StepAnimations(.15)
  local endA,endB=a.WeightCurrent,b.WeightCurrent
  local pose=motion()
  local pass=b.IsPlaying and math.abs(b.TimePosition-.25)<.035 and midA>.05 and midA<.95 and midB>.05 and midB<.95 and endA<.05 and endB>.95 and pose>.001
  table.insert(result.transitions,{from=pair[1],to=pair[2],midOldWeight=midA,midNewWeight=midB,endOldWeight=endA,endNewWeight=endB,beforeMotion=before,midMotion=midMotion,endMotion=pose,time=b.TimePosition,passed=pass})
  all=all and pass
 end
 for _,name in {"Walk","Run"} do
  for _,speed in {.75,1,1.5} do
   reset()
   local t=tracks[name]
   t:Play(0,1,speed)
   animator:StepAnimations(.2)
   local pass=math.abs(t.TimePosition-.2*speed)<.015 and motion()>.01
   table.insert(result.speedTests,{clip=name,speed=speed,expectedTime=.2*speed,actualTime=t.TimePosition,motion=motion(),passed=pass})
   all=all and pass
  end
 end
 reset()
 for name,t in pairs(tracks) do t:Destroy();assets[name]:Destroy() end
 result.allPassed=all
end)
result.ok=ok
if not ok then result.error=tostring(err):sub(1,500) end
model:Destroy()
return syncResult(result)
end
