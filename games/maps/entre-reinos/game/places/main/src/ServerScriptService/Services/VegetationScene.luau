--!strict
-- Approved visual templates are baked by Rojo as asset references. Instancing
-- never loads an entire marketplace pack or copies gameplay from another Place.
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Profile=require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("RegionalProfile"))
local templates=ServerStorage:WaitForChild("ERVegetation")
local Scene={}
local palette={0.89,0.95,1,1.04}
local definitions={
    tree={"BroadleafA",8.5}, broadleaf={"BroadleafB",8}, pine={"Pine",9.5},
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
    local tree=kind=="tree" or kind=="broadleaf" or kind=="pine"
    local _,bounds=model:GetBoundingBox()
    local factor=definition[2]*size/bounds.Y
    if tree then
        -- Scale the whole asset uniformly. Cap wide imported canopies as well
        -- as the height so rotating a tree cannot fill the play corridor.
        local maxHeight=if deep then 11 else 9.5
        local maxWidth=if deep then 10 else 8
        factor=math.min(factor,maxHeight/bounds.Y,maxWidth/math.max(bounds.X,bounds.Z))
    end
    model:ScaleTo(model:GetScale()*factor)
    model:PivotTo(CFrame.new(position)*CFrame.Angles(0,angle,0))
    local bottom,scaled=model:GetBoundingBox()
    local rise=position.Y-bottom.Y+scaled.Y/2
    local retreat=0
    if tree then
        -- The side camera looks in from positive Z. Reserve a full stud
        -- behind the play plane for the entire tree, not just its pivot.
        local depth=(math.abs(bottom.RightVector.Z)*scaled.X+math.abs(bottom.UpVector.Z)*scaled.Y
            +math.abs(bottom.LookVector.Z)*scaled.Z)/2
        retreat=math.max(0,bottom.Z+depth-(Profile.LANE_Z-1))
    end
    model:PivotTo(model:GetPivot()+Vector3.new(0,rise,-retreat))
    for _,piece in ipairs(model:GetChildren()) do
        if not piece:IsA("MeshPart") then continue end
        piece.CastShadow=tree and not deep
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
