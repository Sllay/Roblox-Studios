--!strict
-- Hierarchical passive-prey policy; pure decision layer, engine adapters intentionally separate.
export type State="Idle"|"Explore"|"Forage"|"Peck"|"Flee"|"Recover"|"Flap"|"Static"|"Dead"
export type Sense={dt:number,alive:boolean,aiEnabled:boolean,hit:boolean,threatVisible:boolean,threatDistance:number,approachSpeed:number,predator:boolean,foodAvailable:boolean,atFood:boolean,pathBlocked:boolean,escapeAvailable:boolean,stuck:boolean,random:number}
export type Memory={state:State,age:number,calm:number,fear:number,hunger:number,reason:string,transitions:number}
export type Intent={state:State,branch:string,animation:string,action:string,reason:string}
local M={}
function M.new():Memory return {state="Idle",age=0,calm=0,fear=0,hunger=.2,reason="spawn",transitions=0} end
local function change(m:Memory,s:State,reason:string)
 if m.state~=s then m.state=s;m.age=0;m.transitions+=1;m.reason=reason end
end
function M.step(m:Memory,s:Sense):Intent
 local dt=math.clamp(s.dt,0,2);m.age+=dt
 if not s.alive then change(m,"Dead","death")
 elseif not s.aiEnabled then change(m,"Static","ai disabled")
 else
  local danger=s.hit or (s.threatVisible and ((s.predator and s.threatDistance<22) or (s.approachSpeed>3 and s.threatDistance<12) or s.threatDistance<2.5))
  if danger then m.fear=1;m.calm=0 else m.fear=math.max(0,m.fear-dt*.25);m.calm+=dt end
  m.hunger=math.min(1,m.hunger+dt*.012)
  if danger or (m.state=="Flee" and m.calm<3) or (m.state=="Recover" and m.fear>.3) then
   if (s.stuck or s.pathBlocked) and not s.escapeAvailable then change(m,"Recover","escape blocked")
   else change(m,"Flee",if s.hit then "hit" else "threat") end
  elseif m.state=="Flee" or m.state=="Recover" then change(m,"Idle","threat cleared")
  elseif m.state=="Peck" then
   if m.age>=1.25 then m.hunger=math.max(0,m.hunger-.18);change(m,"Explore","peck completed") end
  elseif m.state=="Flap" then
   if m.age>=1.25 then change(m,"Idle","flap completed") end
  elseif m.state=="Static" or m.state=="Dead" then change(m,"Idle","reactivated")
  elseif s.pathBlocked or s.stuck then change(m,"Recover","route blocked")
  elseif s.foodAvailable and m.hunger>.35 then
   change(m,if s.atFood then "Peck" else "Forage","food")
  elseif m.state=="Idle" and m.age>=2 then
   change(m,if s.random<.12 then "Flap" else "Explore","idle complete")
  elseif (m.state=="Explore" or m.state=="Forage") and m.age>=8 then change(m,"Idle","exploration complete")
  end
 end
 local state:State=m.state :: State
 local branch=if state=="Dead" then "Lifecycle" elseif state=="Static" then "Disabled" elseif state=="Flee" or state=="Recover" then "Survival" else "Routine"
 local anim=if state=="Flee" then "Run" elseif state=="Explore" or state=="Forage" then "Walk" elseif state=="Peck" then "Peck" elseif state=="Flap" then "Flap" else "Idle"
 local action=if state=="Flee" then "ChooseSafeEscape" elseif state=="Recover" then "ReplanEscape" elseif state=="Forage" then "SeekFood" elseif state=="Explore" then "Wander" elseif state=="Peck" then "Peck" elseif state=="Flap" then "Flap" else "Stop"
 return {state=state,branch=branch,animation=anim,action=action,reason=m.reason}
end
return table.freeze(M)
