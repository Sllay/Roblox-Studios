do
assert(game.GameId==10769712441 and game.PlaceId==93428341652658,"staging only")
local A=game:GetService("AssetService")
local K=game:GetService("KeyframeSequenceProvider")
local model=A:LoadAssetAsync(tonumber(cfg.modelAssetId))
assert(model:IsA("Model") and model.Parent==nil,"detached model")
local result={noPlaceWrites=true,modelAssetId=cfg.modelAssetId,clips={},playbackVerified=false}
local ok,err=pcall(function()
 local parts,bones={},{}
 for _,o in model:GetDescendants() do
  if o:IsA("MeshPart") then table.insert(parts,o);o.Anchored=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false end
  if o:IsA("Bone") then bones[o.Name]=o end
 end
 assert(#parts==9,"model partition changed")
 local n=0;for _ in pairs(bones) do n+=1 end
 assert(n==19,"19 bone rig required")
 local ac=model:FindFirstChildWhichIsA("AnimationController",true)
 if not ac then ac=Instance.new("AnimationController");ac.Parent=model end
 local animator=ac:FindFirstChildWhichIsA("Animator") or Instance.new("Animator",ac)
 model.Parent=workspace
 for name,id in pairs(cfg.animationIds) do
  local sequence=nil
  for attempt=1,4 do
   local found,value=pcall(function()return K:GetKeyframeSequenceAsync("rbxassetid://"..id)end)
   if found and value then sequence=value;break end
   task.wait(1)
  end
  assert(sequence,"Animation KeyframeSequence not loadable: "..name)
  local seqLength=0
  for _,k in sequence:GetKeyframes() do seqLength=math.max(seqLength,k.Time) end
  local frameCount=#sequence:GetKeyframes()
  sequence:Destroy()
  local expected=cfg.expected[name]
  assert(expected and frameCount==expected.keyframes and math.abs(seqLength-expected.duration)<.055,"Sequence keyframe contract "..name)
  local anim=Instance.new("Animation");anim.Name="Rabbit_"..name;anim.AnimationId="rbxassetid://"..id
  local track=animator:LoadAnimation(anim);track:Play(.01,1,1)
  for i=1,30 do if track.Length>0 then break end;task.wait(.1) end
  local length=track.Length
  animator:StepAnimations(expected.duration*.32)
  track:AdjustSpeed(0)
  local motion=0;local active=0
  for _,b in pairs(bones) do
   local actual={b.Transform:GetComponents()}
   for i=1,12 do
    local identity=if i==4 or i==8 or i==12 then 1 else 0
    motion=math.max(motion,math.abs(actual[i]-identity))
   end
   active+=1
  end
  local valid=active==19 and math.abs(length-expected.duration)<.06 and motion>.008
  result.clips[name]={assetId=id,frames=frameCount,sequenceLength=seqLength,trackLength=length,nonRestMotion=motion,bones=active,passed=valid}
  track:Stop(0);track:Destroy();anim:Destroy()
 end
 result.playbackVerified=true
 for _,clip in pairs(result.clips) do result.playbackVerified=result.playbackVerified and clip.passed end
end)
result.ok=ok
if not ok then result.error=tostring(err):sub(1,400) end
model:Destroy()
return syncResult(result)
end