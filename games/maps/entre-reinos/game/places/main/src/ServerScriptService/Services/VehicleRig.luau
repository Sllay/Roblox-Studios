--!strict
local Rig={}
local leather=Color3.fromRGB(65,43,35)
local timber=Color3.fromRGB(115,76,49)

local function piece(model: Model,name: string,size: Vector3,color: Color3,shape: Enum.PartType?): Part
    local part=Instance.new("Part")
    part.Name=name
    part.Size=size
    part.Color=color
    part.Shape=shape or Enum.PartType.Block
    part.CanCollide=false
    part.CanTouch=false
    part.CanQuery=false
    part.Massless=true
    part.Parent=model
    return part
end

local function joint(root: BasePart, part: BasePart, offset: CFrame, pivot: Vector3?): Motor6D
    local motor=Instance.new("Motor6D")
    motor.Name=part.Name.."Joint"
    motor.Part0=root
    motor.Part1=part
    local hinge=CFrame.new(pivot or Vector3.zero)
    motor.C0=offset*hinge
    motor.C1=hinge
    part.CFrame=root.CFrame*offset
    motor.Parent=root
    return motor
end

function Rig.create(kind: string, parent: Folder)
    local vehicle=Instance.new("Model")
    vehicle.Name=if kind=="mount" then "Cavalo selado" else "Barco do Vale"
    vehicle.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
    local root=piece(vehicle,"Chassis",Vector3.new(1,1,1),leather)
    root.Transparency=1
    root.Anchored=true
    vehicle.PrimaryPart=root
    local gait: {Motor6D}={}
    local function shape(name: string,size: Vector3,color: Color3,offset: CFrame)
        local p=piece(vehicle,name,size,color,Enum.PartType.Ball)
        joint(root,p,offset)
    end
    local seat=Instance.new("Seat")
    seat.Name="Assento"
    seat.Size=Vector3.new(1.55,0.35,1.48)
    seat.Color=leather
    seat.CanCollide=false
    seat.CanTouch=false
    seat.CanQuery=false
    seat.Massless=true
    seat.Parent=vehicle
    if kind=="mount" then
        local coat=Color3.fromRGB(144,93,63)
        shape("Barril",Vector3.new(2.45,2.5,4.45),coat,CFrame.new(0,2.68,0))
        shape("Garupa",Vector3.new(2.51,2.6,2.2),coat,CFrame.new(0,2.7,1.43))
        shape("Peito",Vector3.new(2.15,2.45,1.72),coat,CFrame.new(0,2.76,-1.58))
        shape("Pescoço",Vector3.new(1.36,2.95,1.48),coat,CFrame.new(0,4.01,-1.75)*CFrame.Angles(-0.54,0,0))
        shape("Cabeça",Vector3.new(1.22,1.43,1.92),coat,CFrame.new(0,4.75,-2.47)*CFrame.Angles(0.32,0,0))
        shape("Focinho",Vector3.new(1.08,0.92,1.24),Color3.fromRGB(106,77,71),CFrame.new(0,4.38,-3))
        shape("Crina",Vector3.new(0.46,2.27,1.35),leather,CFrame.new(0,4.15,-1.27)*CFrame.Angles(-0.54,0,0))
        shape("Cauda",Vector3.new(0.38,2.22,0.57),leather,CFrame.new(0,1.96,2.36)*CFrame.Angles(-0.31,0,0))
        for _,side in ipairs({-1,1}) do
            shape("Olho",Vector3.new(0.16,0.25,0.26),Color3.fromRGB(31,25,21),CFrame.new(side*0.57,4.91,-2.6))
            shape("Orelha",Vector3.new(0.32,0.88,0.44),coat,CFrame.new(side*0.37,5.45,-1.99)*CFrame.Angles(-0.18,0,side*0.26))
            for _,endZ in ipairs({-1,1}) do
                local offsets=CFrame.new(side*0.76,1.47,endZ*1.42)
                local thigh=piece(vehicle,"Coxa",Vector3.new(0.64,1.46,0.73),coat,Enum.PartType.Ball)
                local upper=joint(root,thigh,offsets,Vector3.new(0,0.65,0))
                local cannon=piece(vehicle,"Canela",Vector3.new(0.37,1.32,0.44),coat,Enum.PartType.Ball)
                local lower=joint(thigh,cannon,CFrame.new(0,-0.91,0.13*endZ),Vector3.new(0,0.46,0))
                local hoof=piece(vehicle,"Casco",Vector3.new(0.48,0.34,0.65),leather,Enum.PartType.Ball)
                joint(cannon,hoof,CFrame.new(0,-0.56,-0.12))
                table.insert(gait,upper)
                table.insert(gait,lower)
            end
        end
        shape("Manta",Vector3.new(2.36,0.58,2.4),Color3.fromRGB(84,117,95),CFrame.new(0,3.71,0.2))
        joint(root,seat,CFrame.new(0,3.95,0.32))
    else
        shape("Casco",Vector3.new(4.1,1.35,8.1),leather,CFrame.new(0,0.18,0))
        for _,side in ipairs({-1,1}) do
            local rail=piece(vehicle,"Borda",Vector3.new(0.26,0.48,6),timber)
            joint(root,rail,CFrame.new(side*1.64,0.98,0))
            local oar=piece(vehicle,"Remo",Vector3.new(0.22,0.18,4.3),timber)
            local motor=joint(root,oar,CFrame.new(side*2.35,0.8,0.25)*CFrame.Angles(0,side*1.2,side*0.14))
            local blade=piece(vehicle,"Pá",Vector3.new(0.61,0.19,1.35),timber,Enum.PartType.Ball)
            joint(oar,blade,CFrame.new(0,0,2.0*side))
            table.insert(gait,motor)
        end
        for _,z in ipairs({-1.45,1.45}) do
            local bench=piece(vehicle,"Banco",Vector3.new(3.27,0.28,1.06),timber)
            joint(root,bench,CFrame.new(0,0.84,z))
        end
        joint(root,seat,CFrame.new(0,0.99,0))
    end
    for index,motor in ipairs(gait) do motor:SetAttribute("ER_GaitIndex",index) end
    vehicle:SetAttribute("ER_GaitKind",kind)
    vehicle:SetAttribute("ER_GaitSpeed",0)
    vehicle.Parent=parent
    return {model=vehicle,seat=seat,gait=gait}
end

function Rig.animate(rig: any,speed: number)
    rig.model:SetAttribute("ER_GaitSpeed",speed)
end

return Rig
