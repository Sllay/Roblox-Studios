--!strict
local Inventory=require("./Inventory")
local Social={}
local EVENTS={talk=true,gift=true,help=true,rescue=true,share=true,protected=true}
local MEMORY_LIMIT=8
local LINK_LIMIT=6

local function between(value: any,low: number,high: number): boolean
    return type(value)=="number" and value>=low and value<=high
end

function Social.ensure(state: any,npc: any): any
    if not npc.social then
        local disposition=(state.seed%101+npc.id*37)%101
        npc.social={courage=disposition,care=(disposition*31+17)%101,trust=0,
            nextTalk=0,nextHelp=0,memories={},links={}}
    end
    return npc.social
end

function Social.valid(state: any): boolean
    local known={}
    for _,npc in ipairs(state.npcs) do known[npc.id]=true end
    for _,npc in ipairs(state.npcs) do
        local s=npc.social
        if s==nil then continue end
        if type(s)~="table" or not between(s.courage,0,100) or not between(s.care,0,100)
            or not between(s.trust,-100,100) or not between(s.nextTalk,0,state.elapsed+120)
            or not between(s.nextHelp,0,state.elapsed+120)
            or (s.shelter~=nil and not between(s.shelter,1,state.nextBuildingId-1))
            or (s.escortBy~=nil and s.escortBy~="player" and not known[s.escortBy])
            or type(s.links)~="table" or #s.links>LINK_LIMIT
            or type(s.memories)~="table" or #s.memories>MEMORY_LIMIT then return false end
        local links={}
        for i,link in pairs(s.links) do
            if not between(i,1,#s.links) or i%1~=0 or type(link)~="table"
                or not between(link.id,1,1e9) or not known[link.id] or links[link.id] or link.id==npc.id
                or not between(link.trust,-100,100) then return false end
            links[link.id]=true
        end
        for i,event in pairs(s.memories) do
            if not between(i,1,#s.memories) or i%1~=0 or type(event)~="table" or not EVENTS[event.kind]
                or not between(event.at,0,state.elapsed) or (event.by~="player" and not known[event.by]) then return false end
        end
    end
    return true
end

local function remember(s: any,kind: string,by: any,now: number,benefit: number)
    if by=="player" then
        s.trust=math.clamp(s.trust+benefit,-100,100)
    else
        local relation: any=nil
        for i,link in ipairs(s.links) do
            if link.id==by then relation=table.remove(s.links,i);break end
        end
        relation=relation or {id=by,trust=0}
        relation.trust=math.clamp(relation.trust+benefit,-100,100)
        table.insert(s.links,relation)
        if #s.links>LINK_LIMIT then table.remove(s.links,1) end
    end
    table.insert(s.memories,{kind=kind,by=by,at=now})
    if #s.memories>MEMORY_LIMIT then table.remove(s.memories,1) end
end

local function safeBuilding(b: any): boolean
    return b and (b.typeId=="castle" or b.typeId=="shelter" or b.typeId=="house")
        and b.health>0 and b.state=="complete" and not b.ruined
end

local function refuge(state: any,npc: any,work: any): any
    local best=nil
    local distance=math.huge
    for _,b in ipairs(state.buildings) do
        if safeBuilding(b) and work.canReach(state,npc.x,b.x,"worker") then
            local d=math.abs(npc.x-b.x)
            if d<distance then best,distance=b,d end
        end
    end
    return best
end

function Social.interact(state: any,npc: any,kind: any,playerBag: any,work: any): (boolean, any)
    if not state.production or npc.health<=0 then return false,"action_unavailable" end
    local s=Social.ensure(state,npc)
    if kind=="talk" then
        if state.elapsed>=s.nextTalk then
            s.nextTalk=state.elapsed+65
            remember(s,"talk","player",state.elapsed,1)
        end
        return true,Social.mood(npc)
    end
    if kind=="gift" or kind=="help" then
        if state.elapsed<s.nextHelp then return false,"social_wait" end
        local item=if kind=="help" then "food" else "plank"
        if kind=="help" and npc.hunger<35 and npc.health>=80 then return false,"social_no_need" end
        if not Inventory.transfer(playerBag,npc.inventory,item,1) then return false,"social_need_item" end
        if kind=="help" and Inventory.take(npc.inventory,"food",1) then
            npc.hunger=math.max(0,npc.hunger-35)
            npc.health=math.min(100,npc.health+8)
        end
        s.nextHelp=state.elapsed+45
        remember(s,kind,"player",state.elapsed,if kind=="help" then 7 else 4)
        return true,Social.mood(npc)
    end
    if kind=="rescue" and npc.underAttack and not s.escortBy then
        local building=refuge(state,npc,work)
        if not building then return false,"social_no_shelter" end
        s.shelter,s.escortBy=building.id,"player"
        return true,"Escolta iniciada"
    end
    return false,"action_unavailable"
end

function Social.mood(npc: any): string
    if npc.health<=0 then return "morto" end
    if npc.underAttack then
        return if npc.social and npc.social.courage>=65 then "alerta" else "assustado"
    end
    if npc.hunger>=55 then return "com fome" end
    if npc.fatigue>=75 then return "cansado" end
    if npc.social and npc.social.trust>=12 then return "confiante" end
    return "tranquilo"
end

function Social.shelter(state: any,npc: any,work: any): any
    local social=npc.social
    local b=social and work.findBuilding(state,social.shelter)
    return if safeBuilding(b) and work.canReach(state,npc.x,b.x,"worker") then b else nil
end

function Social.stepResident(state: any,npc: any,dt: number,work: any): boolean
    if not state.production then return false end
    local s=Social.ensure(state,npc)
    if s.escortBy then
        local b=Social.shelter(state,npc,work)
        if not b then
            s.escortBy,s.shelter=nil,nil
        elseif (npc.x-b.x)^2+((npc.z or 0)+4.4)^2<=4 then
            remember(s,"rescue",s.escortBy,state.elapsed,9)
            if s.escortBy~="player" then
                for _,friend in ipairs(state.npcs) do
                    if friend.id==s.escortBy then
                        remember(Social.ensure(state,friend),"protected",npc.id,state.elapsed,4)
                        break
                    end
                end
            end
            s.escortBy,s.shelter=nil,nil
        elseif not npc.underAttack then
            npc.activity="flee"
            work.walkResident(state,npc,b.x,dt,-4.4)
            return true
        end
    end
    if npc.state~="idle" or npc.underAttack or s.care<60 or state.elapsed<s.nextHelp then return false end
    s.nextHelp=state.elapsed+8
    for _,other in ipairs(state.npcs) do
        if other==npc or other.health<=0 or math.abs(npc.x-other.x)>13
            or math.abs((npc.z or 0)-(other.z or 0))>6 then continue end
        local peer=Social.ensure(state,other)
        local trust=0
        for _,link in ipairs(s.links) do if link.id==other.id then trust=link.trust;break end end
        if other.underAttack and not peer.escortBy and s.courage+trust>=75 then
            local b=refuge(state,other,work)
            if b then peer.escortBy,peer.shelter=npc.id,b.id;return false end
        elseif other.hunger>=75 and npc.hunger<55 and math.abs(npc.x-other.x)<=3
            and Inventory.transfer(npc.inventory,other.inventory,"food",1) then
            remember(peer,"share",npc.id,state.elapsed,5)
            remember(s,"share",other.id,state.elapsed,2)
            return false
        end
    end
    return false
end

return Social
