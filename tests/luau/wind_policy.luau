--!strict
local W=require("../../games/maps/mapa-principal/game/places/main/src/ReplicatedStorage/RSWindPolicy")
assert(W.fade(0)==1 and W.fade(72)==1 and W.fade(120)==0 and W.fade(200)==0)
assert(math.abs(W.fade(96)-0.5)<0.00001)
assert(W.angle(0,0,0,0,false)==0)
assert(W.angle(0,0,18,120,false)==0)
assert(W.angle(2,1,18,0,true)<W.angle(2,1,18,0,false))
for i=0,100 do
    local a=W.angle(i*0.17,W.phase(18,32),100,0,false)
    assert(a>=0 and a<=math.rad(3.0))
end
assert(W.phase(10,20)~=W.phase(20,10))
assert(W.maxActive==48 and W.updateInterval==1/30)
print("WIND_POLICY passed: bounded sway, range fade, strength and phase")

assert(W.foliage("79689531752352","Tree_01","Canopy_01","LeafyGrass",""))
assert(W.foliage("79689531752352","Bush_03","Bush_Canopy_03","LeafyGrass",""))
assert(W.foliage("18817890736","Pine_01.1","Leaves","Plastic","rbxassetid://17718985299"))
assert(W.foliage("18817890736","Pine_03.1","Leaves","Plastic","rbxassetid://17718985397"))
assert(not W.foliage("18817890736","Pine_03.1","Trunk","Plastic","rbxassetid://17718985387"))
assert(not W.foliage("18817890736","Pine_03.1","Leaves","Plastic","rbxassetid://17718985299"))
assert(W.angle(0,0,8,0,false)>math.rad(1))
print("P4.5 foliage mapping and amplitude passed")
