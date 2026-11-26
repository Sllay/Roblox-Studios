--!strict
-- Scripted first campaign. Existing mid-prologue saves keep their legacy path.
local Story={}
local hints=table.freeze({
    guard="Fale com o duque diante do castelo.",
    escort="Escolte o duque para além da muralha oeste.",
    encounter="A criatura se aproxima. Fique junto da escolta.",
    hesitation="O duque foi atingido. Os guardas hesitam.",
    duke_fight="O duque caiu sob a infecção. Proteja-se e enfrente-o.",
    crisis="Ataque nas duas fronteiras! Volte para a vila.",
    evacuation="Volte ao castelo e ordene a evacuação dos moradores.",
    last_ring="Defenda o último anel. As muralhas externas precisam ser reconstruídas.",
    coronation="Encontre os sobreviventes no castelo e aceite a coroa.",
})
local DUKE_START=-4
local ESCORT_END=-45

function Story.new(): any
    return {stage="guard",time=0,scene=true,dukeX=DUKE_START,creatureX=-53}
end

function Story.valid(p: any): boolean
    if p.scene==nil then return true end
    return p.scene==true and (hints[p.stage]~=nil or p.stage=="sandbox")
        and type(p.time)=="number" and p.time>=0 and p.time<math.huge
        and type(p.dukeX)=="number" and p.dukeX>=ESCORT_END and p.dukeX<=DUKE_START
        and type(p.creatureX)=="number" and p.creatureX>=-53 and p.creatureX<=ESCORT_END
end

function Story.enter(p: any,stage: string)
    p.stage=stage
    p.time=0
end

function Story.hint(p: any): string?
    return if p.scene then hints[p.stage] else nil
end

function Story.command(p: any,action: string,x: number?): (boolean, string?)
    if not x then return false,"too_far_from_story" end
    if action=="training" and p.stage=="guard" then
        if math.abs(x-DUKE_START)>8 then return false,"too_far_from_story" end
        Story.enter(p,"escort")
        return true,nil
    end
    if (action=="evacuate" and p.stage=="evacuation")
        or (action=="coronation" and p.stage=="coronation") then
        if math.abs(x)>9 then return false,"too_far_from_story" end
        return true,nil
    end
    return false,"action_unavailable"
end

function Story.advance(p: any,dt: number,x: number,playerReady: boolean): boolean
    if not p.scene or not playerReady then return false end
    if p.stage=="escort" then
        if math.abs(x-p.dukeX)<=14 then
            p.dukeX=math.max(ESCORT_END,p.dukeX-dt*6)
            if p.dukeX<=ESCORT_END then Story.enter(p,"encounter") end
        end
    elseif p.stage=="encounter" then
        if math.abs(x-p.dukeX)<=17 then
            p.creatureX=math.min(p.dukeX,p.creatureX+dt*4)
            if p.creatureX>=p.dukeX then Story.enter(p,"hesitation") end
        end
    elseif p.stage=="hesitation" and p.time>=2 then
        Story.enter(p,"duke_fight")
        return true
    end
    return false
end

function Story.actors(p: any): {any}
    if not p.scene then return {} end
    local phase=p.stage
    if phase=="coronation" then
        return {{id="herald",label="Porta-voz dos sobreviventes",x=0,kind="guard",activity="crown",direction=1}}
    end
    if phase=="duke_fight" or phase=="crisis" then
        return {
            {id="guard_one",label="",x=p.dukeX+3,kind="guard",activity="fallen",direction=-1},
            {id="guard_two",label="",x=p.dukeX+6,kind="guard",activity="fallen",direction=-1},
        }
    end
    if not (phase=="guard" or phase=="escort" or phase=="encounter" or phase=="hesitation") then
        return {}
    end
    local activity=if phase=="hesitation" then "stagger" elseif phase=="escort" then "escort" else "idle"
    local result={
        {id="duke",label="Duque",x=p.dukeX,kind="duke",activity=activity,direction=-1},
        {id="guard_one",label="Guarda real",x=p.dukeX+3,kind="guard",activity=activity,direction=-1},
        {id="guard_two",label="Guarda real",x=p.dukeX+6,kind="guard",activity=activity,direction=-1},
    }
    if phase=="encounter" or phase=="hesitation" then
        table.insert(result,{id="creature",label="Criatura infectante",
            x=p.creatureX,kind="creature",activity="encounter",direction=1})
    end
    return result
end
return Story
