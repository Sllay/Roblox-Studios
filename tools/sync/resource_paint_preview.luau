-- Material-only edit in a disposable version-pinned session; inverse tested.
local T=workspace.Terrain
local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
local before=terrainState()
for _,t in before do assert(cfg.terrainExpected[t.id]==t.digest,"Terrain baseline") end
local originals={}
local count=0
for _,patch in cfg.patches do
    for _,cell in patch.cells do
        local r=Region3.new(Vector3.new(cell.x,-32,cell.z),Vector3.new(cell.x+4,112,cell.z+4))
        local data=T:ReadVoxelChannels(r,4,channels)
        local top=0
        for y=1,36 do
            assert(data.LiquidOccupancy[1][y][1]<=.02,"Wet column")
            if data.SolidOccupancy[1][y][1]>.02 then top=y end
        end
        assert(top>0 and data.SolidMaterial[1][top][1]==Enum.Material.Grass,"Surface material")
        assert(math.abs(-32+(top-1+data.SolidOccupancy[1][top][1])*4-cell.height)<.001,"Surface height")
        -- Paint top and the immediately underlying grass voxel if present,
        -- preserving all occupancies; no carving or fill.
        local changes=0
        for y=math.max(1,top-1),top do
            if data.SolidMaterial[1][y][1]==Enum.Material.Grass then data.SolidMaterial[1][y][1]=Enum.Material.Ground;changes+=1 end
        end
        T:WriteVoxelChannels(r,4,{SolidMaterial=data.SolidMaterial,SolidOccupancy=data.SolidOccupancy,LiquidOccupancy=data.LiquidOccupancy})
        local check=T:ReadVoxelChannels(r,4,channels)
        for y=1,36 do
            assert(check.SolidOccupancy[1][y][1]==data.SolidOccupancy[1][y][1] and check.LiquidOccupancy[1][y][1]==data.LiquidOccupancy[1][y][1],"Occupancy changed")
            assert(check.SolidMaterial[1][y][1]==data.SolidMaterial[1][y][1],"Material mismatch")
        end
        table.insert(originals,{region=r,data=data,top=top,oldTop=Enum.Material.Grass,oldBelow=if changes==2 then Enum.Material.Grass else nil})
        count+=1
    end
end
local after=terrainState()
local changed=0
for i,t in after do
    assert(t.solidVoxels==before[i].solidVoxels and t.waterVoxels==before[i].waterVoxels,"Terrain volume")
    if t.digest~=before[i].digest then changed+=1 end
end
assert(changed==9,"Expected 9 affected tiles")
for _,r in originals do
    r.data.SolidMaterial[1][r.top][1]=r.oldTop
    if r.oldBelow then r.data.SolidMaterial[1][r.top-1][1]=r.oldBelow end
    T:WriteVoxelChannels(r.region,4,{SolidMaterial=r.data.SolidMaterial,SolidOccupancy=r.data.SolidOccupancy,LiquidOccupancy=r.data.LiquidOccupancy})
end
local restored=terrainState()
for i,t in restored do assert(t.digest==before[i].digest,"Paint inverse") end
return syncResult({columns=count,changedTiles=changed,all49Restored=#restored==49,occupancyPreserved=true,noPlaceWrites=true,runtimeVisibleVerified=false})
