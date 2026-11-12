
-- Trusted project diagnostic, not asset code. Runs only in the live game.
-- Never changes model transforms or terrain. Reports actual physical support.
local root=script.Parent
local models=root:WaitForChild("Models")
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Include
params.FilterDescendantsInstances={workspace.Terrain}
params.IgnoreWater=false
params.RespectCanCollide=true
local function check()
    local passed,failed,missing,maxError=0,0,0,0
    for _,model in models:GetChildren() do
        if not model:IsA("Model") then continue end
        local pivot=model:GetPivot()
        local ground=model:GetAttribute("RSExpectedGroundY")
        local radius=model:GetAttribute("RSSupportRadius")
        local expectedBurial=model:GetAttribute("RSBuriedDepth")
        local bb,size=model:GetBoundingBox()
        local bottom=bb.Position.Y-size.Y/2
        local ok=true
        for _,off in {{0,0},{radius,0},{-radius,0},{0,radius},{0,-radius}} do
            local hit=workspace:Raycast(Vector3.new(pivot.X+off[1],256,pivot.Z+off[2]),Vector3.new(0,-384,0),params)
            if not hit or hit.Material==Enum.Material.Water then
                ok=false;missing+=1
            else
                maxError=math.max(maxError,math.abs(hit.Position.Y-ground))
                if math.abs(hit.Position.Y-ground)>3 or hit.Position.Y-bottom<0.15 or hit.Position.Y-bottom>expectedBurial+4 then ok=false end
            end
        end
        model:SetAttribute("RSRuntimeGroundStatus",if ok then "pass" else "review")
        if ok then passed+=1 else failed+=1 end
    end
    root:SetAttribute("RSRuntimeGroundPassed",passed)
    root:SetAttribute("RSRuntimeGroundReview",failed)
    root:SetAttribute("RSRuntimeGroundMissing",missing)
    root:SetAttribute("RSRuntimeGroundMaxError",maxError)
    print(string.format("RSSceneBuilder ground: pass=%d review=%d missing=%d maxError=%.3f",passed,failed,missing,maxError))
end
task.wait(2)
check()
