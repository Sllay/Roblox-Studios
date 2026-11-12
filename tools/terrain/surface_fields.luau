--!strict
-- Pure 4-stud surface field. Native voxel readers own the source digest.
-- The result is a terrain occupancy estimate, not a runtime raycast.
local S={}
export type Cell={h:number,grass:boolean,wet:boolean}
export type Tile={b:{number},nx:number,nz:number,grid:{{Cell}}}
function S.height(tile:Tile,x:number,z:number):number?
    local gx,gz=(x-tile.b[1])/4+0.5,(z-tile.b[3])/4+0.5
    local i,j=math.floor(gx),math.floor(gz)
    if i<1 or i>=tile.nx or j<1 or j>=tile.nz then return nil end
    local a,c,d,f=tile.grid[i][j],tile.grid[i+1][j],tile.grid[i][j+1],tile.grid[i+1][j+1]
    for _,v in {a,c,d,f} do if not v.grass or v.wet then return nil end end
    local tx,tz=gx-i,gz-j
    return (a.h+(c.h-a.h)*tx)*(1-tz)+(d.h+(f.h-d.h)*tx)*tz
end
function S.dry(tile:Tile,x:number,z:number,r:number):boolean
    local b=tile.b
    if r<0 or x-r<b[1]+4 or x+r>b[4]-4 or z-r<b[3]+4 or z+r>b[6]-4 then return false end
    local i0,i1=math.floor((x-r-b[1])/4)+1,math.floor((x+r-b[1])/4)+1
    local j0,j1=math.floor((z-r-b[3])/4)+1,math.floor((z+r-b[3])/4)+1
    for i=i0,i1 do for j=j0,j1 do
        local dx,dz=b[1]+(i-0.5)*4-x,b[3]+(j-0.5)*4-z
        if dx*dx+dz*dz<=(r+2.83)^2 then
            local c=tile.grid[i] and tile.grid[i][j]
            if not c or not c.grass or c.wet then return false end
        end
    end end
    return true
end
function S.support(tile:Tile,x:number,z:number,r:number):(number?,number?,number?,number?,number?)
    if r<=0 then return nil,nil,nil,nil,nil end
    local h=S.height(tile,x,z)
    local h1,h2,h3,h4=S.height(tile,x+r,z),S.height(tile,x-r,z),S.height(tile,x,z+r),S.height(tile,x,z-r)
    if not h or not h1 or not h2 or not h3 or not h4 then return nil,nil,nil,nil,nil end
    local dx,dz=(h1-h2)/(2*r),(h3-h4)/(2*r)
    local slope=math.deg(math.atan(math.sqrt(dx*dx+dz*dz)))
    local relief=math.max(h,h1,h2,h3,h4)-math.min(h,h1,h2,h3,h4)
    return h,slope,relief,dx,dz
end
-- Empirical percentile over valid dry grass sample heights, no interpolation.
-- The caller chooses the region set (playable only for biome rules).
function S.percentile(tiles:{Tile},q:number):number?
    assert(q>=0 and q<=1,"Percentile range")
    local values:{number}={}
    for _,tile in tiles do
        for _,column in tile.grid do
            for _,c in column do
                if c.grass and not c.wet then table.insert(values,c.h) end
            end
        end
    end
    if #values==0 then return nil end
    table.sort(values)
    return values[math.max(1,math.ceil(q*#values))]
end
return S
