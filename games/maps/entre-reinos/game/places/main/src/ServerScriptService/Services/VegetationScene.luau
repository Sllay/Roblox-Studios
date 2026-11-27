--!strict
-- Approved visual templates are baked by Rojo as asset references. Instancing
-- never loads an entire marketplace pack or copies gameplay from another Place.
local ServerStorage=game:GetService("ServerStorage")
local templates=ServerStorage:WaitForChild("ERVegetation")
local Scene={}
local palette={0.89,0.95,1,1.04}
local definitions={
    tree={"BroadleafA",12}, broadleaf={"BroadleafB",11}, pine={"Pine",13},
    bush={"Bush",2.7}, rock={"LargeRock",3.6}, pebble={"Pebble",0.38},
    stick={"Stick",0.30}, log={"FallenLog",0.74},
} :: {[string]: {any}}

function Scene.place(parent: Instance,kind: string,position: Vector3,size: number,
        angle: number,tint: number,deep: boolean): Model
    local definition=assert(definitions[kind],"unknown_vegetation_template")
    local template=templates:FindFirstChild(definition[1])
    assert(template and template:IsA("Model"),"missing_vegetation_template")
    local model=template:Clone()
    model:SetAttribute("ER_AssetTemplate",template.Name)
    model:SetAttribute("ER_PlacementRole","decoration")
    model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
    local _,bounds=model:GetBoundingBox()
    model:ScaleTo(model:GetScale()*definition[2]*size/bounds.Y)
    model:PivotTo(CFrame.new(position)*CFrame.Angles(0,angle,0))
    local bottom,scaled=model:GetBoundingBox()
    local toward=position.Y-bottom.Y+scaled.Y/2
    model:PivotTo(model:GetPivot()+Vector3.new(0,toward,0))
    for _,piece in ipairs(model:GetChildren()) do
        if not piece:IsA("MeshPart") then continue end
        piece.CastShadow=not deep and (kind=="tree" or kind=="broadleaf" or kind=="pine")
        for _,leaf in ipairs(piece:GetChildren()) do
            if leaf:IsA("SurfaceAppearance") and (string.find(piece.Name,"Canopy") or piece.Name=="Leaves") then
                local f=palette[tint%#palette+1]
                local c=leaf.Color
                leaf.Color=Color3.new(math.min(1,c.R*f),math.min(1,c.G*f),math.min(1,c.B*f))
            end
        end
    end
    model.Parent=parent
    return model
end

return Scene
