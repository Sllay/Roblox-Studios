--!strict
-- Shared action execution: perception/locomotion are injected, no per-agent heartbeat.
local A={}
local states={Alive={},Routine={parent="Alive"},Survival={parent="Alive"},Combat={parent="Alive"},Lifecycle={},Disabled={},Idle={parent="Routine"},Explore={parent="Routine"},Forage={parent="Routine"},Peck={parent="Routine"},Flap={parent="Routine"},Flee={parent="Survival"},Recover={parent="Survival"},Dead={parent="Lifecycle"},Static={parent="Disabled"}}
function A.new(brain:any,kernel:any,adapter:any):any
 local board:any={adapter=adapter,intent=nil}
 local mem=kernel.memory()
 local tree={id="act",kind="Action",tick=function(b:any,dt:number)
  return b.adapter:execute(b.intent,dt)
 end,cancel=function(b:any)b.adapter:cancel()end}
 kernel.validate(tree)
 return {brain=brain,kernel=kernel,adapter=adapter,board=board,memory=brain.new(),tree=tree,treeMemory=mem,machine=kernel.machine(states,board),intent=nil}
end
function A.decide(a:any,dt:number):any
 local sense=a.adapter:sense(dt)
 local intent=a.brain.step(a.memory,sense)
 local changed=not a.intent or a.intent.state~=intent.state
 if changed then
  a.kernel.abort(a.tree,a.treeMemory,a.board)
  a.kernel.transition(a.machine,if states[intent.state] then intent.state else intent.branch)
  a.adapter:enter(intent)
 end
 a.intent=intent;a.board.intent=intent
 return intent
end
function A.act(a:any,dt:number):any
 if not a.intent then return nil end
 local status,visits=a.kernel.tick(a.tree,a.treeMemory,a.board,dt,1)
 return {intent=a.intent,status=status,visits=visits}
end
function A.step(a:any,dt:number):any
 A.decide(a,dt);return A.act(a,dt)
end
function A.destroy(a:any)
 a.kernel.abort(a.tree,a.treeMemory,a.board);a.adapter:destroy()
end
return table.freeze(A)
