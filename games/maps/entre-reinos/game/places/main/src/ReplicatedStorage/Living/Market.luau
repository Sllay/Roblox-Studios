--!strict
-- Both treasuries and the single freight contract commit in the same slot snapshot.
local Inventory=require("./Inventory")
local Items=require("./ItemDefs")
local Market={}
Market.goods=table.freeze({"wood","stone","iron","food","plank","metal","grain","meat","leather"})
local BASE: {[string]: number}={wood=2,stone=3,iron=4,food=2,plank=3,metal=6,grain=1,meat=3,leather=3}
local LIMIT=32

local function integer(value: any,lo: number,hi: number): boolean
    return type(value)=="number" and value%1==0 and value>=lo and value<=hi
end

function Market.ensure(state: any)
    if state.production.market then return end
    state.production.market={
        balance=if state.r3 then 0 else 24,ledger={},requests={},nextContract=1,payDay=math.floor(state.elapsed/240),
        standing=0,
    }
end

local function acc(state: any): any
    return state.production.market
end

function Market.treasury(state: any): number
    return if state.r3 then state.r3.treasury else acc(state).balance
end

local function pay(state: any,amount: number)
    if state.r3 then state.r3.treasury+=amount else acc(state).balance+=amount end
end

local function log(state: any,kind: string,value: number,detail: string)
    local rows=acc(state).ledger
    table.insert(rows,{kind=kind,value=value,detail=detail})
    if #rows>LIMIT then table.remove(rows,1) end
end

function Market.valid(state: any): boolean
    local data=state.production.market
    if data==nil then return true end
    if type(data)~="table" or not integer(data.balance,0,1e9) or not integer(data.payDay,0,1e9)
        or not integer(data.standing,-100,100) or not integer(data.nextContract,1,1e9)
        or (data.accord~=nil and data.accord~="trade" and data.accord~="alliance")
        or (data.nextTribute~=nil and (type(data.nextTribute)~="number"
            or not (data.nextTribute>=0 and data.nextTribute<=state.elapsed+91)))
        or type(data.ledger)~="table" or #data.ledger>LIMIT
        or type(data.requests)~="table" or #data.requests>LIMIT then return false end
    for _,id in ipairs(data.requests) do
        if type(id)~="string" or #id>40 then return false end
    end
    for _,row in ipairs(data.ledger) do
        if type(row)~="table" or type(row.kind)~="string" or #row.kind>24
            or not integer(row.value,-1e9,1e9) or type(row.detail)~="string" or #row.detail>50 then return false end
    end
    local c=data.contract
    if c~=nil then
        if type(c)~="table" or not integer(c.id,1,data.nextContract-1) or type(c.item)~="string" or not BASE[c.item]
            or (c.seller~="home" and c.seller~="foreign")
            or not integer(c.units,1,6) or not integer(c.payment,1,100)
            or (c.worker~=nil and not integer(c.worker,1,1e9))
            or (c.stage~="pickup" and c.stage~="delivery" and c.stage~="recover")
            or (c.returning~=nil and type(c.returning)~="boolean") or not Inventory.valid(c.cargo) then return false end
        local expected=if c.stage=="pickup" then 0 else c.units
        if Inventory.count(c.cargo,c.item)~=expected or Inventory.weight(c.cargo)~=expected*
            Items.get(c.item).mass then return false end
        if c.stage=="recover" and (type(c.cacheX)~="number" or not (math.abs(c.cacheX)<1600)
            or type(c.cacheZ)~="number" or not (math.abs(c.cacheZ)<32)) then return false end
    end
    for _,npc in ipairs(state.npcs) do
        if npc.coins~=nil and not integer(npc.coins,0,1e9) then return false end
    end
    return true
end

function Market.center(state: any): any
    for _,b in ipairs(state.buildings) do
        if b.typeId=="castle" and b.health>0 and not b.ruined then return b end
    end
    return nil
end

local function depot(state: any,item: string,amount: number,x: number,source: boolean,work: any): any
    local best=nil
    local distance=math.huge
    for _,b in ipairs(state.buildings) do
        local d=math.abs(x-b.x)
        if d<distance and work.usableStorage(b) and (if source
            then work.stockAvailable(state,b,item)>=amount else work.storageFree(state,b,item)>=amount) then
            best,distance=b,d
        end
    end
    return best
end

function Market.quote(state: any,item: string,work: any): any
    local base=BASE[item]
    if not base then return nil end
    local stock=0
    for _,b in ipairs(state.buildings) do stock+=work.stockAvailable(state,b,item) end
    local buy=math.clamp(base+2-math.floor(stock/8),math.max(2,base-1),base+2)
    return {stock=stock,buy=buy,sell=math.max(1,buy-1)}
