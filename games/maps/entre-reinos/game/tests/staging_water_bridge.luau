-- Candidate Terrain is generated in a disposable Open Cloud server.
local function probeWaterBridge(world,profile,routes)
    local seed=516639272
    local graph=routes.compile(seed)
    local wet=RaycastParams.new()
    wet.FilterType=Enum.RaycastFilterType.Include
    wet.FilterDescendantsInstances={workspace.Terrain}
    local banks={}
    for _,crossing in ipairs(graph.crossings) do
        if not crossing.buildable then continue end
        for _,side in ipairs({"west","east"}) do
            local bank=crossing[side]
            assert(world.ensureNear(seed,bank.x))
            local approach=bank.x+(if side=="west" then -2 else 2)
            local _,reason=routes.bridgePlan(graph,approach)
            local native={}
            for _,z in ipairs({-3, -2, 0, 2, 3}) do
                local hit=workspace:Raycast(Vector3.new(bank.x,70,z),Vector3.new(0,-120,0),wet)
                table.insert(native,if hit then {material=hit.Material.Name,delta=hit.Position.Y-bank.y}
                    else {missing=true})
            end
            table.insert(banks,{crossing=crossing.id,side=side,x=bank.x,approach=reason,native=native})
        end
    end
    return {banks=banks}
end
