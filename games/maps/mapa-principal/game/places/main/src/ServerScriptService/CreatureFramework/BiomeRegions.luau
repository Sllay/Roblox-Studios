--!strict
-- Current nine verified playable regions are a biome provider, not a species-specific coordinate list.
export type Region={id:string,minX:number,maxX:number,minZ:number,maxZ:number}
local B={}
local cells:{Region}={}
for z=-1,1 do for x=-1,1 do
 table.insert(cells,table.freeze({id=("chunk-%d-%d"):format(x,z),minX=x*256-128,maxX=x*256+128,minZ=z*256-128,maxZ=z*256+128}))
end end
table.freeze(cells)
function B.regions(id:string):{Region}
 if id=="emerald_valley" then return table.clone(cells) end
 return {}
end
function B.regionAt(id:string,x:number,z:number):Region?
 if id~="emerald_valley" then return nil end
 for _,r in cells do if x>=r.minX and x<r.maxX and z>=r.minZ and z<r.maxZ then return r end end
 return nil
end
return table.freeze(B)
