--!strict
-- Render the existing animated mesh, never clone it or move the authoritative hitbox.
local CollectionService=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local poses:{[BasePart]:CFrame}={}
local offsets:{[BasePart]:{[BasePart]:CFrame}}={}
local function remove(instance:Instance)
 if instance:IsA("BasePart") then poses[instance]=nil;offsets[instance]=nil end
end
CollectionService:GetInstanceRemovedSignal("CreatureVisual"):Connect(remove)
RunService.PreRender:Connect(function(dt:number)
 local camera=workspace.CurrentCamera
 if not camera then return end
 for _,instance in CollectionService:GetTagged("CreatureVisual") do
  if not instance:IsA("BasePart") then continue end
  local ancestor=instance.Parent
  local hitbox:Instance?=nil
  while ancestor and ancestor~=workspace do
   hitbox=ancestor:FindFirstChild("CreatureHitbox")
   if hitbox then break end
   ancestor=ancestor.Parent
  end
  if not hitbox or not hitbox:IsA("BasePart") or not hitbox.CanQuery or not instance.Anchored then
   poses[instance]=nil;offsets[instance]=nil
   continue
  end
  local target=hitbox.CFrame
  local parts=offsets[instance]
  if not parts then
   parts={}
   for _,descendant in ancestor:GetDescendants() do
    if descendant:IsA("BasePart") and descendant~=hitbox then parts[descendant]=instance.CFrame:ToObjectSpace(descendant.CFrame) end
   end
   offsets[instance]=parts
  end
  local distance=(target.Position-camera.CFrame.Position).Magnitude
  if distance>800*math.clamp(instance.Size.Magnitude/3,1,8) then
   poses[instance]=nil
   continue
  end
  local previous=poses[instance] or target
  local pose=previous:Lerp(target,1-math.exp(-24*math.min(dt,.1)))
  local offset=pose.Position-target.Position
  -- Stay inside the server hitbox's extra .3 stud margin.
  if offset.Magnitude>.25 then pose=pose.Rotation+(target.Position+offset.Unit*.25) end
  -- Bound angular error too; the server hitbox remains the aim authority.
  local _,angle=target:ToObjectSpace(pose):ToAxisAngle()
  if math.abs(angle)>math.rad(8) then pose=target:Lerp(pose,math.rad(8)/math.abs(angle)) end
  poses[instance]=pose
  -- Smooth the whole animated skinned model; never drag the hitbox or leave the arms behind.
  for part,offset in pairs(parts) do
   if part.Parent and part.Anchored then part.CFrame=pose*offset else parts[part]=nil end
  end
 end
end)