end

local function remember(data: any,id: string)
    table.insert(data.requests,id)
    if #data.requests>LIMIT then table.remove(data.requests,1) end
end

function Market.playerTrade(state: any,playerData: any,id: any,verb: any,item: any,work: any): (boolean,string?)
    if type(id)~="string" or #id>40 or not string.match(id,"^[%x%-]+$")
        or type(item)~="string" or (verb~="buy" and verb~="sell") then return false,"invalid_market_order" end
    local data=acc(state)
    if table.find(data.requests,id) then return true,"duplicate" end
    local quote=Market.quote(state,item,work)
    local center=Market.center(state)
    if not center or not quote then return false,"invalid_market_order" end
    local buying=verb=="buy"
    local price=if buying then quote.buy else quote.sell
    if (if buying then playerData.wallet else Market.treasury(state))<price then return false,"market_funds" end
    local b=depot(state,item,1,center.x,buying,work)
    if not b or math.abs(b.x-center.x)>45 then return false,"market_stock" end
    local from,to=if buying then b.stored else playerData.playerBag,if buying then playerData.playerBag else b.stored
    if not Inventory.transfer(from,to,item,1) then return false,"market_stock" end
    local delta=if buying then price else -price
    pay(state,delta)
    playerData.wallet-=delta
    log(state,verb,delta,item)
    remember(data,id)
    return true,nil
end

function Market.payroll(state: any)
    local data=acc(state)
    local day=math.floor(state.elapsed/240)
    if day<=data.payDay then return end
    data.payDay=day
    for _,n in ipairs(state.npcs) do
        if n.health<=0 then continue end
        n.coins=n.coins or 0
        if n.coins>=4 then
            n.coins-=1
            pay(state,1)
            log(state,"tax",1,tostring(n.id))
        end
        if n.profession~="common" and Market.treasury(state)>0 then
            n.coins+=1
            pay(state,-1)
            log(state,"wage",-1,tostring(n.id))
        end
    end
end

local function realms(session: any,seller: string): (any,any)
    return if seller=="home" then session.home else session.record.foreign,
        if seller=="home" then session.record.foreign else session.home
end

function Market.openContract(session: any,seller: any,item: any,units: any,requestId: any,work: any): (boolean,string?)
    local home=session.home
    if not session.record.discovered["2"] or not session.record.foreign or not home.production
        or not home.production.market or not session.record.foreign.production
        or (seller~="home" and seller~="foreign") or type(item)~="string" or not BASE[item]
        or not integer(units,1,6) or type(requestId)~="string" or #requestId>40
        or not string.match(requestId,"^[%x%-]+$") then return false,"invalid_market_order" end
    local data=acc(home)
    if table.find(data.requests,requestId) then return true,"duplicate" end
    if data.contract then return false,"market_contract_active" end
    if data.standing<=-20 then return false,"market_hostile" end
    local origin,destination=realms(session,seller)
    Market.ensure(destination)
    Market.ensure(origin)
    local a,b=Market.center(origin),Market.center(destination)
    if not a or not b then return false,"market_stock" end
    local from=depot(origin,item,units,a.x,true,work)
    local to=depot(destination,item,units,b.x,false,work)
    if not from or not to then return false,"market_stock" end
    if not work.canReach(origin,from.x,to.x,"carrier") then return false,"market_route" end
    local quote=Market.quote(origin,item,work)
    local payment=units*math.max(1,quote.buy-(if data.accord then 1 else 0))
    if Market.treasury(destination)<payment then return false,"market_funds" end
    local id=data.nextContract
    data.nextContract+=1
    pay(destination,-payment)
    log(destination,"freight_escrow",-payment,tostring(id))
    data.contract={id=id,seller=seller,item=item,units=units,payment=payment,stage="pickup",cargo=Inventory.new(36)}
    remember(data,requestId)
    return true,nil
end

function Market.cancel(session: any): boolean
    local c=acc(session.home).contract
    if not c or c.returning then return false end
    c.returning=true
    return true
end

function Market.freight(session: any): (any,any)
    local data=session.home.production and session.home.production.market
    local c=data and data.contract
    if not c then return nil,nil end
    local origin=realms(session,c.seller)
    if origin then
        for _,n in ipairs(origin.npcs) do
            if n.id==c.worker then return c,n end
        end
    end
    return c,nil
end

