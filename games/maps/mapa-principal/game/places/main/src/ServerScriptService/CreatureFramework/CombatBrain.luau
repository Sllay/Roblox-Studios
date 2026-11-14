--!strict
-- Reactive shared combat policy. State transitions never apply damage directly.
export type Sense={dt:number,alive:boolean,aiEnabled:boolean,healthRatio:number,hunger:number,targetId:string?,targetAlive:boolean,targetVisible:boolean,targetDistance:number,pathBlocked:boolean,atGoal:boolean,attackAcknowledged:number?}
export type Memory={state:string,age:number,cooldown:number,unseen:number,targetId:string?,attackToken:number,reason:string}
local C={}
function C.withProfile(p:any):any
 local M={}
 function M.new():Memory return {state="Idle",age=0,cooldown=0,unseen=math.huge,targetId=nil,attackToken=0,reason="spawn"} end
 local function change(m:Memory,state:string,why:string)
  if m.state~=state then m.state=state;m.age=0;m.reason=why end
 end
 function M.step(m:Memory,s:Sense):any
  local dt=math.clamp(s.dt,0,2);m.age+=dt;m.cooldown=math.max(0,m.cooldown-dt)
  local same=s.targetId~=nil and s.targetId==m.targetId
  if s.targetId and s.targetAlive and s.targetVisible then
   if not same then m.targetId=s.targetId;m.unseen=0;change(m,"Track","new target") else m.unseen=0 end
  else m.unseen+=dt end
  local visible=s.targetId~=nil and s.targetAlive and s.targetVisible and s.targetDistance<=p.sight
  local inRange=visible and s.targetDistance>=p.minRange and s.targetDistance<=p.maxRange
  if not s.alive then change(m,"Dead","death")
  elseif not s.aiEnabled then change(m,"Static","disabled")
  elseif s.healthRatio<=p.retreatHealth and visible then change(m,"Retreat","low health")
  elseif p.preyOnly and s.hunger<p.hungerThreshold then change(m,"Idle","satiated")
  elseif not visible then
   if m.targetId and m.unseen<5 then change(m,"Search","lost line of sight")
   else m.targetId=nil;change(m,"Idle","no target") end
  elseif m.state=="Attack" then
   if s.attackAcknowledged==m.attackToken or m.age>=.5 then change(m,"Recover","attack committed or expired") end
  elseif m.state=="Recover" and m.age<p.recovery then
   -- Recovery is interruptible by death, disable, loss of target or low health above.
  elseif m.state=="Windup" then
   if not inRange then change(m,if s.targetDistance<p.minRange then "Retreat" else "Chase","windup invalidated")
   elseif m.age>=p.windup then
    m.attackToken+=1;m.cooldown=p.cooldown;change(m,"Attack","strike")
   end
  elseif s.targetDistance<p.minRange then change(m,"Retreat","too close")
  elseif s.pathBlocked then change(m,"Reposition","route blocked")
  elseif s.targetDistance>p.maxRange then
   change(m,if p.preyOnly and s.targetDistance>8 then "Stalk" else "Chase","close distance")
  elseif inRange and m.cooldown<=0 then change(m,"Windup","valid attack window")
  else change(m,"Guard","cooldown") end
  local state=m.state
  local branch=if state=="Dead" then "Lifecycle" elseif state=="Static" then "Disabled" elseif state=="Idle" then "Routine" elseif state=="Retreat" then "Survival" else "Combat"
  local action=if state=="Attack" then (if p.kind=="Ranged" then "AttackRanged" else "AttackMelee") elseif state=="Chase" or state=="Stalk" then "Approach" elseif state=="Retreat" then "Retreat" elseif state=="Reposition" or (state=="Guard" and p.kind=="Ranged") then "Position" elseif state=="Search" then "Search" else "Stop"
  local animation=if state=="Windup" or state=="Attack" then "Attack" elseif state=="Chase" or state=="Retreat" then "Run" elseif state=="Stalk" or state=="Search" or state=="Reposition" or (state=="Guard" and p.kind=="Ranged") then "Walk" else "Idle"
  return {state=state,branch=branch,action=action,animation=animation,reason=m.reason,targetId=m.targetId,attackToken=m.attackToken}
 end
 return table.freeze(M)
end
return table.freeze(C)
