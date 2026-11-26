--!strict
-- Local steering index. Rebuilt once per simulation tick and updated after movement.
local Crowd={}
local CELL=4
Crowd.INDEX_MIN=9
local worlds=setmetatable({}, {__mode="k"})
local function key(x: number,z: number): string
    return tostring(x)..":"..tostring(z)
end
local function update(index: any,npc: any)
    local cell=key(math.floor(npc.x/CELL),math.floor((npc.z or 0)/CELL))
    local old=index.cells[npc]
    if old==cell then return end
    if old then index.bins[old][npc]=nil end
    index.cells[npc]=cell
    local bin=index.bins[cell]
    if not bin then bin={};index.bins[cell]=bin end
    bin[npc]=true
end
function Crowd.index(state: any): any
    local index=worlds[state]
    if not index then
        index={tick=-1,stands={},claims={},approaches={}}
        worlds[state]=index
    end
    if #state.npcs>=Crowd.INDEX_MIN and index.tick~=state.elapsed then
        index.tick=state.elapsed
        index.bins,index.cells={},{}
        for _,npc in ipairs(state.npcs) do
            if npc.health>0 then update(index,npc) end
        end
    end
    return index
end
function Crowd.move(state: any,npc: any)
    update(Crowd.index(state),npc)
end
function Crowd.near(index: any,npc: any): {any}
    local x,z=math.floor(npc.x/CELL),math.floor((npc.z or 0)/CELL)
    local neighbors={}
    for dx=-1,1 do
        for dz=-1,1 do
            local bin=index.bins[key(x+dx,z+dz)]
            if not bin then continue end
            for other in pairs(bin) do
                if other~=npc and other.health>0 then table.insert(neighbors,other) end
            end
        end
    end
    table.sort(neighbors,function(a,b) return a.id<b.id end)
    return neighbors
end
function Crowd.release(state: any,npc: any)
    local index=worlds[state]
    local claim=index and index.claims[npc]
    if claim then
        index.stands[claim.key]=nil
        index.claims[npc]=nil
    end
end
function Crowd.stand(state: any,npc: any,id: number,options: {number}): (number?,number?)
    local index=Crowd.index(state)
    local existing=index.claims[npc]
    if existing and existing.id==id and existing.untilTime>=state.elapsed then
        existing.untilTime=state.elapsed+1.5
        return existing.offset,existing.slot
    end
    Crowd.release(state,npc)
    for slot,offset in ipairs(options) do
        local claimKey=key(id,slot)
        local owner=index.stands[claimKey]
        if owner and owner.npc.health>0 and owner.untilTime>=state.elapsed then continue end
        if owner then index.claims[owner.npc]=nil end
        local claim={npc=npc,id=id,key=claimKey,slot=slot,offset=offset,untilTime=state.elapsed+1.5}
        index.claims[npc]=claim
        index.stands[claimKey]=claim
        return offset,slot
    end
    return nil,nil
end
return Crowd
