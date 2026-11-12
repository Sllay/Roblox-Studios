-- Read exact pre-clearing material channels from historical v16.
local T=workspace.Terrain
local out={}
for _,c in cfg.columns do
    local region=Region3.new(Vector3.new(c.x,-32,c.z),Vector3.new(c.x+4,112,c.z+4))
    local d=T:ReadVoxelChannels(region,4,{"SolidMaterial","SolidOccupancy","LiquidOccupancy"})
    local a={x=c.x,z=c.z,material={},solid={},liquid={}}
    for y=1,36 do
        a.material[y]=d.SolidMaterial[1][y][1].Name
        a.solid[y]=d.SolidOccupancy[1][y][1]
        a.liquid[y]=d.LiquidOccupancy[1][y][1]
    end
    table.insert(out,a)
end
return syncResult({columns=out,noPlaceWrites=true})
