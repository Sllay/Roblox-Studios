--!strict
-- Shared, engine-independent AI executor. Per-agent memory; immutable definitions by convention.
export type Status="Success"|"Failure"|"Running"
export type Blackboard={[string]:any}
export type Node={id:string,kind:"Action"|"Sequence"|"Selector",children:{Node}?,tick:((Blackboard,number)->Status)?,cancel:((Blackboard)->())?}
export type TreeMemory={cursor:{[string]:number},active:{[string]:boolean}}
export type State={parent:string?,enter:((Blackboard)->())?,exit:((Blackboard)->())?}
export type Machine={states:{[string]:State},current:string?,board:Blackboard}
local K={}
function K.memory():TreeMemory return {cursor={},active={}} end
function K.validate(root:Node):boolean
 local seen:{[string]:boolean}={}
 local function walk(n:Node,depth:number)
  assert(depth<=32 and #n.id>0 and not seen[n.id],"invalid tree identity/depth")
  seen[n.id]=true
  if n.kind=="Action" then assert(n.tick~=nil and n.children==nil,"invalid action")
  else
   local children=assert(n.children,"missing children");assert(#children>0,"empty branch")
   for _,c in children do walk(c,depth+1) end
  end
 end
 walk(root,1);return true
end
function K.abort(n:Node,m:TreeMemory,b:Blackboard)
 if n.kind=="Action" then
  if m.active[n.id] and n.cancel then n.cancel(b) end
 else
  for _,c in n.children or {} do K.abort(c,m,b) end
 end
 m.active[n.id]=nil;m.cursor[n.id]=nil
end
function K.tick(root:Node,m:TreeMemory,b:Blackboard,dt:number,maxVisits:number):(Status,number)
 assert(maxVisits>=1 and maxVisits%1==0,"invalid node budget")
 local visits=0
 local function run(n:Node):Status
  if visits>=maxVisits then return "Running" end
  visits+=1
  if n.kind=="Action" then
   local f=assert(n.tick);local s=f(b,dt)
   assert(s=="Success" or s=="Failure" or s=="Running","invalid action result")
   m.active[n.id]=if s=="Running" then true else nil
   return s
  end
  local children=assert(n.children);local start=m.cursor[n.id] or 1
  for i=start,#children do
   local s=run(children[i])
   if s=="Running" then m.cursor[n.id]=i;return "Running" end
   local stop=(n.kind=="Sequence" and s=="Failure") or (n.kind=="Selector" and s=="Success")
   if stop then m.cursor[n.id]=nil;return s end
  end
  m.cursor[n.id]=nil
  return if n.kind=="Sequence" then "Success" else "Failure"
 end
 return run(root),visits
end
local function ancestry(states:{[string]:State},name:string):{string}
 local path:{string}={};local seen:{[string]:boolean}={};local nextName:string?=name
 while nextName do
  local n:string=nextName
  assert(not seen[n] and #path<32,"state hierarchy cycle/depth");seen[n]=true
  local s=assert(states[n],"unknown state "..n);table.insert(path,1,n);nextName=s.parent
 end
 return path
end
function K.machine(states:{[string]:State},board:Blackboard):Machine
 for n in pairs(states) do ancestry(states,n) end
 return {states=states,current=nil,board=board}
end
function K.transition(m:Machine,target:string):boolean
 if m.current==target then return false end
 local new=ancestry(m.states,target)
 local old:{string}=if m.current then ancestry(m.states,m.current) else {}
 local common=0
 while common<math.min(#old,#new) and old[common+1]==new[common+1] do common+=1 end
 for i=#old,common+1,-1 do local f=m.states[old[i]].exit;if f then f(m.board) end end
 m.current=target
 for i=common+1,#new do local f=m.states[new[i]].enter;if f then f(m.board) end end
 return true
end
return table.freeze(K)
