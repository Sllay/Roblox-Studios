--!strict
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = ReplicatedStorage:WaitForChild("RSWorldClock", 15)
local state = ReplicatedStorage:WaitForChild("RSWorldTimeState", 15)
if not module or not module:IsA("ModuleScript") or not state then
    warn("RSWorldTime unavailable; preserving authored Lighting")
    return
end
local Clock = require(module)
local epoch = state:GetAttribute("Epoch")
local day = state:GetAttribute("DaySeconds")
local night = state:GetAttribute("NightSeconds")
local dayBrightness = state:GetAttribute("DayBrightness")
local dayAmbient = state:GetAttribute("DayAmbient")
local dayOutdoor = state:GetAttribute("DayOutdoorAmbient")
if typeof(epoch) ~= "number" or typeof(day) ~= "number" or typeof(night) ~= "number"
    or typeof(dayBrightness) ~= "number" or typeof(dayAmbient) ~= "Color3"
    or typeof(dayOutdoor) ~= "Color3" or not Clock.valid(day, night) then
    warn("RSWorldTime invalid state; preserving authored Lighting")
    return
end
local nightAmbient = Color3.fromRGB(35, 42, 65)
local nightOutdoor = Color3.fromRGB(48, 55, 82)
while state.Parent == ReplicatedStorage do
    local hour = Clock.at(Workspace:GetServerTimeNow() - epoch, day, night)
    local light = Clock.daylight(hour)
    Lighting.ClockTime = hour
    Lighting.Brightness = dayBrightness * (0.22 + 0.78 * light)
    Lighting.Ambient = nightAmbient:Lerp(dayAmbient, light)
    Lighting.OutdoorAmbient = nightOutdoor:Lerp(dayOutdoor, light)
    task.wait(0.1)
end
