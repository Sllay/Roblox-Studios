--!strict
local Scene={}
local function timber(model: Model,name: string,size: Vector3,pose: CFrame,stone: boolean): Part
    local p=Instance.new("Part")
    p.Name=name
    p.Size=size
    p.CFrame=pose
    p.Anchored=true
    p.CanCollide=false
    p.CanTouch=false
    p.Material=if stone then Enum.Material.Cobblestone else Enum.Material.WoodPlanks
    p.Color=if stone then Color3.fromRGB(121,121,110) else Color3.fromRGB(122,83,51)
    p.Parent=model
    return p
end

function Scene.sync(folder: Folder,bridge: any,crossing: any,buildSeconds: number)
    local key=bridge.typeId..":"..bridge.state..":"..math.floor(bridge.progress/buildSeconds*8)
    local model=folder:FindFirstChild(crossing.id)
    if model and model:GetAttribute("Appearance")==key then return end
    if model then model:Destroy() end
    local new=Instance.new("Model")
    new.Name=crossing.id
    new:SetAttribute("Appearance",key)
    local reinforced=bridge.typeId=="bridge_reinforced"
    local open=bridge.state=="complete" or bridge.state=="damaged"
    local from=Vector3.new(crossing.west.x,crossing.deckWestY-0.35,0)
    local to=Vector3.new(crossing.east.x,crossing.deckEastY-0.35,0)
    local span=(to-from).Magnitude
    local pose=CFrame.new((from+to)/2)*CFrame.Angles(0,0,math.atan2(to.Y-from.Y,to.X-from.X))
    local slices=math.ceil(span/6)
    local progress=if open then slices elseif bridge.state=="ruined" then 2
        else math.max(1,math.floor(slices*bridge.progress/buildSeconds))
    for index=1,progress do
        local x=-span/2+(index-0.5)*span/slices
        local plank=timber(new,"Tabuleiro",Vector3.new(span/slices+0.03,0.7,6.7),
            pose*CFrame.new(x,0,0),false)
        plank.CanCollide=open and reinforced
        if not open then plank.Transparency=0.4 end
        if reinforced and index%3==1 then
            for _,side in ipairs({-1,1}) do
                timber(new,"Parapeito",Vector3.new(span/slices*3,0.34,0.34),
                    pose*CFrame.new(x+span/slices,1.25,side*3.05),true)
                timber(new,"Pilar",Vector3.new(0.52,3.1,0.55),pose*CFrame.new(x,0.45,side*3.05),true)
            end
        end
    end
    new.Parent=folder
end
return Scene
