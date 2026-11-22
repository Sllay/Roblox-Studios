--!strict
-- T1-R3 executable pure domain contracts; no Roblox engine shims.
local Living=require("../places/main/src/ReplicatedStorage/Living/LivingModel")
local R3=require("../places/main/src/ReplicatedStorage/Living/R3Engine")
local Work=require("../places/main/src/ReplicatedStorage/Living/WorkEngine")
local Structures=require("../places/main/src/ReplicatedStorage/Living/StructureDefs")
local seed=516639272

local legacy=Living.new(seed)
assert(legacy.r3==nil)
local old=Living.clone(legacy)
local sandbox=R3.ensure(legacy,false)
assert(sandbox.prologue.stage=="sandbox")
assert(Living.valid(legacy))
assert(Living.restore(Living.clone(legacy),seed))
assert(old.r3==nil, "migrating old save must not mutate previous snapshot")
assert(R3.ensure(legacy,false)==sandbox, "migration must be idempotent")
local fresh=Living.new(seed)
local d=R3.ensure(fresh,true)
assert(d.prologue.stage=="guard" and #d.enemies==0 and d.wallet==0)
assert(R3.command(fresh,"evacuate")==false)
assert(R3.command(fresh,"training"))
assert(d.prologue.stage=="crisis" and #d.enemies==4)
assert(R3.spawnWave(fresh,2)==false, "no duplicate raid wave")
local originalId=d.enemies[1].id
local leftX=d.enemies[1].x
assert(R3.hit(fresh,leftX-1,20,1,6,99))
assert(d.stats.killed==1 and d.enemies[1].id~=originalId)

-- Removing defeated enemies transitions the interactive script into civilian
-- evacuation and then the final defensive ring; no coin grant until coronation.
for _,e in ipairs(d.enemies) do e.hp=0 end
R3.step(fresh,0.1,0)
assert(d.prologue.stage=="evacuation" and #d.enemies==0 and d.wallet==0)
assert(R3.command(fresh,"evacuate"))
assert(d.prologue.stage=="last_ring" and #d.enemies==4)
for _,e in ipairs(d.enemies) do e.hp=0 end
R3.step(fresh,0.1,0)
assert(d.prologue.stage=="coronation" and d.wallet==0)
assert(R3.command(fresh,"coronation"))
assert(d.prologue.stage=="sandbox" and d.wallet==8 and d.treasury==16)
assert(not R3.command(fresh,"coronation"),"crown grant must be issued only once")

-- Real currency: player may drop a minted-from-treasury coin exactly once.
local previous=d.wallet
local ok,dropId=R3.drop(fresh,0,1)
assert(ok and d.wallet==previous-1)
assert(R3.pickup(fresh,dropId,60)==false,"pickup must be near")
assert(R3.pickup(fresh,dropId,0))
assert(d.wallet==previous)
assert(R3.pickup(fresh,dropId,0)==false,"no duplicate pickup")
assert(R3.drop(fresh,0,1000)==false)
assert(R3.trade(fresh,"fake",0)==false)
local woodBefore=fresh.sites[1].remaining
local treasuryBefore=d.treasury
local balanceBefore=d.wallet
assert(R3.trade(fresh,"wood",0))
assert(fresh.sites[1].remaining==woodBefore-1)
assert(d.treasury==treasuryBefore-1 and d.wallet==balanceBefore+1)
assert(R3.trade(fresh,"wood",100)==false,"trade not possible outside village")
assert(d.wallet+d.treasury==balanceBefore+treasuryBefore,
    "trade only transfers money, never prints new money")

-- Equipment consumes real finite resources and cannot be free-repeated.
local woodAfterTrade=fresh.sites[1].remaining
local equipped,npcId=R3.arm(fresh,1,"bow")
assert(equipped and npcId==1)
assert(fresh.sites[1].remaining==woodAfterTrade-3)
assert(R3.arm(fresh,1,"bow")==false)
assert(R3.arm(fresh,999,"spear")==false)

-- Wall exists as a true collision gate in the 2.5D raid lane.
local blocked=Living.new(seed)
local bstate=R3.ensure(blocked,false)
local placed,wall=Work.place(blocked,"wall",18)
assert(placed)
wall.progress=Structures.get("wall").buildSeconds
wall.state="complete"
wall.health=Structures.get("wall").health
assert(R3.spawnWave(blocked,2))
local right=nil
for _,e in ipairs(bstate.enemies) do if e.side==1 then right=e;break end end
assert(right~=nil)
for _=1,500 do
    Work.step(blocked,0.1)
    R3.step(blocked,0.1,0)
end
assert(right.x>=wall.x-3,"wall must stop a raider while intact")
assert(wall.health<Structures.get("wall").health,
    "real structure must lose HP when attacked")
assert(wall.state=="damaged")
-- Raid conditions do not roll every night and preserve existing snapshots.
local saved=Living.clone(fresh)
assert(Living.valid(saved))
local reopened=Living.restore(saved,seed)
assert(reopened and R3.valid(reopened.r3))
assert(reopened.r3.wallet==fresh.r3.wallet)
assert(reopened.r3.prologue.stage=="sandbox")
assert(reopened.r3.stats.killed==fresh.r3.stats.killed)
saved.r3.wallet=-5
assert(not Living.valid(saved),"invalid R3 ledger must block save")
print("ENTRE_REINOS_T1_R3: prologue, combat, raids, walls, trade, loot, equip, save passed")
