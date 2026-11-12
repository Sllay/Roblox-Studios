--!strict
-- Set the shared native wind only if no authored nonzero wind exists.
local Workspace = game:GetService("Workspace")
if Workspace.GlobalWind.Magnitude < 0.01 then
    Workspace.GlobalWind = Vector3.new(8,0,3)
end
