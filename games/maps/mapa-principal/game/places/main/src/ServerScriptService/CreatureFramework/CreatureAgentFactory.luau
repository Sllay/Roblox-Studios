--!strict
-- One factory for passive and combat profiles. No new species implied by a capability profile.
local F={}
function F.new(deps:any,species:any,base:any,actor:any?,world:any?):any
 local brain=deps.profiles.brain(species.profile,deps.brain,deps.combatBrain)
 if species.profile=="PassivePrey" then
  if actor and world then deps.combatWorld.register(world,actor) end
  return deps.agent.new(brain,deps.kernel,base)
 end
 assert(actor and world,"combat actor/world required")
 local profile=assert(deps.profiles.get(species.profile))
 deps.combatWorld.register(world,actor)
 local adapter=deps.combatAdapter.new(base,actor,profile,world,deps.combatWorld,deps.targetSelector)
 return deps.agent.new(brain,deps.kernel,adapter)
end
return table.freeze(F)
