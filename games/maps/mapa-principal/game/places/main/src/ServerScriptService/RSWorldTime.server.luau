--!strict
-- Server owns the epoch and durations; clients derive visual time locally.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Clock = require(ReplicatedStorage:WaitForChild("RSWorldClock") :: ModuleScript)
local DAY_SECONDS = 180
local NIGHT_SECONDS = 60
assert(Clock.valid(DAY_SECONDS, NIGHT_SECONDS))
assert(not ReplicatedStorage:FindFirstChild("RSWorldTimeState"), "Duplicate world clock")
local state = Instance.new("Folder")
state.Name = "RSWorldTimeState"
state:SetAttribute("DaySeconds", DAY_SECONDS)
state:SetAttribute("NightSeconds", NIGHT_SECONDS)
state:SetAttribute("Epoch", Workspace:GetServerTimeNow())
state:SetAttribute("DayBrightness", Lighting.Brightness)
state:SetAttribute("DayAmbient", Lighting.Ambient)
state:SetAttribute("DayOutdoorAmbient", Lighting.OutdoorAmbient)
state.Parent = ReplicatedStorage
-- Gameplay can query Clock.at(server time - Epoch, DaySeconds, NightSeconds).
-- Lighting.ClockTime is not replicated; do not stream server lighting updates.
