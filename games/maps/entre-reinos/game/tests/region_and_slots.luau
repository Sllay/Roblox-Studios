--!strict
local W = require("../places/main/src/ReplicatedStorage/WorldProfile")
local S = require("../places/main/src/ReplicatedStorage/SlotModel")
assert(W.validSeed(1) and W.validSeed(2147483646))
assert(not W.validSeed(0) and not W.validSeed(1.5) and not W.validSeed(math.huge))
assert(W.signature(42) == "1:42")
local a = W.sample(42, 0, 0)
local b = W.sample(42, 0, 0)
assert(a.height == b.height and a.material == b.material)
assert(not a.wet and a.material == "Grass")
local river = W.sample(42, 76, 0)
assert(river.wet and river.height == -6)
assert(W.sample(42, 76, -44).wet)
assert(W.sample(42, 76, 44).wet)
local w2 = W.sample(1234, -120, -42)
local w3 = W.sample(1234, -120, -42)
assert(w2.height == w3.height)
assert(a.height == W.sample(42, 0, 0).height)
local spawn = W.spawn(42)
assert(spawn.x == 0 and spawn.z == 0 and spawn.y == a.height + 5)
for i = 1, 6 do
    assert(S.validIndex(i))
    assert(S.key(10001, i) ~= S.key(10002, i))
    local s = S.newWorld(i, 100, W.spawn(i))
    assert(S.validWorld(s))
    assert(S.summary(s, i).exists)
    assert(S.summary(s, i).worldDay == 1)
    assert(S.key(10001, i) ~= S.key(10001, if i == 6 then 1 else i + 1))
    s.position.z = 7
    assert(not S.validWorld(s))
end
assert(not S.validIndex(0) and not S.validIndex(7) and not S.validIndex(1.1))
assert(not S.validIndex("3"))
assert(S.summary(nil, 1).exists == false)
assert(S.summary({deleted = true}, 1).exists == false)
assert(S.summary({foo = 1}, 1).corrupt)
local legacy = S.newWorld(11, 100, {x=0,y=15,z=0})
assert(S.SAVE_FORMAT_VERSION==1 and S.RULESET_VERSION==1)
assert(legacy.saveFormatVersion==1 and legacy.rulesetVersion==1)
local v1=S.newWorld(11,100,{x=0,y=15,z=0})
v1.saveFormatVersion=nil
v1.rulesetVersion=nil
assert(S.validWorld(v1),"legacy slot without metadata must be readable")
assert(S.summary(v1,1).compatibility=="legacy_compatible")
local future=S.newWorld(11,100,{x=0,y=15,z=0})
future.rulesetVersion=999
assert(not S.validWorld(future))
local protected=S.summary(future,1)
assert(protected.exists and protected.incompatible and
    protected.compatibility=="newer_save_protected","new save must fail closed")
assert(S.validWorld(S.newWorld(11,100,{x=0,y=15,z=0})))
legacy.schemaVersion = 999
assert(not S.validWorld(legacy))
print("ENTRE_REINOS_PURE: deterministic world, 6 independent slots and schema assertions passed")
-- Session lock and retry decisions are tested with the same pure module used on the server.
local P = require("../places/main/src/ReplicatedStorage/SlotLeasePolicy")
assert(P.foreignLease(nil, "a", 100) == false)
assert(P.foreignLease({token="a", expiresAt=200}, "a", 100) == false)
assert(P.foreignLease({token="b", expiresAt=200}, "a", 100) == true)
assert(P.foreignLease({token="b", expiresAt=100}, "a", 100) == false)
assert(P.foreignLease({token="b", expiresAt=99}, "a", 100) == false)
assert(P.foreignLease({token="b", expiresAt="invalid"}, "a", 100) == true)
assert(P.foreignLease("bad schema", "a", 100) == true)
assert(P.writeDecision(nil, "a", 0, 1, "op1") == "conflict")
local owned = {revision=7, lock={token="a",expiresAt=200}, lastWriteId="older"}
assert(P.writeDecision(owned, "a", 7, 8, "op1") == "apply")
assert(P.writeDecision(owned, "b", 7, 8, "op1") == "conflict")
assert(P.writeDecision(owned, "a", 6, 7, "op1") == "conflict")
local saved = {revision=8, lock={token="a",expiresAt=200}, lastWriteId="op1"}
assert(P.writeDecision(saved, "a", 7, 8, "op1") == "already_applied")
saved.lock = nil
assert(P.writeDecision(saved, "a", 7, 8, "op1") == "already_applied")
saved.lock = {token="b",expiresAt=200}
assert(P.writeDecision(saved, "a", 7, 8, "op1") == "conflict")
print("ENTRE_REINOS_LEASE: ownership, expiry, revision and retry assertions passed")


