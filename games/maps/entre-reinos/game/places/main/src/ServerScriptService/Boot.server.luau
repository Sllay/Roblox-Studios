--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local version = require(ReplicatedStorage:WaitForChild("PlatformShared"):WaitForChild("Version"))
print("entre_reinos_main started. Shared version:", version.major, version.minor, version.patch)
