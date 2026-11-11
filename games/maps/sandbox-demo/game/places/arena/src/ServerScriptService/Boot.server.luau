--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local version = require(ReplicatedStorage:WaitForChild("PlatformShared"):WaitForChild("Version"))
print("SandboxArena started. Shared version:", version.major, version.minor, version.patch)