-- The lobby and reserved-world gateway share a pure, versioned ticket contract.
local R = require("../places/main/src/ReplicatedStorage/WorldRoute")
assert(R.isWorldServer("guid", 0))
assert(not R.isWorldServer("", 0))
assert(not R.isWorldServer("guid", 5))
local accepted = {kind=R.KIND,protocol=R.PROTOCOL,slot=1,ownerUserId=421,
    reservedId="reserved-guid",sourcePlaceId=90623742498445}
assert(R.validArrival(accepted,421,90623742498445,"reserved-guid"))
assert(not R.validArrival(accepted,422,90623742498445,"reserved-guid"))
assert(not R.validArrival(accepted,421,90623742498446,"reserved-guid"))
assert(not R.validArrival(accepted,421,90623742498445,"another-reserved-guid"))
assert(not R.validArrival(nil,421,90623742498445,"reserved-guid"))
local wrongSlot = table.clone(accepted)
wrongSlot.slot = 7
assert(not R.validArrival(wrongSlot,421,90623742498445,"reserved-guid"))
local wrongProtocol = table.clone(accepted)
wrongProtocol.protocol = 2
assert(not R.validArrival(wrongProtocol,421,90623742498445,"reserved-guid"))
print("ENTRE_REINOS_ROUTE: lobby-to-reserved server auth contract passed")

-- Use the stock Roblox control system, but project thumbstick X/Z onto
-- the 2.5D character's X/Y lane. These are executable pure Luau tests.
local Input = require("../places/main/src/ReplicatedStorage/InputProjection")
local ix,iy=Input.toLane(1,0)
assert(ix==1 and iy==0)
ix,iy=Input.toLane(-0.5,0)
assert(ix==-0.5 and iy==0)
ix,iy=Input.toLane(0,-1) -- Roblox native up = negative Z
assert(ix==0 and iy==1)
ix,iy=Input.toLane(0,1)
assert(ix==0 and iy==-1)
ix,iy=Input.toLane(1,-1)
assert(math.abs(ix-0.70710678)<0.00001 and math.abs(iy-0.70710678)<0.00001)
ix,iy=Input.toLane(0.02,-0.02)
assert(ix==0 and iy==0)
ix,iy=Input.toLane(math.huge,0)
assert(ix==0 and iy==0)
assert(Input.facing(1,0,false,0)==-math.pi/2)
assert(Input.facing(-1,0,false,0)==math.pi/2)
assert(Input.facing(0,1,false,0)==0)
assert(Input.facing(0,-1,false,0)==math.pi)
assert(Input.facing(0,1,true,math.pi/2)==math.pi/2)
print("ENTRE_REINOS_NATIVE_INPUT: analog X/Y, swim Z-to-height, diagonal and facing tests passed")

-- Water and swimming state are now exclusively owned by native Terrain/Humanoid.
-- InputProjection is the only custom translation for vertical swim controls.

local boundary = S.newWorld(42, 100, W.spawn(42))
for _, x in ipairs({-121, -120.5, 120.5, 121}) do
    boundary.position.x = x
    assert(S.validWorld(boundary), "v15 boundary position must remain loadable")
end
boundary.position.x = 121.01
assert(not S.validWorld(boundary))
assert(S.summary(boundary, 1).exists and S.summary(boundary, 1).corrupt)
assert(S.summary("invalid payload", 1).exists and S.summary("invalid payload", 1).corrupt)
local Living = require("../places/main/src/ReplicatedStorage/Living/LivingModel")
local wrongSeed: any = S.newWorld(42, 100, W.spawn(42))
wrongSeed.living = Living.new(43)
assert(not S.validWorld(wrongSeed), "population from another seed cannot replace the slot")
print("ENTRE_REINOS_T1_F1_SAVE: legacy boundary, protected corrupt slots and population seed passed")
