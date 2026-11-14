do
local A=game:GetService("AssetService")
local K=game:GetService("KeyframeSequenceProvider")
local model=A:LoadAssetAsync(76960331636475)
assert(model.Parent==nil)
local result={assetId=cfg.assetId,playbackVerified=false,noPlaceWrites=true}
local ok,err=pcall(function()
 local seq=K:GetKeyframeSequenceAsync("rbxassetid://"..cfg.assetId)
 local keyframes=seq:GetKeyframes()
 result.keyframes=#keyframes
 local maxTime=0
 for _,k in keyframes do maxTime=math.max(maxTime,k.Time) end
 result.sequenceDuration=maxTime
 seq:Destroy()
 local mesh=model:FindFirstChildWhichIsA("MeshPart",true)
 mesh.Anchored=true
 mesh.CanCollide=false
 local controller=model:FindFirstChildWhichIsA("AnimationController",true)
 if not controller then controller=Instance.new("AnimationController");controller.Parent=model end
 local animator=controller:FindFirstChildWhichIsA("Animator")
 if not animator then animator=Instance.new("Animator");animator.Parent=controller end
 model.Parent=workspace
 local anim=Instance.new("Animation");anim.AnimationId="rbxassetid://"..cfg.assetId
 local track=animator:LoadAnimation(anim)
 track:Play(0,1,1)
 for i=1,30 do if track.Length>0 then break end task.wait(.1) end
 result.length=track.Length
 result.playing=track.IsPlaying
 result.simulationRunning=game:GetService("RunService"):IsRunning()
 animator.PreferLodEnabled=false
 track:AdjustSpeed(1)
 track.TimePosition=0
 animator:StepAnimations(cfg.expected.time)
 track:AdjustSpeed(0)
 result.explicitStep=true
 local maxError=0
 local motion=0
 local count=0
 for _,b in mesh:GetDescendants() do
  if b:IsA("Bone") then
   local want=cfg.expected.bones[b.Name]
   if want then
    local actual={b.Transform:GetComponents()}
    for i=1,12 do
     maxError=math.max(maxError,math.abs(actual[i]-want[i]))
     local identity=if i==4 or i==8 or i==12 then 1 else 0
     motion=math.max(motion,math.abs(actual[i]-identity))
    end
    count+=1
   end
  end
 end
 result.sampleTime=track.TimePosition
 result.bonesCompared=count
 result.maxPoseError=maxError
 result.motion=motion
 result.playbackVerified=count==14 and math.abs(track.Length-cfg.duration)<.05 and math.abs(maxTime-cfg.duration)<.05 and motion>.01 and maxError<.035
 track:Stop(0);track:Destroy();anim:Destroy()
end)
result.ok=ok
if not ok then result.error=tostring(err):sub(1,500) end
model:Destroy()
return syncResult(result)
end
