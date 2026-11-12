--!strict
local S=require("../../tools/terrain/surface_fields")
local tile:S.Tile={b={0,0,0,24,64,24},nx=6,nz=6,grid={}}
for x=1,6 do
    tile.grid[x]={}
    for z=1,6 do tile.grid[x][z]={h=x*2,grass=true,wet=false} end
end
assert(S.height(tile,10,10)==6)
assert(S.height(tile,12,10)==7)
assert(S.height(tile,0,0)==nil)
assert(S.dry(tile,12,12,1))
assert(not S.dry(tile,1,1,1))
local h,slope,relief,dx,dz=S.support(tile,12,12,2)
assert(h==7 and slope and math.abs(slope-math.deg(math.atan(0.5)))<0.00001)
assert(relief==2 and dx==0.5 and dz==0)
assert(S.percentile({tile},0.8)==10)
assert(S.percentile({tile},1)==12)
tile.grid[3][3].wet=true
assert(S.height(tile,12,12)==nil)
assert(not S.dry(tile,12,12,1))
assert(S.percentile({},0.8)==nil)
print("SURFACE_FIELDS: interpolation, slope, relief, dry mask and altitude percentile passed")