function Market.stepFreight(session: any,dt: number,work: any)
    local c,worker=Market.freight(session)
    if not c then return end
    local home=session.home
    local data=acc(home)
    local origin,dest=realms(session,c.seller)
    if not origin or not dest then return end
    if c.returning and c.stage=="pickup" then
        pay(dest,c.payment)
        log(dest,"escrow_return",c.payment,tostring(c.id))
        if worker then work.releaseWorker(origin,worker);worker.tradeLoad=nil end
        data.contract=nil
        return
    end
    if worker and worker.health<=0 then
        if c.stage~="pickup" then c.stage,c.cacheX,c.cacheZ="recover",worker.x,worker.z or 0 end
        worker.tradeLoad=nil
        c.worker,worker=nil,nil
    end
    if not worker then
        for _,n in ipairs(origin.npcs) do
            if n.health>0 and not n.underAttack and not n.tradeLoad
                and (n.profession=="carrier" or n.profession=="merchant") then worker=n;break end
        end
        if not worker then
            for _,n in ipairs(origin.npcs) do
                if n.state=="idle" and n.health>0 and not n.underAttack then worker=n;break end
            end
        end
        if not worker then return end
        work.releaseWorker(origin,worker)
        c.worker=worker.id
    end
    if worker.underAttack then worker.state="freight";return end
    worker.state="freight"
    worker.tradeLoad=Inventory.weight(c.cargo)>0 and c.stage~="recover"
    worker.activity="freight"
    if c.stage=="recover" then
        if work.walkResident(origin,worker,c.cacheX,dt,c.cacheZ,nil,true) then
            c.stage,c.cacheX,c.cacheZ="delivery",nil,nil
        end
        return
    end
    local receiving=if c.returning then origin else dest
    local town=Market.center(if c.stage=="pickup" then origin else receiving)
    if not town then return end
    local b=depot(if c.stage=="pickup" then origin else receiving,c.item,c.units,town.x,c.stage=="pickup",work)
    if not b or not work.walkResident(origin,worker,b.x,dt,-4.4,nil,true) then return end
    if c.stage=="pickup" then
        if work.stockAvailable(origin,b,c.item)>=c.units and Inventory.transfer(b.stored,c.cargo,c.item,c.units) then
            c.stage="delivery"
        end
        return
    end
    if work.storageFree(receiving,b,c.item)<c.units or not Inventory.transfer(c.cargo,b.stored,c.item,c.units) then return end
    if c.returning then
        pay(dest,c.payment)
        log(dest,"escrow_return",c.payment,tostring(c.id))
        data.standing=math.max(-100,data.standing-6)
        if data.standing<0 then data.accord=nil end
    else
        pay(origin,c.payment)
        log(origin,"freight_sale",c.payment,tostring(c.id))
        log(dest,"freight_received",0,tostring(c.id))
        data.standing=math.min(100,data.standing+5)
    end
    worker.tradeLoad=nil
    work.releaseWorker(origin,worker)
    data.contract=nil
end

function Market.diplomacy(session: any,action: any): (boolean,string?)
    local home,foreign=session.home,session.record.foreign
    local data=home.production and home.production.market
    if not data or not session.record.discovered["2"] or not foreign or not foreign.production
        or not foreign.production.market then return false,"market_unmet" end
    if action=="trade" and data.standing>=0 and not data.accord then
        data.accord="trade"
    elseif action=="alliance" and data.accord=="trade" and data.standing>=15 then
        data.accord="alliance"
    elseif action=="withdraw" and data.accord then
        data.accord=nil
        data.standing=math.max(-100,data.standing-12)
    elseif action=="tribute" then
        local now=home.elapsed
        if now<(data.nextTribute or 0) or Market.treasury(home)<3 then return false,"market_funds" end
        pay(home,-3)
        pay(foreign,3)
        log(home,"tribute",-3,"Cedro")
        log(foreign,"tribute",3,"Vale")
        data.nextTribute=now+90
        data.standing=math.min(100,data.standing+8)
    else
        return false,"diplomacy_conditions"
    end
    return true,nil
end

function Market.relations(session: any): any
    local data=session.home.production and session.home.production.market
    if not data or not session.record.discovered["2"] then return nil end
    local standing=data.standing
    local attitude=if standing<=-20 then "hostil" elseif standing>=15 then "amigável" else "neutra"
    return {standing=standing,attitude=attitude,accord=data.accord}
end

function Market.summary(state: any,work: any): any
    if not state.production or not state.production.market then return nil end
    local quotes={}
    for _,item in ipairs(Market.goods) do quotes[item]=Market.quote(state,item,work) end
    local data=acc(state)
    local last=data.ledger[#data.ledger]
    return {treasury=Market.treasury(state),goods=quotes,latest=last and table.clone(last)}
end

return Market
