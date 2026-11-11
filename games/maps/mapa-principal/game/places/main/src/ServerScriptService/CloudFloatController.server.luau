--!strict
-- Roblox-Studios: teste de replicação, animação autoritativa no servidor.
local TweenService = game:GetService("TweenService")
local folder = workspace:WaitForChild("RobloxStudiosSmoke", 20)
assert(folder, "RobloxStudiosSmoke não foi carregado no Workspace")
local platform = folder:WaitForChild("FloatingPlatform", 20)
assert(platform and platform:IsA("BasePart"), "FloatingPlatform não existe ou não é Part")
local part = platform :: BasePart
part.Anchored = true
part.CanCollide = true

local lowerPosition = part.Position
local upperPosition = lowerPosition + Vector3.new(0, 6, 0)
local tweenInfo = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

print("[RobloxStudiosSmoke] SERVER OK; plataforma:", part:GetFullName())
while part:IsDescendantOf(workspace) do
    for _, destination in { upperPosition, lowerPosition } do
        local tween = TweenService:Create(part, tweenInfo, { Position = destination })
        tween:Play()
        local status = tween.Completed:Wait()
        tween:Destroy()
        if status ~= Enum.PlaybackState.Completed or not part:IsDescendantOf(workspace) then
            return
        end
    end
end
