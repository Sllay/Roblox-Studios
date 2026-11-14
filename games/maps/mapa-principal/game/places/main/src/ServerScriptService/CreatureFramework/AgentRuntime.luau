--!strict
-- Shared action execution: perception/locomotion are injected, no per-agent heartbeat.
local A={}
local states={Alive={},Routine={parent="Alive"},Survival={parent="Alive"},Lifecycle={},Disabled={}}
function A.new(brain:any,kernel:any,adapter:any):any
 local board:any={adapter=adapter,intent=nil}
 local mem=kernel.memory()
 local tree={id="act",kind="Action",tick=function(b:any,dt:number)
  return b.adapter:execute(b.intent,dt)
 end,cancel=function(b:any)b.adapter:cancel()end}
 kernel.validate(tree)
 return {brain=brain,kernel=kernel,adapter=adapter,board=board,memory=brain.new(),tree=tree,treeMemory=mem,machine=kernel.machine(states,board),intent=nil}
end
function A.step(a:any,dt:number):any
 local sense=a.adapter:sense(dt)
 local intent=a.brain.step(a.memory,sense)
 local changed=not a.intent or a.intent.state~=intent.state
 if changed then
  a.kernel.abort(a.tree,a.treeMemory,a.board)
  a.kernel.transition(a.machine,intent.branch)
  a.adapter:enter(intent)
 end
 a.intent=intent;a.board.intent=intent
 local status,visits=a.kernel.tick(a.tree,a.treeMemory,a.board,dt,1)
 return {intent=intent,status=status,visits=visits}
end
function A.destroy(a:any)
 a.kernel.abort(a.tree,a.treeMemory,a.board);a.adapter:destroy()
end
return table.freeze(A)
