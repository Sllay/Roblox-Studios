--!strict
-- The regional graph connects dry approaches along the lateral world axis.
-- Callers can retain the graph per seed, while each query sees live bridge
-- state. Local X/Z obstacle avoidance remains the job of the resident mover.
local Profile = require("./RegionalProfile")
local Routes = {}

export type Bank = {x: number, y: number}
export type Crossing = {
    id: string, region: number, west: Bank, east: Bank,
    depth: number, span: number, deckWestY: number, deckEastY: number, buildable: boolean,
}
export type Bridge = {tier: string, state: string, health: number, load: number}
export type Graph = {crossings: {Crossing}}
type Agent = {wade: boolean, swim: boolean, light: boolean, heavy: boolean, weight: number}

local agents: {[string]: Agent} = {
    player = {wade = true, swim = true, light = false, heavy = true, weight = 1},
    worker = {wade = true, swim = false, light = true, heavy = true, weight = 1},
    guard = {wade = true, swim = false, light = false, heavy = true, weight = 1},
    carrier = {wade = true, swim = false, light = false, heavy = true, weight = 2},
    mount = {wade = true, swim = false, light = false, heavy = true, weight = 3},
}

-- Capacity values are initial lab inputs; balance remains open.
local capacity = {light = 2, reinforced = 6}
local cell = Profile.CELL

local function waterDepthAt(sample: {waterSurface: number?, height: number}): number
    return if sample.waterSurface then math.max(0, sample.waterSurface - sample.height) else 0
end

local function approach(seed: number, from: number, direction: number): (Bank, boolean)
    for offset = 0, 12, cell do
        local x = from + direction * offset
        local current = Profile.sample(seed, x, Profile.LANE_Z)
        local dryAhead = Profile.sample(seed, x + direction * cell, Profile.LANE_Z)
        if waterDepthAt(current) == 0 and waterDepthAt(dryAhead) == 0
            and math.abs(current.height - dryAhead.height) <= 2.5 then
            return {x = x, y = current.height}, true
        end
    end
    return {x = from, y = Profile.sample(seed, from, Profile.LANE_Z).height}, false
end

function Routes.compile(seed: number): Graph
    assert(Profile.validSeed(seed), "invalid world seed")
    local crossings: {Crossing} = {}
    local start: number? = nil
    local depth, water = 0, -math.huge
    for x = Profile.BOUNDS.xMin + cell / 2, Profile.BOUNDS.xMax - cell / 2, cell do
        local sample = Profile.sample(seed, x, Profile.LANE_Z)
        local waterDepth = waterDepthAt(sample)
        if waterDepth > 0 then
            start = start or x
            depth = math.max(depth, waterDepth)
            water = math.max(water, sample.waterSurface :: number)
        elseif start then
            local west, supportedWest = approach(seed, start - cell, -1)
            local east, supportedEast = approach(seed, x, 1)
            local span = east.x - west.x
            local region = assert(Profile.regionAt(start))
            local id = Profile.region(region).id .. ":crossing:" .. tostring((start - cell / 2) / cell)
            local deckWest = math.max(west.y, water + 0.5)
            local deckEast = math.max(east.y, water + 0.5)
            table.insert(crossings, {
                id = id, region = region, west = west, east = east,
                depth = depth, span = span, deckWestY = deckWest, deckEastY = deckEast,
                buildable = depth > 2 and supportedWest and supportedEast and span >= 12 and span <= 88
                    and math.abs(deckWest - deckEast) <= span * 0.14
                    and deckWest - west.y <= 2 and deckEast - east.y <= 2,
            })
            start, depth, water = nil, 0, -math.huge
        end
    end
    assert(start == nil, "water access at the outer edge is undefined")
    return {crossings = crossings}
end

function Routes.bridgePlan(graph: Graph, x: number): (Crossing?, string?)
    if not Profile.regionAt(x) then return nil, "outside_region" end
    for _, crossing in ipairs(graph.crossings) do
        if x >= crossing.west.x and x <= crossing.east.x then
            if crossing.buildable then return crossing, nil end
            return nil, "invalid_bridge_banks"
        end
    end
    return nil, "missing_crossing"
end

local function bridgeAllows(bridge: Bridge?, agent: Agent): boolean
    if not bridge or (bridge.state ~= "complete" and bridge.state ~= "damaged")
        or not (bridge.health > 0 and bridge.load >= 0) then return false end
    if bridge.tier == "light" then
        return agent.light and bridge.load + agent.weight <= capacity.light
    end
    if bridge.tier == "reinforced" then
        return agent.heavy and bridge.load + agent.weight <= capacity.reinforced
    end
    return false
end

function Routes.passage(crossing: Crossing, className: string, bridge: Bridge?): string?
    local agent = agents[className]
    if not agent then return nil end
    if crossing.buildable and bridgeAllows(bridge, agent) then return "bridge" end
    if crossing.depth <= 2 and agent.wade then return "ford" end
    if agent.swim then return "swim" end
    return nil
end

export type RouteStep = {id: string, enter: Bank, exit: Bank, mode: string}
function Routes.route(graph: Graph, from: number, to: number, className: string,
        bridges: {[string]: Bridge}, blocked: {[string]: boolean}?): ({RouteStep}?, string?)
    if not agents[className] then return nil, "invalid_agent" end
    if not Profile.regionAt(from) or not Profile.regionAt(to) then return nil, "outside_region" end
    local left, right = math.min(from, to), math.max(from, to)
    local forward = to >= from
    local steps: {RouteStep} = {}
    for i = 1, #graph.crossings do
        local crossing = graph.crossings[if forward then i else #graph.crossings - i + 1]
        if left < crossing.east.x and right > crossing.west.x then
            if blocked and blocked[crossing.id] then return nil, "closed_crossing" end
            local mode = Routes.passage(crossing, className, bridges[crossing.id])
            if not mode then return nil, "no_crossing" end
            table.insert(steps, {
                id = crossing.id,
                enter = if forward then crossing.west else crossing.east,
                exit = if forward then crossing.east else crossing.west,
                mode = mode,
            })
        end
    end
    return steps, nil
end

return Routes
