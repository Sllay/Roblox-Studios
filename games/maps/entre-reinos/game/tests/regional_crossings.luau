--!strict
local Routes = require("../places/main/src/ReplicatedStorage/RegionalCrossings")
local Profile = require("../places/main/src/ReplicatedStorage/RegionalProfile")

for _, seed in ipairs({1, 42, 1009, 870001, 123456789, 516639272, 2147483646}) do
    local graph = Routes.compile(seed)
    local repeatGraph = Routes.compile(seed)
    assert(#graph.crossings == 5 and #repeatGraph.crossings == #graph.crossings)
    local ids: {[string]: boolean} = {}
    for i, crossing in ipairs(graph.crossings) do
        assert(not ids[crossing.id] and crossing.id == repeatGraph.crossings[i].id)
        ids[crossing.id] = true
        assert(crossing.west.x < crossing.east.x and crossing.span > 0)
        assert(Profile.regionAt(crossing.west.x) == crossing.region)
        assert(Profile.regionAt(crossing.east.x) == crossing.region)
        local left, right = crossing.west.x - 1, crossing.east.x + 1
        local plan = Routes.bridgePlan(graph, (left + right) / 2)
        local walk = assert(Routes.route(graph, left, right, "player", {}))
        assert(#walk == 1 and walk[1].enter.x < walk[1].exit.x)
        if math.abs(crossing.region) == 1 then
            assert(crossing.depth <= 2 and Routes.passage(crossing, "worker", nil) == "ford")
            assert(plan == nil and assert(Routes.route(graph, left, right, "carrier", {}))[1].mode == "ford")
        else
            assert(crossing.depth > 2 and walk[1].mode == "swim")
            assert(not Routes.route(graph, left, right, "worker", {}))
            if crossing.region ~= 0 then
                assert(plan == crossing, "missing buildable banks on regional river")
            end
            if plan then
                local bridge: Routes.Bridge = {tier = "light", state = "blueprint", health = 70, load = 0}
                local bridges = {[crossing.id] = bridge}
                assert(not Routes.route(graph, left, right, "worker", bridges))
                bridge.state = "complete"
                assert(assert(Routes.route(graph, left, right, "worker", bridges))[1].mode == "bridge")
                assert(not Routes.route(graph, left, right, "guard", bridges))
                assert(not Routes.route(graph, left, right, "carrier", bridges))
                assert(not Routes.route(graph, left, right, "mount", bridges))
                bridge.load = 2
                assert(not Routes.route(graph, left, right, "worker", bridges))
                bridge.tier, bridge.load = "reinforced", 0
                local reverse = assert(Routes.route(graph, right, left, "mount", bridges))
                assert(reverse[1].enter.x > reverse[1].exit.x and reverse[1].mode == "bridge")
                assert(Routes.route(graph, left, right, "carrier", bridges))
                assert(not Routes.route(graph, left, right, "worker", bridges, {[crossing.id] = true}))
                bridge.state, bridge.health = "ruined", 0
                assert(not Routes.route(graph, left, right, "worker", bridges))
                assert(assert(Routes.route(graph, left, right, "player", bridges))[1].mode == "swim")
            end
        end
    end
    local acrossWorld = assert(Routes.route(graph, -Profile.PLAY_EDGE, Profile.PLAY_EDGE, "player", {}))
    assert(#acrossWorld == 5)
end
print("ENTRE_REINOS_T2_R1_ROUTE: five crossings and bridge restrictions tested on seven seeds")
